// Flare Core web app — 冷/热启动 × 超大消息量 历史完整性核验(真实浏览器)。
//
// 目的:发方在一个 1:1 会话里灌 N 条带序号(COLDHOT-RUN#seq~)的消息后,验证:
//   ① 冷启动:全新浏览器 context(空 IndexedDB)登录接收端 → 逐屏上滚翻历史 → 按序号
//      核对能否无损恢复全部 N 条(命中已知坑:新设备 has_more 只看本地页 → 提前"没有更多")。
//   ② 热启动:同 context 重载(暖缓存 + 增量)→ 复核旧历史不丢 + 期间新发的 M 条能增量收到。
// 完整性判据:抓到的 seq 集合 vs 应有的 {0..N-1}(冷)/{0..N+M-1}(热);逐屏上滚累积,
//   规避虚拟化(每行都在某一屏被渲染过一次)。
//
// 运行(有头,可肉眼看):
//   CH_BASE_URL=http://<host> SEND_N=300 node soak/coldhot.mjs   (默认账号 member-000010/11)
//   目标地址必填,脚本从不默认指向任何线上环境。
//   报告落 soak/coldhot-report.json,coldhot.out 有实时汇总。

import { chromium } from "playwright";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const num = (v, d) => (v == null || v === "" ? d : Number(v));
const baseUrl = process.env.CH_BASE_URL;
if (!baseUrl) {
  console.error("CH_BASE_URL is required (example: CH_BASE_URL=http://localhost:1430); coldhot never defaults to a deployed environment.");
  process.exit(2);
}
const cfg = {
  baseUrl,
  sender: process.env.CH_SENDER ?? "member-000010",
  receiver: process.env.CH_RECEIVER ?? "member-000011",
  n: num(process.env.SEND_N, 300), // 冷启动前灌入的消息量(超大消息量)
  m: num(process.env.SEND_M, 20), // 热启动期间新发的增量消息量
  sendGapMs: num(process.env.CH_SEND_GAP_MS, 45), // 每条间隔(护线上)
  headless: process.env.CH_HEADFUL === "0",
};
mkdirSync(HERE, { recursive: true });
const RUN = Date.now().toString(36) + Math.random().toString(36).slice(2, 5);
const REPORT = `${HERE}/coldhot-report.json`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const nowIso = () => new Date().toISOString();
const log = (...a) => console.log(`[${nowIso()}]`, ...a);

const loginButton = /立即登录|Log in/i;
async function login(context, userId) {
  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  // goto 重试:SPA 首页偶发瞬时非 200(如高负载/nginx 抖动),重试数次。
  let gerr;
  for (let a = 0; a < 5; a++) {
    try { await page.goto(`${cfg.baseUrl}/#/login`, { waitUntil: "domcontentloaded" }); gerr = null; break; }
    catch (e) { gerr = e; log(`  goto 重试 ${a + 1}/5: ${String(e).slice(0, 80)}`); await sleep(1500); }
  }
  if (gerr) throw gerr;
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(userId);
  await page.getByRole("button", { name: loginButton }).click();
  await page.waitForURL(/#\/conversations/, { timeout: 90000 });
  return page;
}
async function openPeer(page, peerUserId) {
  await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
  const dialog = page.getByRole("dialog").last();
  await dialog.getByRole("textbox").first().fill(peerUserId);
  const confirm = dialog.getByRole("button", { name: /^(打开|Open)$/i });
  await confirm.click();
  await page.waitForURL(/#\/chat/, { timeout: 30000 });
  await page.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 30000 });
}
async function sendText(page, text) {
  const box = page.locator(".composer-input textarea");
  await box.fill(text);
  await box.press("Enter");
}
const tag = (seq) => `COLDHOT-${RUN}#${seq}~`;

