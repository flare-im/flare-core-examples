// 最小隔离测试:web app 登录态是否跨页面刷新持久化。
// 登录 → 进会话 → 连续 reload 3 次,每次记录 URL 与是否仍在已登录界面。
import { chromium } from "playwright";
const baseUrl = process.env.CH_BASE_URL;
if (!baseUrl) {
  console.error("CH_BASE_URL is required (example: CH_BASE_URL=http://localhost:1430); reloadcheck never defaults to a deployed environment.");
  process.exit(2);
}
const user = process.env.RC_USER ?? "member-000010";
const peer = process.env.RC_PEER ?? "member-000011";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(`[${new Date().toISOString()}]`, ...a);

async function stateOf(page) {
  const url = page.url();
  const composer = await page.locator(".composer-input textarea").isVisible().catch(() => false);
  const onLogin = /#\/login/.test(url);
  const hasStorage = await page.evaluate(() => {
    let ls = 0, hasIdb = false;
    try { ls = Object.keys(localStorage).length; } catch {}
    try { hasIdb = !!window.indexedDB; } catch {}
    const keys = (() => { try { return Object.keys(localStorage); } catch { return []; } })();
    return { ls, hasIdb, keys };
  });
  return { url, composer, onLogin, storage: hasStorage };
}

async function main() {
  const browser = await chromium.launch({ headless: process.env.CH_HEADFUL === "0" });
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  page.setDefaultTimeout(60000);
  page.on("console", (m) => { if (["error", "warning"].includes(m.type())) log(`  [console.${m.type()}]`, m.text().slice(0, 200)); });
  page.on("pageerror", (e) => log("  [pageerror]", String(e).slice(0, 200)));
  page.on("response", (r) => { if (r.status() >= 400) log(`  [http ${r.status()}]`, r.url().slice(0, 120)); });
  page.on("request", (r) => { const u = r.url(); if (/auth|token/i.test(u)) log(`  [req ${r.method()}]`, u.slice(0, 130)); });
  page.on("requestfailed", (r) => log(`  [reqfailed]`, r.url().slice(0, 100), r.failure()?.errorText || ""));
  await page.goto(`${baseUrl}/#/login`, { waitUntil: "domcontentloaded" });
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(user);
  await page.getByRole("button", { name: /立即登录|Log in/i }).click();
  await page.waitForURL(/#\/conversations/, { timeout: 90000 });
  log("登录成功:", JSON.stringify(await stateOf(page)));

  // 进一个会话
  await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
  const dialog = page.getByRole("dialog").last();
  await dialog.getByRole("textbox").first().fill(peer);
  await dialog.getByRole("button", { name: /^(打开|Open)$/i }).click();
  await page.waitForURL(/#\/chat/, { timeout: 30000 });
  await page.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 30000 });
  log("进会话成功:", JSON.stringify(await stateOf(page)));

  // 连续 reload 3 次
  for (let i = 1; i <= 3; i++) {
    await sleep(2000);
    await page.reload({ waitUntil: "domcontentloaded" });
    await sleep(4000);
    const s = await stateOf(page);
    log(`reload #${i}:`, JSON.stringify(s));
  }
  await sleep(1500);
  await browser.close();
}
main().catch((e) => { log("FATAL", String(e)); process.exit(1); });
