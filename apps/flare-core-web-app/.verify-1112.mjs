import { chromium } from "@playwright/test";
const base = "http://127.0.0.1:1430";
const stamp = Date.now();
const browser = await chromium.launch();
async function login(user) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto(`${base}/#/login`);
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(user);
  await page.getByRole("button", { name: /立即登录|Log in/i }).click();
  await page.waitForURL(/#\/conversations/, { timeout: 90000 });
  return { ctx, page };
}
async function openConv(page, peer) {
  await page.getByLabel("新建会话").click();
  const d = page.getByRole("dialog").last();
  await d.getByRole("textbox").fill(peer);
  await d.getByRole("button", { name: /^打开$/ }).click();
  await page.waitForURL(/#\/chat/, { timeout: 30000 });
}
const a = await login("11"), b = await login("12");
await openConv(a.page, "12"); await openConv(b.page, "11");
const t1 = `verify-11to12-${stamp}`;
await a.page.locator(".composer-input textarea").fill(t1);
await a.page.getByRole("button", { name: /^发送$/ }).click();
console.log("12 realtime:", await b.page.getByText(t1).first().isVisible({ timeout: 15000 }).catch(() => false));
const t2 = `verify-12to11-${stamp}`;
await b.page.locator(".composer-input textarea").fill(t2);
await b.page.getByRole("button", { name: /^发送$/ }).click();
console.log("11 realtime:", await a.page.getByText(t2).first().isVisible({ timeout: 15000 }).catch(() => false));
await browser.close();