// 逐屏上滚翻历史 + 每屏抓取 seq(累积到 Set),直到到顶且集合稳定(翻历史无更多)。
async function loadAllHistoryAndScrape(page) {
  const seen = new Set();
  const scrape = async () => {
    const found = await page.evaluate((run) => {
      const out = [];
      const re = new RegExp("COLDHOT-" + run + "#(\\d+)~", "g");
      for (const r of document.querySelectorAll(".message-row")) {
        let m; const t = r.textContent || ""; re.lastIndex = 0;
        while ((m = re.exec(t))) out.push(+m[1]);
      }
      return out;
    }, RUN);
    for (const s of found) seen.add(s);
  };
  // 找可滚动祖先并回到底部
  const findScroller = () => {
    const isScrollable = (el) => {
      if (!el) return false;
      const st = getComputedStyle(el).overflowY;
      return (st === "auto" || st === "scroll") && el.scrollHeight > el.clientHeight + 4;
    };
    const row = document.querySelector(".message-row");
    let el = row ? row.parentElement : null;
    while (el && !isScrollable(el)) el = el.parentElement;
    return el || document.scrollingElement || document.documentElement;
  };
  const metrics = () => page.evaluate(`(() => { const c=(${findScroller})(); return { top: Math.round(c.scrollTop), h: Math.round(c.scrollHeight), rows: document.querySelectorAll('.message-row').length, noMore: /没有更多|No more messages|已经到顶|no more/i.test(document.body.innerText||'') }; })()`);

  // Phase 1:反复跳到最顶,耐心等服务端历史回填,直到 scrollHeight 连续多轮不再增长
  //   或出现「没有更多」标记 → 判定历史已全部加载(能加载多少就加载多少)。
  await page.evaluate(`(${findScroller})().scrollTop = (${findScroller})().scrollHeight`);
  await sleep(800);
  let hStable = 0, lastH = -1, mTop = null;
  for (let i = 0; i < 120 && hStable < 5; i++) {
    await page.evaluate(`(${findScroller})().scrollTop = 0`); // 跳到最顶,触发翻历史
    await sleep(1100); // 给服务端历史页回填留足往返时间(比之前 450ms 宽松得多)
    mTop = await metrics();
    if (mTop.h === lastH) hStable++; else hStable = 0;
    lastH = mTop.h;
    if (i % 5 === 0) log(`  Phase1 加载历史: scrollTop=${mTop.top} scrollHeight=${mTop.h} rows=${mTop.rows} noMore=${mTop.noMore} hStable=${hStable}`);
    if (mTop.noMore && mTop.top <= 2) break; // 明确到顶
  }
  log(`  Phase1 完成: 最终 scrollHeight=${mTop?.h} 顶部rows=${mTop?.rows} noMore=${mTop?.noMore}`);

  // Phase 2:从最顶逐屏向下抓取,保证每一行都在某一屏被渲染并扫到。
  await page.evaluate(`(${findScroller})().scrollTop = 0`);
  await sleep(500); await scrape();
  for (let i = 0; i < 500; i++) {
    const atBottom = await page.evaluate(`(() => { const c=(${findScroller})(); c.scrollTop = Math.min(c.scrollHeight, c.scrollTop + c.clientHeight*0.7); return c.scrollTop + c.clientHeight >= c.scrollHeight - 2; })()`);
    await sleep(280); await scrape();
    if (atBottom) { await sleep(300); await scrape(); break; }
    if (i % 20 === 0) log(`  Phase2 抓取中 seen=${seen.size}`);
  }
  return seen;
}

function completeness(seen, from, to) { // [from, to)
  const missing = [];
  for (let s = from; s < to; s++) if (!seen.has(s)) missing.push(s);
  const expected = to - from;
  return {
    expected, recovered: expected - missing.length,
    lossPct: +(100 * missing.length / expected).toFixed(3),
    missingCount: missing.length,
    missingSample: missing.slice(0, 20),
    minSeq: seen.size ? Math.min(...seen) : null,
    maxSeq: seen.size ? Math.max(...seen) : null,
  };
}

