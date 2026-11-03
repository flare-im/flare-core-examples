// 定性:reload 离线窗口期间对端发的增量,B 热恢复+重连后能否补拉(区分"收敛慢"vs"真丢")。
// 关键:B resume 进聊天窗后,先显式等到连接 connected,再每 2s 轮询底部最长 90s,记录增量到达时间线。
import { chromium } from "playwright";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const num = (v, d) => (v == null || v === "" ? d : Number(v));
const cfg = {
  baseUrl: process.env.CH_BASE_URL ?? "http://localhost:1430",
  sender: process.env.CH_SENDER ?? "member-000010",
  receiver: process.env.CH_RECEIVER ?? "member-000011",
  n: num(process.env.SEND_N, 40),
  m: num(process.env.SEND_M, 15),
  gapMs: num(process.env.CH_SEND_GAP_MS, 45),
  headless: process.env.CH_HEADFUL === "0",
  watchMs: num(process.env.WATCH_MS, 90000), // resume+connected 后盯底部多久
};
const RUN = Date.now().toString(36) + Math.random().toString(36).slice(2, 5);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(`[${new Date().toISOString()}]`, ...a);
const loginButton = /立即登录|Log in/i;
const tag = (s) => `INCR-${RUN}#${s}~`;

async function login(context, userId) {
  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  for (let a = 0; a < 5; a++) {
    try { await page.goto(`${cfg.baseUrl}/#/login`, { waitUntil: "domcontentloaded" }); break; }
    catch (e) { log(`goto retry ${a + 1}`, String(e).slice(0, 60)); await sleep(1500); }
  }
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(userId);
  await page.getByRole("button", { name: loginButton }).click();
  await page.waitForURL(/#\/conversations/, { timeout: 90000 });
  return page;
}
async function openPeer(page, peer) {
  await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
  const dialog = page.getByRole("dialog").last();
  await dialog.getByRole("textbox").first().fill(peer);
  await dialog.getByRole("button", { name: /^(打开|Open)$/i }).click();
  await page.waitForURL(/#\/chat/, { timeout: 30000 });
  await page.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 30000 });
}
async function sendText(page, text) {
  const box = page.locator(".composer-input textarea");
  await box.fill(text); await box.press("Enter");
}
async function connState(page) {
  return page.evaluate(() => {
    const t = document.body.innerText || "";
    for (const s of ["reconnecting", "connecting", "disconnected", "ready", "connected"])
      if (new RegExp("\\b" + s + "\\b", "i").test(t)) return s;
    return "?";
  });
}
const scrollBottom = (page) => page.evaluate(() => {
  const isS = (el) => { if (!el) return false; const st = getComputedStyle(el).overflowY; return (st === "auto" || st === "scroll") && el.scrollHeight > el.clientHeight + 4; };
  const row = document.querySelector(".message-row"); let el = row ? row.parentElement : null;
  while (el && !isS(el)) el = el.parentElement;
  (el || document.scrollingElement || document.documentElement).scrollTop = 1e9;
}).catch(() => {});
async function seenInRange(page, from, to) {
  await scrollBottom(page); await sleep(250);
  const found = await page.evaluate((run) => {
    const out = []; const re = new RegExp("INCR-" + run + "#(\\d+)~", "g");
    for (const r of document.querySelectorAll(".message-row")) { let m; const t = r.textContent || ""; re.lastIndex = 0; while ((m = re.exec(t))) out.push(+m[1]); }
    return out;
  }, RUN);
  const set = new Set(found.filter((s) => s >= from && s < to));
  return set;
}

