/**
 * SQLite (wa-sqlite + OPFS) storage host — desktop/PC builds.
 *
 * Implements the same `WasmStorageHostCallbacks` contract as the IndexedDB host, so the
 * WASM core's `setStorageHost` callbacks persist to a real SQLite file (OPFS) instead of
 * IndexedDB. Used by packaged Electron desktop apps; web/H5 keep IndexedDB.
 *
 * The SQLite engine runs in `sqliteOpfsWorker.ts` (OPFS sync access requires a Worker);
 * this module owns the worker, computes the same keys as the IndexedDB host, and emits the
 * `WASM_STORAGE_CHANGED_EVENT` so the UI refreshes identically on either backend.
 *
 * Requires the `wa-sqlite` dependency + Vite worker bundling; certify in an Electron run.
 */
import {
  WASM_STORAGE_CHANGED_EVENT,
  type WasmStorageChangedDetail,
  type WasmStorageHostCallbacks,
} from "@flare-im/sdk/web";

type WorkerResponse = { id: number; ok: true; result: unknown } | { id: number; ok: false; error: string };

function cryptoSafeId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return Math.random().toString(36).slice(2);
}

function userPrefix(userId: string): string {
  return userId.trim();
}

function messageKey(userId: string, message: Record<string, unknown>): string {
  const serverId = String(message.serverId ?? "");
  const clientMsgId = String(message.clientMsgId ?? "");
  const conversationId = String(message.conversationId ?? "");
  const seq = String(message.conversationSeq ?? 0).padStart(20, "0");
  return `${userPrefix(userId)}::${conversationId}::${seq}::${serverId || clientMsgId || cryptoSafeId()}`;
}

function pendingSendKey(userId: string, entry: Record<string, unknown>): string {
  const clientMsgId = String(entry.clientMsgId ?? cryptoSafeId());
  return `${userPrefix(userId)}::${clientMsgId}`;
}

function notifyStorageChanged(detail: WasmStorageChangedDetail): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent<WasmStorageChangedDetail>(WASM_STORAGE_CHANGED_EVENT, { detail }));
}

class SqliteWorkerClient {
  private worker: Worker | null = null;
  private seq = 0;
  private readonly pending = new Map<
    number,
    { resolve: (value: unknown) => void; reject: (reason: unknown) => void }
  >();

  private ensureWorker(): Worker {
    if (!this.worker) {
      this.worker = new Worker(new URL("./sqliteOpfsWorker.ts", import.meta.url), { type: "module" });
      this.worker.onmessage = (event: MessageEvent<WorkerResponse>) => {
        const message = event.data;
        const entry = this.pending.get(message.id);
        if (!entry) return;
        this.pending.delete(message.id);
        if (message.ok) entry.resolve(message.result);
        else entry.reject(new Error(message.error));
      };
    }
    return this.worker;
  }

  call(op: string, payload: Record<string, unknown>): Promise<unknown> {
    const worker = this.ensureWorker();
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      worker.postMessage({ id, op, payload });
    });
  }
}

export function createSqliteOpfsStorageHost(): WasmStorageHostCallbacks {
  const client = new SqliteWorkerClient();
  return {
    async loadSnapshot(payload) {
      const userId = payload.userId?.trim();
      if (!userId) {
        return JSON.stringify({ messages: [], conversations: [], cursors: {}, pendingSends: [] });
      }
      return String(await client.call("loadSnapshot", { userId }));
    },
    async saveMessage(payload) {
      const userId = payload.userId?.trim();
      if (!userId) return;
      const message = payload.message ?? {};
      const conversationId = String(message.conversationId ?? "").trim();
      await client.call("saveMessage", {
        userId,
        key: messageKey(userId, message),
        json: JSON.stringify(message),
      });
      notifyStorageChanged({ userId, kind: "message", conversationId, message });
    },
    async saveConversation(payload) {
      const userId = payload.userId?.trim();
      if (!userId) return;
      const conversation = payload.conversation ?? {};
      const conversationId = String(conversation.conversationId ?? "").trim();
      await client.call("saveConversation", {
        userId,
        key: `${userPrefix(userId)}::${conversationId}`,
        json: JSON.stringify(conversation),
      });
      notifyStorageChanged({ userId, kind: "conversation", conversationId, conversation });
    },
    async saveCursor(payload) {
      const userId = payload.userId?.trim();
      if (!userId || !payload.key) return;
      await client.call("saveCursor", {
        userId,
        key: `${userPrefix(userId)}::${payload.key}`,
        json: JSON.stringify({ cursorKey: payload.key, value: payload.value }),
      });
      notifyStorageChanged({ userId, kind: "cursor", id: payload.key });
    },
    async savePendingSend(payload) {
      const userId = payload.userId?.trim();
      if (!userId) return;
      const entry = payload.entry ?? {};
      await client.call("savePendingSend", {
        userId,
        key: pendingSendKey(userId, entry),
        json: JSON.stringify(entry),
      });
      notifyStorageChanged({ userId, kind: "pending_send", id: String(entry.clientMsgId ?? "") });
    },
    async deleteMessage(payload) {
      const userId = payload.userId?.trim();
      if (!userId || !payload.id) return;
      await client.call("deleteMessage", { userId, prefix: `${userPrefix(userId)}::`, id: payload.id });
      notifyStorageChanged({ userId, kind: "delete", id: payload.id });
    },
    async deleteConversation(payload) {
      const userId = payload.userId?.trim();
      if (!userId || !payload.id) return;
      await client.call("deleteConversation", { userId, key: `${userPrefix(userId)}::${payload.id}` });
      notifyStorageChanged({ userId, kind: "delete", conversationId: payload.id, id: payload.id });
    },
    async deletePendingSend(payload) {
      const userId = payload.userId?.trim();
      if (!userId || !payload.id) return;
      await client.call("deletePendingSend", { userId, key: `${userPrefix(userId)}::${payload.id}` });
      notifyStorageChanged({ userId, kind: "delete", id: payload.id });
    },
  };
}
