/**
 * Web Worker: wa-sqlite over OPFS (Origin Private File System).
 *
 * OPFS synchronous access handles are only available in a Worker, so the SQLite
 * engine + persistence run here; the main-thread host (`sqliteOpfsStorageHost.ts`)
 * drives it over a small request/response protocol.
 *
 * Storage model mirrors the IndexedDB host (`@flare-im/sdk/web`
 * idbWasmStorageHost): four KV tables keyed exactly the same way, so a packaged
 * desktop app persists the same snapshot to a real SQLite file instead of IndexedDB.
 *
 * NOTE: requires the `wa-sqlite` dependency and Vite worker bundling; certify in an
 * Electron run (OPFS is unavailable in Node/SSR).
 */

// Ambient: wa-sqlite ships its own ESM; types are declared in `wa-sqlite.d.ts`.
import SQLiteESMFactory from "wa-sqlite/dist/wa-sqlite.mjs";
import * as SQLite from "wa-sqlite";
import { OPFSCoopSyncVFS } from "wa-sqlite/src/examples/OPFSCoopSyncVFS.js";
// wasm 的地址必须显式交给 emscripten glue，不能用它的默认行为。
//
// 默认是「按 glue 脚本自己的 URL 找同名 .wasm」。dev 下 glue 由 vite 转换后
// 从别的 URL 提供，那个位置没有 .wasm，于是请求落进 SPA 回退拿到 index.html，
// 报的是 `WebAssembly.instantiate(): expected magic word 00 61 73 6d,
// found 3c 21 64 6f`——`3c 21 64 6f` 就是 "<!do"。
//
// `?url` 让 vite 两种模式下都给出真实可取的地址：dev 直接服务该文件，
// build 时作为资源产出并改写成带 hash 的路径。
import wasmUrl from "wa-sqlite/dist/wa-sqlite.wasm?url";

type Req = {
  id: number;
  op: string;
  payload: Record<string, unknown>;
};

const DB_FILE = "flare-core.sqlite";

let sqlite3: ReturnType<typeof SQLite.Factory> | null = null;
let db = 0;
let ready: Promise<void> | null = null;

const TABLES = ["messages", "conversations", "cursors", "pending_sends"] as const;

function ensureReady(): Promise<void> {
  if (!ready) {
    ready = (async () => {
      const module = await SQLiteESMFactory({ locateFile: () => wasmUrl });
      sqlite3 = SQLite.Factory(module);
      const vfs = await OPFSCoopSyncVFS.create("flare-opfs", module);
      sqlite3.vfs_register(vfs, true);
      db = await sqlite3.open_v2(DB_FILE, undefined, "flare-opfs");
      for (const table of TABLES) {
        await sqlite3.exec(
          db,
          `CREATE TABLE IF NOT EXISTS ${table} (
             key TEXT PRIMARY KEY,
             user_id TEXT NOT NULL,
             json TEXT NOT NULL
           );
           CREATE INDEX IF NOT EXISTS ${table}_user ON ${table}(user_id);`,
        );
      }
    })();
  }
  return ready;
}

async function run(sql: string, params: SQLite.SQLiteCompatibleType[] = []): Promise<void> {
  if (!sqlite3) throw new Error("sqlite not ready");
  for await (const stmt of sqlite3.statements(db, sql)) {
    sqlite3.bind_collection(stmt, params);
    await sqlite3.step(stmt);
  }
}

async function selectJson(sql: string, params: SQLite.SQLiteCompatibleType[]): Promise<string[]> {
  if (!sqlite3) throw new Error("sqlite not ready");
  const out: string[] = [];
  for await (const stmt of sqlite3.statements(db, sql)) {
    sqlite3.bind_collection(stmt, params);
    while ((await sqlite3.step(stmt)) === SQLite.SQLITE_ROW) {
      out.push(String(sqlite3.column(stmt, 0)));
    }
  }
  return out;
}

async function upsert(table: string, key: string, userId: string, json: string): Promise<void> {
  await run(
    `INSERT INTO ${table} (key, user_id, json) VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET json = excluded.json, user_id = excluded.user_id`,
    [key, userId, json],
  );
}

async function deleteByKey(table: string, key: string): Promise<void> {
  await run(`DELETE FROM ${table} WHERE key = ?`, [key]);
}

async function deleteByKeyPrefixContains(table: string, prefix: string, idFragment: string): Promise<void> {
  // Mirror idb host's "key startsWith user prefix AND contains ::id" delete.
  await run(`DELETE FROM ${table} WHERE key LIKE ? AND key LIKE ?`, [`${prefix}%`, `%::${idFragment}%`]);
}

async function loadSnapshot(userId: string): Promise<string> {
  const [messages, conversations, cursorRows, pendingSends] = await Promise.all([
    selectJson(`SELECT json FROM messages WHERE user_id = ? ORDER BY key`, [userId]),
    selectJson(`SELECT json FROM conversations WHERE user_id = ?`, [userId]),
    selectJson(`SELECT json FROM cursors WHERE user_id = ?`, [userId]),
    selectJson(`SELECT json FROM pending_sends WHERE user_id = ?`, [userId]),
  ]);
  const cursors: Record<string, string> = {};
  for (const raw of cursorRows) {
    try {
      const entry = JSON.parse(raw) as { cursorKey?: string; value?: string };
      if (entry.cursorKey) cursors[entry.cursorKey] = String(entry.value ?? "");
    } catch {
      /* skip malformed cursor row */
    }
  }
  return JSON.stringify({
    messages: messages.map((j) => JSON.parse(j)),
    conversations: conversations.map((j) => JSON.parse(j)),
    cursors,
    pendingSends: pendingSends.map((j) => JSON.parse(j)),
  });
}

async function handle(op: string, p: Record<string, unknown>): Promise<unknown> {
  await ensureReady();
  const userId = String(p.userId ?? "").trim();
  switch (op) {
    case "loadSnapshot":
      return loadSnapshot(userId);
    case "saveMessage":
      await upsert("messages", String(p.key), userId, String(p.json));
      return undefined;
    case "saveConversation":
      await upsert("conversations", String(p.key), userId, String(p.json));
      return undefined;
    case "saveCursor":
      await upsert("cursors", String(p.key), userId, String(p.json));
      return undefined;
    case "savePendingSend":
      await upsert("pending_sends", String(p.key), userId, String(p.json));
      return undefined;
    case "deleteMessage":
      await deleteByKeyPrefixContains("messages", String(p.prefix), String(p.id));
      return undefined;
    case "deleteConversation":
      await deleteByKey("conversations", String(p.key));
      return undefined;
    case "deletePendingSend":
      await deleteByKey("pending_sends", String(p.key));
      return undefined;
    default:
      throw new Error(`unknown sqlite op: ${op}`);
  }
}

self.onmessage = async (event: MessageEvent<Req>): Promise<void> => {
  const { id, op, payload } = event.data;
  try {
    const result = await handle(op, payload);
    (self as unknown as Worker).postMessage({ id, ok: true, result });
  } catch (error) {
    (self as unknown as Worker).postMessage({
      id,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};