async function main() {
  log(`OFFLINE-INCR start RUN=${RUN}`, JSON.stringify(cfg));
  const browser = await chromium.launch({ headless: cfg.headless });
  const ctxA = await browser.newContext();
  const pageA = await login(ctxA, cfg.sender);
  await openPeer(pageA, cfg.receiver);
  log(`发方灌 ${cfg.n} 条基线…`);
  for (let s = 0; s < cfg.n; s++) { await sendText(pageA, tag(s)); await sleep(cfg.gapMs); }
  await sleep(6000);

  // B 冷启拿基线
  const ctxB = await browser.newContext();
  const pageB = await login(ctxB, cfg.receiver);
  pageB.on("console", (m) => { if (["error", "warning"].includes(m.type())) log(`  [B console.${m.type()}]`, m.text().slice(0, 160)); });
  pageB.on("pageerror", (e) => log("  [B pageerror]", String(e).slice(0, 160)));
  pageB.on("requestfailed", (r) => { const u = r.url(); if (/ws|api|auth|token/i.test(u)) log(`  [B reqfailed]`, u.slice(0, 90), r.failure()?.errorText || ""); });
  pageB.on("response", (r) => { const u = r.url(); if (/auth|token/i.test(u)) log(`  [B resp ${r.status()} ${r.request().method()}]`, u.slice(0, 110)); });
  await openPeer(pageB, cfg.sender);
  await sleep(4000);
  const baseSeen = await seenInRange(pageB, 0, cfg.n);
  log(`B 冷启基线可见: ${baseSeen.size}/${cfg.n}`);

  // B 离线(reload 前),A 发增量
  log(`B 即将 reload;先由 A 在“B 离线窗口”发 ${cfg.m} 条增量 seq ${cfg.n}..${cfg.n + cfg.m - 1}`);
  const incrStart = Date.now();
  // 先触发 B reload(离线),再立刻发增量,使增量确实落在 B 离线期间
  const reloadP = pageB.reload({ waitUntil: "domcontentloaded" }).catch(() => {});
  for (let s = cfg.n; s < cfg.n + cfg.m; s++) { await sendText(pageA, tag(s)); await sleep(cfg.gapMs); }
  log(`增量发送完毕(用时 ${Date.now() - incrStart}ms);等 B reload 完成`);
  await reloadP;
  await sleep(2500);

  // B resume:进聊天窗
  log(`B reload 后 URL: ${pageB.url()}`);
  let inChat = await pageB.locator(".composer-input textarea").isVisible().catch(() => false);
  if (!inChat) {
    const row = pageB.locator(".im-conv-item__select, .im-conv-item").first();
    await row.waitFor({ state: "visible", timeout: 30000 }).catch(() => {});
    await row.click().catch(() => {});
    await pageB.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 30000 }).catch(() => {});
    inChat = await pageB.locator(".composer-input textarea").isVisible().catch(() => false);
  }
  log(`B 是否进聊天窗: ${inChat}`);

  // 等到 connected
  let conn = "?";
  for (let i = 0; i < 40; i++) { conn = await connState(pageB); if (conn === "connected" || conn === "ready") break; await sleep(1500); }
  log(`B 连接状态: ${conn}`);

  // connected 后持续盯底部,记录增量到达时间线
  const t0 = Date.now();
  let last = -1;
  while (Date.now() - t0 < cfg.watchMs) {
    const s = await seenInRange(pageB, cfg.n, cfg.n + cfg.m);
    if (s.size !== last) { log(`  +${((Date.now() - t0) / 1000).toFixed(0)}s 增量补拉可见: ${s.size}/${cfg.m}`); last = s.size; }
    if (s.size >= cfg.m) break;
    await sleep(2000);
  }
  const finalSeen = await seenInRange(pageB, cfg.n, cfg.n + cfg.m);

  // 实时探针:resume 后 A 再发 3 条,B 若收到=其实连着(connState 误读);收不到=真断连
  const liveBase = cfg.n + cfg.m + 100;
  log(`实时探针:A 发 3 条 seq ${liveBase}..${liveBase + 2},盯 B 20s`);
  for (let i = 0; i < 3; i++) { await sendText(pageA, tag(liveBase + i)); await sleep(200); }
  let liveSeen = new Set();
  for (let i = 0; i < 10; i++) { liveSeen = await seenInRange(pageB, liveBase, liveBase + 3); if (liveSeen.size >= 3) break; await sleep(2000); }
  log(`实时探针结果: B 收到 ${liveSeen.size}/3 (connState=${await connState(pageB)})`);

  // 也复核基线仍在
  const baseAfter = await seenInRange(pageB, 0, cfg.n);
  log(`OFFLINE-INCR done`, JSON.stringify({
    baseColdSeen: baseSeen.size, baseAfterResume: baseAfter.size,
    incrRecovered: finalSeen.size, incrExpected: cfg.m,
    incrLossPct: +(100 * (cfg.m - finalSeen.size) / cfg.m).toFixed(1),
    connState: conn,
  }));
  await sleep(1500);
  await browser.close();
}
main().catch((e) => { log("FATAL", String(e)); process.exit(1); });
