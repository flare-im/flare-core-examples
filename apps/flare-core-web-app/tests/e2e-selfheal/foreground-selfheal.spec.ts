import { expect, test, type Browser, type BrowserContext, type Page } from "@playwright/test";

// 忠实验证「前台恢复自愈」：
// 半开死连（浏览器侧 WS 仍 OPEN、服务端帧被丢弃 → 无 PONG、onclose 不触发）下，
// 触发 visibility→visible 应让 flare-core 心跳层做一次即时验活（probe），
// 8s 窗口内无 PONG 即主动断开 → 重连 → 恢复收发。
//
// 用 page.routeWebSocket 拦截 alice 的网关 WS：置「dead」后双向丢帧但不关 socket，
// 精确复刻半开态（这是普通 setOffline 造不出的——setOffline 会触发 onclose 走另一条路）。

const loginButton = /立即登录|Log in/i;

async function loginAs(browser: Browser, userId: string): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto("/#/login");
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(userId);
  await page.getByRole("button", { name: loginButton }).click();
  await expect(page).toHaveURL(/#\/conversations/, { timeout: 60_000 });
  return { context, page };
}

async function openPeerConversation(page: Page, peerUserId: string): Promise<void> {
  await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
  const dialog = page.getByRole("dialog").last();
  await dialog.getByRole("textbox").first().fill(peerUserId);
  // 确认按钮在不同 locale 下是「打开」或「Open」；等它可点再点。
  const confirm = dialog.getByRole("button", { name: /^(打开|Open)$/i });
  await expect(confirm).toBeEnabled({ timeout: 15_000 });
  await confirm.click();
  await expect(page).toHaveURL(/#\/chat/, { timeout: 30_000 });
  await expect(page.locator(".composer-input textarea")).toBeVisible();
}

async function typeAndSend(page: Page, text: string): Promise<void> {
  await page.locator(".composer-input textarea").fill(text);
  await page.getByRole("button", { name: /^发送$|^Send$/i }).click();
}

async function setVisibility(page: Page, state: "hidden" | "visible"): Promise<void> {
  await page.evaluate((s) => {
    Object.defineProperty(document, "visibilityState", { configurable: true, get: () => s });
    Object.defineProperty(document, "hidden", { configurable: true, get: () => s === "hidden" });
    document.dispatchEvent(new Event("visibilitychange"));
  }, state);
}

test.describe("Flare Core web 前台恢复自愈", () => {
  test("半开死连在 visibility→visible 后经心跳 probe 自愈并恢复收发", async ({ browser }) => {
    const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 6)}`;
    const alice = `pw-heal-a-${suffix}`;
    const bob = `pw-heal-b-${suffix}`;
    const seedText = `heal-seed ${suffix}`;
    const afterHealText = `heal-after ${suffix}`;

    // alice 的网关 WS 拦截状态（Node 侧共享）。
    const wsState = { count: 0, deadIdx: null as number | null };

    const context = await browser.newContext();
    const page = await context.newPage();

    // 只拦截 alice：置 deadIdx 后该 socket 双向丢帧但保持 OPEN（半开）。
    await page.routeWebSocket(/\/ws(\?|$)/, (ws) => {
      const idx = ++wsState.count;
      const server = ws.connectToServer();
      ws.onMessage((m) => {
        if (wsState.deadIdx === idx) return; // 丢客户端帧：网关收不到 ping
        server.send(m);
      });
      server.onMessage((m) => {
        if (wsState.deadIdx === idx) return; // 丢服务端帧：客户端收不到 pong
        ws.send(m);
      });
    });

    // alice 登录（走 routeWebSocket）。
    await page.goto("/#/login");
    await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(alice);
    await page.getByRole("button", { name: loginButton }).click();
    await expect(page).toHaveURL(/#\/conversations/, { timeout: 60_000 });
    const a = { context, page };

    // bob 普通登录（不拦截），作为对端验证收发。
    const b = await loginAs(browser, bob);

    // 基线：alice→bob 通，证明拦截转发正常、连接健康。
    await openPeerConversation(a.page, bob);
    await typeAndSend(a.page, seedText);
    await expect(b.page.getByText(seedText).first()).toBeVisible({ timeout: 60_000 });
    await b.page.getByText(seedText).first().click();
    await expect(b.page).toHaveURL(/#\/chat/, { timeout: 15_000 });

    // 记下自愈前的 socket 数（此刻应为 1）。
    const socketsBeforeHeal = wsState.count;
    expect(socketsBeforeHeal).toBeGreaterThanOrEqual(1);

    // —— 制造半开死连：把 alice 当前 socket 标记为 dead（双向丢帧、不关 socket）——
    wsState.deadIdx = wsState.count;

    // 模拟后台一段时间：先 hidden（心跳降配/在真实浏览器会被节流），
    // 死连期间 UI 仍自认为在线（onclose 不触发）。
    await setVisibility(a.page, "hidden");
    await a.page.waitForTimeout(3_000);

    // —— 用户回到前台：visibility→visible → setHeartbeatAppState(Foreground)
    //    → flare-core 心跳即时 probe：8s 窗口无 PONG → 主动 close → 重连 ——
    await setVisibility(a.page, "visible");

    // 自愈判据①：probe 戳穿死连后触发重连，必然新建一个 socket（count 增长）。
    // 无本修复时只会等 90s 心跳 timeout，这里 45s 内出现新 socket 即证明 probe 生效。
    await expect
      .poll(() => wsState.count, { timeout: 45_000, intervals: [1_000] })
      .toBeGreaterThan(socketsBeforeHeal);

    // 自愈判据②：恢复后 alice 真实收发正常（连接真愈，而非仅换了 socket）。
    await typeAndSend(a.page, afterHealText);
    await expect(b.page.getByText(afterHealText).first()).toBeVisible({ timeout: 60_000 });

    await a.context.close();
    await b.context.close();
  });
});
