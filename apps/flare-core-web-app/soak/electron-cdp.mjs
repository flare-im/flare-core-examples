// 经 CDP 驱动 electron 的 renderer,验证桌面端热启动(登录/重启后恢复)。
import { chromium } from "playwright";
const mode = process.argv[2] || "check";
const user = process.argv[3] || "member-000010";
const peer = process.argv[4] || "member-000011";
const log = (...a) => console.log(`[${new Date().toISOString()}]`, ...a);

const browser = await chromium.connectOverCDP("http://localhost:9222");
const ctx = browser.contexts()[0];
let page = ctx.pages().find((p) => p.url().includes("1433")) || ctx.pages()[0];
await page.waitForLoadState("domcontentloaded").catch(() => {});

const connState = () => page.evaluate(() => {
  const t = document.body.innerText || "";
  for (const s of ["reconnecting", "connecting", "disconnected", "ready", "connected"])
    if (new RegExp("\\b" + s + "\\b", "i").test(t)) return s;
  return "?";
});
const savedSession = () => page.evaluate(() => { try { return !!localStorage.getItem("flare-core:saved-session:v1"); } catch { return "err"; } });
const stateOf = async () => ({ url: page.url(), composer: await page.locator(".composer-input textarea").isVisible().catch(() => false), onLogin: /#\/login/.test(page.url()) });

if (mode === "login") {
  log("初始:", JSON.stringify(await stateOf()));
  if (/#\/login/.test(page.url())) {
    await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(user);
    await page.getByRole("button", { name: /立即登录|Log in/i }).click();
    await page.waitForURL(/#\/conversations/, { timeout: 90000 });
  }
  await page.waitForTimeout(3000);
  log("登录后:", JSON.stringify(await stateOf()), "connState=", await connState(), "saved-session=", await savedSession());
} else {
  // 重启后:等 resume 跑完,看是否恢复到 conversations(而非 login)+ 连接
  for (let i = 0; i < 20; i++) {
    const s = await stateOf();
    if (!s.onLogin && /#\/(conversations|chat)/.test(s.url)) break;
    await page.waitForTimeout(1500);
    page = ctx.pages().find((p) => p.url().includes("1433")) || page;
  }
  let conn = "?";
  for (let i = 0; i < 25; i++) { conn = await connState(); if (conn === "ready" || conn === "connected") break; await page.waitForTimeout(1500); }
  log("重启后:", JSON.stringify(await stateOf()), "connState=", conn, "saved-session=", await savedSession());
}
await browser.close(); // 仅断开 CDP,不关 electron
