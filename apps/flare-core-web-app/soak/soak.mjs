// Flare Core web app — 12h soak / reliability harness (real browser composer input).
//
// 打 SOAK_BASE_URL 指向的 web app(必填,脚本从不默认指向任何线上环境),用两个真实浏览器实例
// + 两个账号(SOAK_A / SOAK_B,必填)通过真 composer 互发消息,严格核账「丢失 / 乱序 / 延迟」,并周期性:
//   ① 瞬时大消息量 burst(单聊)
//   ② 连接掉线注入 + 自愈核验(验证 self-heal 修复,12h 不掉线)
//   ③ 10万大群 burst(周期性发几百条;客户端可观测退化 → 自动退避,保护生产)
//
// ⚠️ 生产·有真实用户:一切以「不打挂线上」为先。10万群 burst 有安全阀:
//    发送 p95 延迟或失败率超阈值即停掉后续 10万群 burst 并告警(见 BIG_* + backoff)。
//    服务端 Redis/内部读不了(策略拦截),只能用客户端可观测信号做退化代理。
//
// 运行(本机,跑满 12h):
//   cd examples/flare-core-web-app
//   SOAK_BASE_URL=http://<host> SOAK_A=<user> SOAK_B=<user> SOAK_BIG_CONV=<大群会话 id> \
//     nohup node soak/soak.mjs > soak/soak.out 2>&1 &
//   (不跑 10万群 burst 时 SOAK_BIG=0,可不给 SOAK_BIG_CONV)
//   报告落 soak/soak-report.jsonl,每 REPORT_MS 一行;soak.out 有实时汇总。
// 停止:kill 该进程即可(优雅落一份最终报告靠 SIGINT: kill -INT <pid>)。

import { chromium } from "playwright";
import { appendFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const num = (v, d) => (v == null || v === "" ? d : Number(v));
// 目标环境与账号必须显式给出:这个 harness 会往目标环境持续发消息,不能有一个「默认就打线上」的路径。
const required = (name, example) => {
  const value = process.env[name];
  if (!value) {
    console.error(`${name} is required (example: ${name}=${example}); soak never defaults to a deployed environment.`);
    process.exit(2);
  }
  return value;
};
const big = process.env.SOAK_BIG !== "0";
const cfg = {
  baseUrl: required("SOAK_BASE_URL", "http://localhost:1430"),
  userA: required("SOAK_A", "member-000010"),
  userB: required("SOAK_B", "member-000011"),
  durationMs: num(process.env.SOAK_DURATION_MS, 12 * 60 * 60 * 1000), // 12h
  steadyMs: num(process.env.SOAK_STEADY_MS, 5000), // 每 5s 一条稳态
  burstEveryMs: num(process.env.SOAK_BURST_EVERY_MS, 30 * 60 * 1000), // 每 30min 一次单聊 burst
  burstSize: num(process.env.SOAK_BURST_SIZE, 50),
  healEveryMs: num(process.env.SOAK_HEAL_EVERY_MS, 20 * 60 * 1000), // 每 20min 注入一次掉线
  reportMs: num(process.env.SOAK_REPORT_MS, 5 * 60 * 1000), // 每 5min 落盘报告
  // 10万群(可关:SOAK_BIG=0;开着时会话 id 必填)
  big,
  bigMember: process.env.SOAK_BIG_MEMBER ?? "member-000000",
  bigConvId: big ? required("SOAK_BIG_CONV", "<conversation id of the large group>") : "",
  bigEveryMs: num(process.env.SOAK_BIG_EVERY_MS, 60 * 60 * 1000), // 每 1h 一次大群 burst
  bigBurst: num(process.env.SOAK_BIG_BURST, 200), // 每次几百条
  // 安全阀:发送延迟/失败率退化即停 10万群 burst
  sendLatencyP95AbortMs: num(process.env.SOAK_ABORT_P95_MS, 8000),
  sendFailRateAbort: num(process.env.SOAK_ABORT_FAILRATE, 0.1),
  headless: process.env.SOAK_HEADFUL !== "1",
};

// 可指定独立报告文件(SOAK_REPORT_FILE),避免并发实例污染同一份 soak-report.jsonl。
const REPORT = process.env.SOAK_REPORT_FILE
  ? (process.env.SOAK_REPORT_FILE.startsWith("/") ? process.env.SOAK_REPORT_FILE : `${HERE}/${process.env.SOAK_REPORT_FILE}`)
  : `${HERE}/soak-report.jsonl`;
mkdirSync(HERE, { recursive: true });
const t0 = Date.now();
// 每轮唯一 RUN-ID:tag 带上它,poll 只认本轮 → 忽略会话历史里之前轮次残留的 SOAK 消息
// (否则旧消息被计入 → recv>sent、乱序爆表、延迟为分钟级历史时间戳)。
const RUN = Date.now().toString(36) + Math.random().toString(36).slice(2, 5);
const nowIso = () => new Date().toISOString();
const log = (...a) => console.log(`[${nowIso()}]`, ...a);

// ---- 全局统计 ----
const stat = {
  ab: dirStat(), // A→B
  ba: dirStat(), // B→A
  reconnects: 0,
  healInjected: 0,
  healRecovered: 0,
  healFailed: 0,
  bigBursts: 0,
  bigSent: 0,
  bigSendMs: [], // 大群发送耗时样本(近窗口)
  bigAborted: false,
  sendMs: [], // 单聊发送耗时样本(近窗口)
  sendFail: 0,
  sendTotal: 0,
  errors: [],
};
function dirStat() {
  return { sent: 0, recv: 0, dup: 0, outOfOrder: 0, maxSeqSeen: -1, seen: new Set(), latMs: [] };
}
function pct(arr, p) {
  if (!arr.length) return null;
  const s = [...arr].sort((x, y) => x - y);
  return Math.round(s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))]);
}
function pushCapped(arr, v, cap = 2000) {
  arr.push(v);
  if (arr.length > cap) arr.splice(0, arr.length - cap);
}

