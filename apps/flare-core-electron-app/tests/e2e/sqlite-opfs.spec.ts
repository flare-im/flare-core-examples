import { expect, test } from "@playwright/test";

/**
 * 桌面存储路径（wa-sqlite + OPFS）的运行时认证。
 *
 * 源码注释里长期写着「certify in an Electron run」—— 也就是从没认证过。
 * 这条测试把它变成可重复的：OPFS 与 Web Worker 都是 Chromium 的能力，
 * 而 Electron 的渲染进程就是 Chromium，所以在 Chromium 里跑通足以覆盖
 * 存储引擎本身。
 *
 * 仍**不**覆盖的是 Electron 打包后的资源定位（file:// / app:// 协议下
 * wasm 与 worker 的 URL），那需要真的打一个包再跑。别把这条测试当成
 * 「打包后也没问题」的证据。
 *
 * 这条测试挡住过两个真缺陷：
 *
 * 1. wa-sqlite 声明成 optionalDependencies 且版本区间在 npm 上不存在
 *    （只有 1.0.0，更新版本只在上游 GitHub）→ npm 静默跳过、不报错，
 *    构建时才报找不到模块。
 * 2. emscripten glue 没拿到 locateFile → 默认按 glue 自身 URL 找同名 .wasm，
 *    dev 下那个位置没有文件，请求落进 SPA 回退拿到 index.html，
 *    报成 `expected magic word 00 61 73 6d, found 3c 21 64 6f`（"<!do"）。
 *
 * 前置：`npx playwright install chromium`。
 */

const USER = "opfs-cert-user";
const OTHER_USER = "opfs-cert-other";

/** 在页面里加载**真实**的存储主机模块并执行一段操作。 */
const writeThenRead = async (userId: string) => {
  const mod = await import("/src/storage/sqliteOpfsStorageHost.ts");
  const host = mod.createSqliteOpfsStorageHost();
  await host.saveConversation({ userId, conversation: { conversationId: "conv-A", name: "cert-conversation" } });
  await host.saveMessage({
    userId,
    message: { conversationId: "conv-A", messageId: "m-1", seq: 1, content: "hello-opfs" },
  });
  await host.saveCursor({ userId, key: "conv-A", value: "7" });
  return JSON.parse(await host.loadSnapshot({ userId }));
};

const readOnly = async (userId: string) => {
  const mod = await import("/src/storage/sqliteOpfsStorageHost.ts");
  const host = mod.createSqliteOpfsStorageHost();
  return JSON.parse(await host.loadSnapshot({ userId }));
};

test.describe("wa-sqlite + OPFS 存储主机", () => {
  test("写入后读回，且按 userId 隔离", async ({ page }) => {
    await page.goto("/");

    const snapshot = await page.evaluate(writeThenRead, USER);
    expect(snapshot.messages).toHaveLength(1);
    expect(snapshot.messages[0].content).toBe("hello-opfs");
    expect(snapshot.conversations).toHaveLength(1);
    expect(snapshot.conversations[0].name).toBe("cert-conversation");
    expect(Object.keys(snapshot.cursors)).toContain("conv-A");

    // 另一个用户不该看到上面的数据——四张 KV 表都按 user 前缀分键。
    const other = await page.evaluate(readOnly, OTHER_USER);
    expect(other.messages).toHaveLength(0);
    expect(other.conversations).toHaveLength(0);
  });

  test("刷新后仍在（这才是用 SQLite/OPFS 而不是内存的意义）", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(writeThenRead, USER);

    await page.reload();

    // 这一轮**只读不写**：数据必须来自 OPFS 上真实的 SQLite 文件。
    const snapshot = await page.evaluate(readOnly, USER);
    expect(snapshot.messages).toHaveLength(1);
    expect(snapshot.messages[0].content).toBe("hello-opfs");

    // 并确认落地的是真文件，而不是某层内存兜底。
    const entries = await page.evaluate(async () => {
      const root = await navigator.storage.getDirectory();
      const names: string[] = [];
      // @ts-expect-error entries() 在 TS 的 FileSystemDirectoryHandle 定义里还没有
      for await (const [name] of root.entries()) names.push(name);
      return names;
    });
    expect(entries).toContain("flare-core.sqlite");
  });
});