async function main() {
  log(`COLDHOT start RUN=${RUN}`, JSON.stringify(cfg));
  const browser = await chromium.launch({ headless: cfg.headless });

  // 1) 发方灌 N 条
  const ctxA = await browser.newContext();
  const pageA = await login(ctxA, cfg.sender);
  await openPeer(pageA, cfg.receiver);
  log(`发方 ${cfg.sender} 已进会话,开始灌 ${cfg.n} 条…`);
  let sendFail = 0;
  const tSeed = Date.now();
  for (let s = 0; s < cfg.n; s++) {
    try { await sendText(pageA, tag(s)); } catch (e) { sendFail++; }
    if (s % 50 === 49) log(`  已发 ${s + 1}/${cfg.n}`);
    await sleep(cfg.sendGapMs);
  }
  const seedMs = Date.now() - tSeed;
  log(`灌完 ${cfg.n} 条,用时 ${seedMs}ms,发送失败 ${sendFail};等 8s 落库…`);
  await sleep(8000);

  // 2) 冷启动:全新 context(空 IndexedDB)
  log(`=== 冷启动:全新浏览器 context 登录 ${cfg.receiver} ===`);
  const ctxCold = await browser.newContext();
  const pageCold = await login(ctxCold, cfg.receiver);
  await openPeer(pageCold, cfg.sender);
  await sleep(3000); // 等 bootstrap/首屏同步
  const coldSeen = await loadAllHistoryAndScrape(pageCold);
  const cold = completeness(coldSeen, 0, cfg.n);
  log(`冷启动完整性: recovered ${cold.recovered}/${cold.expected} loss ${cold.lossPct}% missing ${cold.missingCount} (min ${cold.minSeq} max ${cold.maxSeq})`);
  if (cold.missingCount) log(`  缺失样本: ${JSON.stringify(cold.missingSample)}`);

  // 3) 热启动:期间发方再发 M 条(增量),然后同 context 重载(暖缓存)
  log(`=== 热启动:发方补发 ${cfg.m} 条增量,接收端同 context 重载 ===`);
  let hotSendFail = 0;
  for (let s = cfg.n; s < cfg.n + cfg.m; s++) {
    try { await sendText(pageA, tag(s)); } catch { hotSendFail++; }
    await sleep(cfg.sendGapMs);
  }
  await sleep(3000);
  await pageCold.reload(); // 同 context → IndexedDB 暖缓存 + 增量同步
  await sleep(3000);
  log(`  热启动 reload 后 URL: ${pageCold.url()}`);
  // reload 后可能掉回会话列表/登录页;诊断并稳健地重进聊天窗。
  let inChat = await pageCold.locator(".composer-input textarea").isVisible().catch(() => false);
  if (!inChat) {
    const url = pageCold.url();
    if (/#\/login/.test(url)) {
      log("  ⚠️ reload 后回到登录页(会话未持久化)→ 重新登录");
      await pageCold.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(cfg.receiver).catch(() => {});
      await pageCold.getByRole("button", { name: loginButton }).click().catch(() => {});
      await pageCold.waitForURL(/#\/conversations/, { timeout: 60000 }).catch(() => {});
    }
    // 热恢复后落在会话列表(已登录):点已存在的会话行进入聊天窗,而非新建会话。
    log("  reload 后在会话列表 → 点已存在会话行进入");
    const row = pageCold.locator(".im-conv-item__select, .im-conv-item").first();
    await row.waitFor({ state: "visible", timeout: 30000 }).catch(() => {});
    await row.click().catch((e) => log("  点会话行失败:", String(e).slice(0, 80)));
    await pageCold.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 30000 }).catch(() => {});
    inChat = await pageCold.locator(".composer-input textarea").isVisible().catch(() => false);
    if (!inChat) {
      log("  会话行进入失败 → 回退新建会话");
      await openPeer(pageCold, cfg.sender).catch((e) => log("  重开会话失败:", String(e).slice(0, 80)));
      inChat = await pageCold.locator(".composer-input textarea").isVisible().catch(() => false);
    }
  }
  log(`  热启动最终是否在聊天窗: ${inChat}`);
  await sleep(4000);
  const hotSeen = await loadAllHistoryAndScrape(pageCold);
  const hotAll = completeness(hotSeen, 0, cfg.n + cfg.m); // 旧历史 + 新增量
  const hotIncr = completeness(hotSeen, cfg.n, cfg.n + cfg.m); // 仅增量部分
  log(`热启动总完整性: recovered ${hotAll.recovered}/${hotAll.expected} loss ${hotAll.lossPct}% (min ${hotAll.minSeq} max ${hotAll.maxSeq})`);
  log(`热启动增量部分: recovered ${hotIncr.recovered}/${hotIncr.expected} loss ${hotIncr.lossPct}% missing ${JSON.stringify(hotIncr.missingSample)}`);

  const report = { ts: nowIso(), run: RUN, cfg, seedMs, sendFail, hotSendFail, cold, hotAll, hotIncr };
  writeFileSync(REPORT, JSON.stringify(report, null, 2));
  log("COLDHOT done", JSON.stringify({ cold: cold.lossPct, hotAll: hotAll.lossPct, hotIncr: hotIncr.lossPct }));
  await sleep(2000);
  await browser.close();
}
main().catch((e) => { log("FATAL", String(e)); process.exit(1); });