const loginButton = /立即登录|Log in/i;
async function login(context, userId) {
  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  await page.goto(`${cfg.baseUrl}/#/login`);
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

// WS 探针:登录前注入,记录 live socket 供自愈注入(close 当前 socket)。
// ⚠️ 收方核账不走 WS 帧:消息帧是二进制 msgpack + gzip payload,黑盒解不划算;改走 DOM。
async function installWsSpy(context) {
  await context.addInitScript(() => {
    const w = window;
    if (w.__soakWs) return;
    w.__soakWs = { sockets: 0, last: null };
    const origSend = WebSocket.prototype.send;
    WebSocket.prototype.send = function (...a) {
      w.__soakWs.last = this;
      return origSend.apply(this, a);
    };
    const Native = w.WebSocket;
    w.WebSocket = function (...a) {
      const ws = new Native(...a);
      w.__soakWs.sockets++;
      w.__soakWs.last = ws;
      return ws;
    };
    w.WebSocket.prototype = Native.prototype;
    Object.assign(w.WebSocket, Native);
  });
}
async function connState(page) {
  return page.evaluate(() => {
    const t = document.body.innerText || "";
    for (const s of ["reconnecting", "connecting", "disconnected", "ready", "connected"])
      if (new RegExp("\\b" + s + "\\b", "i").test(t)) return s;
    return "?";
  });
}

// 收方:轮询 DOM message-row,提取本方向的 tag(#seq @sendMs~),核账丢失/乱序/延迟。
// ⚠️ tag 末尾必须有终止符 ~,否则 @<ms> 会贪婪吞掉消息渲染时间的数字(致延迟为垃圾负数)。
function tagFor(dir, seq, ms) {
  return `SOAK-${RUN}-${dir}#${seq}@${ms}~`;
}
// 收方 DOM 扫描:读渲染出的 message-row 里**本轮 RUN**的本方向 tag(忽略历史残留)。
// ⚠️ 局限:消息列表虚拟化 → burst 期快速渲染又滚出 DOM 的消息可能漏读 → 稳态准确、
//    burst 窗口的 loss 是「上界」(可能含扫描漏读,非真丢)。真丢需 app 内 SDK 埋点。
// 根治长时程 recv 冻结:抓取前把消息列表可滚动祖先强制滚到底,让最新行进入虚拟化窗口。
//   (burst/heal 会把视图滚离底部 → 新消息渲染到可视区外 → 抓取器反复读同一批冻结行。)
async function scrollReceiverToBottom(page) {
  try {
    await page.evaluate(() => {
      const isScrollable = (el) => {
        if (!el) return false;
        const st = getComputedStyle(el).overflowY;
        return (st === "auto" || st === "scroll") && el.scrollHeight > el.clientHeight + 4;
      };
      const row = document.querySelector(".message-row");
      let el = row ? row.parentElement : null;
      while (el && !isScrollable(el)) el = el.parentElement; // 向上找最近可滚动祖先
      const target = el || document.scrollingElement || document.documentElement;
      if (target) target.scrollTop = target.scrollHeight;
    });
  } catch { /* 页面切换/导航瞬间可能失败,忽略 */ }
}
async function pollReceipts(page, dir) {
  await scrollReceiverToBottom(page);
  await sleep(120); // 等虚拟化按新滚动位置补渲染最新行
  const found = await page.evaluate((run) => {
    const out = [];
    const rows = document.querySelectorAll(".message-row");
    const re = new RegExp("SOAK-" + run + "-(AB|BA)#(\\d+)@(\\d+)~", "g");
    for (const r of rows) {
      let m;
      const txt = r.textContent || "";
      re.lastIndex = 0;
      while ((m = re.exec(txt))) out.push({ dir: m[1], seq: +m[2], ms: +m[3] });
    }
    return out;
  }, RUN);
  const at = Date.now();
  const d = dir === "AB" ? stat.ab : stat.ba;
  for (const it of found) {
    if (it.dir !== dir) continue;
    if (d.seen.has(it.seq)) continue;
    d.seen.add(it.seq);
    d.recv++;
    if (it.seq < d.maxSeqSeen) d.outOfOrder++;
    d.maxSeqSeen = Math.max(d.maxSeqSeen, it.seq);
    pushCapped(d.latMs, at - it.ms);
  }
}

let running = true;
function snapshot(final = false) {
  const elapsedH = ((Date.now() - t0) / 3600000).toFixed(3);
  const line = {
    ts: nowIso(),
    elapsedH: Number(elapsedH),
    final,
    ab: {
      sent: stat.ab.sent,
      recv: stat.ab.recv,
      lossPct: stat.ab.sent ? +(100 * (1 - stat.ab.recv / stat.ab.sent)).toFixed(3) : 0,
      outOfOrder: stat.ab.outOfOrder,
      latP50: pct(stat.ab.latMs, 50),
      latP99: pct(stat.ab.latMs, 99),
    },
    ba: {
      sent: stat.ba.sent,
      recv: stat.ba.recv,
      lossPct: stat.ba.sent ? +(100 * (1 - stat.ba.recv / stat.ba.sent)).toFixed(3) : 0,
      outOfOrder: stat.ba.outOfOrder,
      latP50: pct(stat.ba.latMs, 50),
      latP99: pct(stat.ba.latMs, 99),
    },
    conn: { reconnects: stat.reconnects, healInjected: stat.healInjected, healRecovered: stat.healRecovered, healFailed: stat.healFailed },
    send: { total: stat.sendTotal, fail: stat.sendFail, p95Ms: pct(stat.sendMs, 95) },
    big: { bursts: stat.bigBursts, sent: stat.bigSent, sendP95Ms: pct(stat.bigSendMs, 95), aborted: stat.bigAborted },
    errors: stat.errors.slice(-5),
  };
  appendFileSync(REPORT, JSON.stringify(line) + "\n");
  log("REPORT", JSON.stringify(line));
  return line;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function timedSend(page, text) {
  const s = Date.now();
  stat.sendTotal++;
  try {
    await sendText(page, text);
    pushCapped(stat.sendMs, Date.now() - s);
  } catch (e) {
    stat.sendFail++;
    stat.errors.push(`send: ${String(e).slice(0, 120)}`);
  }
}

async function main() {
  log("SOAK start RUN=" + RUN, JSON.stringify({ ...cfg }));
  const browser = await chromium.launch({ headless: cfg.headless });
  const ctxA = await browser.newContext();
  const ctxB = await browser.newContext();
  await installWsSpy(ctxA);
  await installWsSpy(ctxB);
  const pageA = await login(ctxA, cfg.userA);
  const pageB = await login(ctxB, cfg.userB);
  await openPeer(pageA, cfg.userB);
  await openPeer(pageB, cfg.userA);
  log("logged in + conversations open", cfg.userA, "<->", cfg.userB);

  // 10万群成员上下文(可选)
  let ctxBig, pageBig;
  if (cfg.big) {
    try {
      ctxBig = await browser.newContext();
      await installWsSpy(ctxBig);
      pageBig = await login(ctxBig, cfg.bigMember);
      log("big-group member logged in", cfg.bigMember);
    } catch (e) {
      log("WARN big-group member login failed; disabling big bursts:", String(e).slice(0, 160));
      cfg.big = false;
      stat.errors.push(`big-login: ${String(e).slice(0, 120)}`);
    }
  }

  // 收方轮询器
  const pollTimer = setInterval(async () => {
    if (!running) return;
    try {
      await pollReceipts(pageB, "AB");
      await pollReceipts(pageA, "BA");
    } catch (e) {
      stat.errors.push(`poll: ${String(e).slice(0, 100)}`);
    }
  }, 500);

  let seqAB = 0, seqBA = 0;
  let lastBurst = Date.now(), lastHeal = Date.now(), lastBig = Date.now(), lastReport = Date.now();

  while (running && Date.now() - t0 < cfg.durationMs) {
    // 稳态:双向各发一条带 tag 的消息
    await timedSend(pageA, tagFor("AB", ++seqAB, Date.now())); stat.ab.sent++;
    await timedSend(pageB, tagFor("BA", ++seqBA, Date.now())); stat.ba.sent++;

    // 瞬时 burst(单聊)
    if (Date.now() - lastBurst >= cfg.burstEveryMs) {
      lastBurst = Date.now();
      log(`BURST ${cfg.burstSize} A→B`);
      for (let i = 0; i < cfg.burstSize && running; i++) {
        await timedSend(pageA, tagFor("AB", ++seqAB, Date.now())); stat.ab.sent++;
      }
    }

    // 掉线注入 + 自愈核验(验证 self-heal 修复)
    if (Date.now() - lastHeal >= cfg.healEveryMs) {
      lastHeal = Date.now();
      stat.healInjected++;
      log("HEAL inject: close A live WS");
      const before = seqAB;
      try {
        await pageA.evaluate(() => { try { window.__soakWs?.last?.close(4009, "soak-heal"); } catch {} });
        // 等自愈:visibility 触发 + 轮询 ready(最长 ~90s)
        await pageA.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
        let ok = false;
        for (let i = 0; i < 90 && running; i++) {
          const s = await connState(pageA);
          if (s === "ready" || s === "connected") { ok = true; break; }
          await sleep(1000);
        }
        // 愈后发一条,确认无丢失
        await timedSend(pageA, tagFor("AB", ++seqAB, Date.now())); stat.ab.sent++;
        if (ok) { stat.healRecovered++; log("HEAL recovered"); }
        else { stat.healFailed++; log("HEAL FAILED to recover within 90s"); }
      } catch (e) {
        stat.healFailed++;
        stat.errors.push(`heal: ${String(e).slice(0, 120)}`);
      }
    }

    // 10万群 burst(周期,带安全阀退避)
    if (cfg.big && pageBig && !stat.bigAborted && Date.now() - lastBig >= cfg.bigEveryMs) {
      lastBig = Date.now();
      try {
        // 首次打开大群会话
        if (!pageBig.__opened) {
          await openBigConversation(pageBig, cfg.bigConvId, cfg.bigMember);
          pageBig.__opened = true;
        }
        // 安全阀:近窗口单聊发送 p95 或失败率退化则不做大群 burst
        const p95 = pct(stat.sendMs, 95) ?? 0;
        const failRate = stat.sendTotal ? stat.sendFail / stat.sendTotal : 0;
        if (p95 > cfg.sendLatencyP95AbortMs || failRate > cfg.sendFailRateAbort) {
          stat.bigAborted = true;
          log(`BIG ABORT: degradation detected (sendP95=${p95}ms failRate=${failRate.toFixed(3)}) — skipping all future 100k bursts`);
        } else {
          log(`BIG burst ${cfg.bigBurst} -> ${cfg.bigConvId}`);
          stat.bigBursts++;
          for (let i = 0; i < cfg.bigBurst && running; i++) {
            const s = Date.now();
            await sendText(pageBig, `SOAK-${RUN}-BIG#${stat.bigSent}@${Date.now()}~`);
            pushCapped(stat.bigSendMs, Date.now() - s);
            stat.bigSent++;
            // 每 20 条重新查退化,及时退避
            if (i % 20 === 19) {
              const bp95 = pct(stat.bigSendMs, 95) ?? 0;
              if (bp95 > cfg.sendLatencyP95AbortMs) {
                stat.bigAborted = true;
                log(`BIG ABORT mid-burst: bigSendP95=${bp95}ms — stopping`);
                break;
              }
            }
          }
        }
      } catch (e) {
        stat.errors.push(`big: ${String(e).slice(0, 140)}`);
        log("BIG error:", String(e).slice(0, 160));
      }
    }

    // 周期报告
    if (Date.now() - lastReport >= cfg.reportMs) {
      lastReport = Date.now();
      snapshot(false);
    }

    await sleep(cfg.steadyMs);
  }

  clearInterval(pollTimer);
  // 收尾多轮 poll,给在途消息落账
  for (let i = 0; i < 10; i++) { await pollReceipts(pageB, "AB"); await pollReceipts(pageA, "BA"); await sleep(1000); }
  const fin = snapshot(true);
  log("SOAK done", JSON.stringify(fin));
  await browser.close();
}

async function openBigConversation(page, convId, _member) {
  // 大群通过「新建会话/打开」输入群会话 ID 打开;若 UI 不支持直接输 CID,回退用 hash 路由。
  try {
    await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
    const dialog = page.getByRole("dialog").last();
    await dialog.getByRole("textbox").first().fill(convId);
    const confirm = dialog.getByRole("button", { name: /^(打开|Open)$/i });
    await confirm.click();
  } catch {
    await page.goto(`${cfg.baseUrl}/#/chat/${convId}`);
  }
  await page.locator(".composer-input textarea").waitFor({ state: "visible", timeout: 45000 });
}

process.on("SIGINT", () => { log("SIGINT — finalizing"); running = false; });
process.on("SIGTERM", () => { running = false; });
main().catch((e) => { log("FATAL", String(e)); snapshot(true); process.exit(1); });
