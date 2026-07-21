// @ts-nocheck
// herdr-vessel-ext — 团队纪律执法插件（F001）
//
// 激活方式（环境变量）：
//   TEAM_ROLE=orchestrator      → orchestrator 模式：注入门禁 + 自动记帐 + hop 熔断 + 船长输入自动 reset
//   TEAM_ROLE=<role>            → 角色模式：outbox 导出 + handoff 形式校验与就地打回 + git push 红线
//   未设置                       → 完全 no-op
// 紧急总开关：HERDR_VESSEL_EXT=off
//
// 设计原则（F001 KD-2/KD-3）：
//   - 只做形式执法，不做语义判断；
//   - 审计走"观察 tool_result 推导"，不信 orchestrator 自报；
//   - 存储底座复用 $TEAM_HOME/state/<herdr-session>/，与 hop.sh 写同一本账。

import { execFile } from "node:child_process";
import {
  readFileSync, writeFileSync, renameSync, appendFileSync, mkdirSync,
} from "node:fs";
import path from "node:path";
import { promisify } from "node:util";

const execFileP = promisify(execFile);

const TEAM_HOME = process.env.TEAM_HOME ?? `${process.env.HOME}/projects/herdr-vessel`;
const ROLE = process.env.TEAM_ROLE ?? "";
const DISABLED = process.env.HERDR_VESSEL_EXT === "off";
const HOP_BUDGET = 20;
const HOP_SH = `${TEAM_HOME}/bin/hop.sh`;
const MAX_BOUNCES = 2;

// ── herdr session 名推导（与 hop.sh 同逻辑）─────────────────────
function sessionName() {
  const sock = process.env.HERDR_SOCKET_PATH ?? "";
  if (!sock) return "default";
  const d1 = path.basename(path.dirname(sock));
  const d2 = path.basename(path.dirname(path.dirname(sock)));
  return d2 === "sessions" ? d1 : "default";
}

function stateDir() {
  const dir = path.join(TEAM_HOME, "state", sessionName());
  mkdirSync(dir, { recursive: true });
  return dir;
}

// ── 边表（routing.conf，唯一拓扑真相源）──────────────────────────
function loadBackEdges() {
  const edges = new Set();
  try {
    for (const line of readFileSync(`${TEAM_HOME}/routing.conf`, "utf8").split("\n")) {
      const t = line.trim();
      if (!t || t.startsWith("#")) continue;
      const m = t.match(/^(\S+)\s*->\s*(\S+)$/);
      if (m) edges.add(`${m[1]} -> ${m[2]}`);
    }
  } catch { /* 读不到就当没有回边（fail open，门禁仍工作） */ }
  return edges;
}

// ── herdr / hop.sh 子进程封装 ────────────────────────────────────
async function sh(cmd, args, timeoutMs = 8000) {
  try {
    const { stdout } = await execFileP(cmd, args, { timeout: timeoutMs });
    return stdout.trim();
  } catch {
    return "";
  }
}

async function paneStatus(target) {
  const out = await sh("herdr", ["pane", "get", target]);
  const m = out.match(/"agent_status"\s*:\s*"(\w+)"/);
  return m?.[1] ?? ""; // 空 = 非 agent pane（普通 shell），不在门禁范围
}

async function agentNameOf(target) {
  const out = await sh("herdr", ["pane", "get", target]);
  // 自定义名册名在 label 字段（agent rename 设置）；为空则退回检测标签
  return out.match(/"label"\s*:\s*"([^"]+)"/)?.[1]
      ?? out.match(/"agent"\s*:\s*"([^"]+)"/)?.[1]
      ?? target;
}

async function hopCount() {
  const out = await sh(HOP_SH, ["count"]);
  return parseInt(out, 10) || 0;
}

// 注入类命令：herdr pane run <pane> "..." 或 herdr agent send <target> ...
const INJECT_RE = /\bherdr\s+pane\s+run\s+([^\s-]\S*)|\bherdr\s+agent\s+send\s+([^\s-]\S*)/;

// git 对外红线（角色模式）：push / publish / release 类
const GIT_REDLINE_RE = /\bgit\s+push\b/;

// ── handoff block 提取与形式校验（角色模式）──────────────────────
const HANDOFF_ROLES = ["first-mate", "chief-engineer", "reviewer", "captain"];

function extractText(msg) {
  const c = msg?.content;
  if (typeof c === "string") return c;
  if (!Array.isArray(c)) return "";
  return c.filter((b) => b?.type === "text").map((b) => b.text ?? "").join("\n");
}

// 提取最后一个 ```handoff 块；返回出现次数、是否在输出最末尾
function extractHandoff(text) {
  const re = /```handoff\s*\n([\s\S]*?)```/g;
  let m, last = null, count = 0;
  while ((m = re.exec(text)) !== null) { last = m; count++; }
  if (!last) return { found: false, count: 0 };
  const after = text.slice(last.index + last[0].length).trim();
  return { found: true, count, body: last[1], atEnd: after === "" };
}

function validateHandoff(body) {
  const problems = [];
  const field = (k) => body.match(new RegExp(`^${k}\\s*:\\s*(.*)$`, "m"))?.[1]?.trim();
  const hasKey = (k) => new RegExp(`^${k}\\s*:`, "m").test(body);

  const to = field("to");
  if (!to) problems.push("missing field: to");
  else if (!HANDOFF_ROLES.includes(to)) problems.push(`to '${to}' not in enum (${HANDOFF_ROLES.join(" | ")})`);
  for (const k of ["what", "why", "next_action"]) {
    if (!field(k)) problems.push(`missing field: ${k}`);
  }
  for (const k of ["artifacts", "open_questions"]) {
    if (!hasKey(k)) problems.push(`missing field: ${k}`);
  }
  return { problems, to: to ?? null };
}

// ════════════════════════════════════════════════════════════════
export default function (pi) {
  if (DISABLED || !ROLE) return;

  // ═══════════════ orchestrator 模式（Phase A）═══════════════
  if (ROLE === "orchestrator") {
    const backEdges = loadBackEdges();
    let lastTarget = null; // 球当前在谁手里（上一个被成功注入的角色）

    // A1 注入门禁 + A3 hop 熔断：拦在 tool_call 执行前
    pi.on("tool_call", async (event) => {
      if (event.toolName !== "bash") return;
      const cmd = event.input?.command ?? "";
      const m = cmd.match(INJECT_RE);
      if (!m) return;
      const target = m[1] ?? m[2];

      const status = await paneStatus(target);
      if (status && status !== "idle") {
        return {
          block: true,
          reason: `[herdr-vessel] 门禁：目标 ${target} 当前为 ${status}，只允许往 idle 注入。` +
                  (status === "blocked" ? "blocked = 权限/信任确认等人操作，升船长处理。" : "等它 done 再注入。"),
        };
      }

      const count = await hopCount();
      if (count >= HOP_BUDGET) {
        return {
          block: true,
          reason: `[herdr-vessel] 熔断：返工计数 ${count}/${HOP_BUDGET} 已满。停止自动路由，向船长汇报乒乓现场；` +
                  `船长输入后计数自动清零。`,
        };
      }
    });

    // A2 自动记帐：观察成功的注入，自己推导 from/to 和边分类
    pi.on("tool_result", async (event) => {
      if (event.toolName !== "bash" || event.isError) return;
      const cmd = event.input?.command ?? "";
      const m = cmd.match(INJECT_RE);
      if (!m) return;
      const target = m[1] ?? m[2];

      const toName = await agentNameOf(target);
      const fromName = lastTarget ?? "captain";
      const kind = backEdges.has(`${fromName} -> ${toName}`) ? "incr" : "route";
      await sh(HOP_SH, [kind, "--from", fromName, "--to", toName, "--what", "(auto-audit by extension)"]);
      lastTarget = toName;
    });

    // OQ-2 船长输入自动 reset：interactive 输入 = 人工保险丝
    pi.on("input", async (event) => {
      if (event.source !== "interactive") return;
      await sh(HOP_SH, ["reset", "captain input (auto)"]);
    });

    return;
  }

  // ═══════════════ 角色模式（Phase B）═══════════════
  const CREW = ROLE;
  let bounceCount = 0;

  function outboxDir() {
    const dir = path.join(stateDir(), "outbox", CREW);
    mkdirSync(dir, { recursive: true });
    return dir;
  }

  // 原子写 latest.md（tmp + rename，防半截读）
  function writeOutbox(text) {
    const dir = outboxDir();
    const tmp = path.join(dir, ".latest.md.tmp");
    writeFileSync(tmp, text, "utf8");
    renameSync(tmp, path.join(dir, "latest.md"));
  }

  function appendLegComplete(handoffTo) {
    const rec = {
      type: "leg_complete",
      ts: new Date().toISOString(),
      session: sessionName(),
      role: CREW,
      handoff_to: handoffTo,
    };
    try {
      appendFileSync(path.join(stateDir(), "routes.jsonl"), JSON.stringify(rec) + "\n");
    } catch { /* 日志失败不阻断主流程 */ }
  }

  // git 对外红线（OQ-4 窄拦）
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = event.input?.command ?? "";
    if (GIT_REDLINE_RE.test(cmd)) {
      return {
        block: true,
        reason: `[herdr-vessel] 红线：git 对外操作归船长。请用 handoff block（to: captain）请求交付。`,
      };
    }
  });

  // B1 outbox 导出 + B2 handoff 形式校验（同一 message_end 挂钩）
  pi.on("message_end", async (event) => {
    const msg = event.message;

    // 新用户任务重置打回计数；我们自己的打回话术不算新任务
    if (msg?.role === "user") {
      const t = extractText(msg);
      if (!t.startsWith("Your handoff block was invalid:")) bounceCount = 0;
      return;
    }

    if (msg?.role !== "assistant") return;
    if (msg.stopReason !== "stop") return; // toolUse/aborted/error/length 全部排除

    const text = extractText(msg);
    if (!text.trim()) return;

    // ── B2 先校验 ──
    const h = extractHandoff(text);
    if (h.found) {
      const problems = [];
      if (h.count > 1) problems.push(`expected exactly 1 handoff block, found ${h.count}`);
      if (!h.atEnd) problems.push("handoff block must be the LAST thing in your output");
      const v = validateHandoff(h.body);
      problems.push(...v.problems);

      if (problems.length > 0) {
        bounceCount++;
        if (bounceCount <= MAX_BOUNCES) {
          // 话术真相源：contracts/handoff.md（改话术两处同步）
          await pi.sendUserMessage(
            `Your handoff block was invalid: ${problems.join("; ")}. ` +
            "Re-emit ONLY the corrected ```handoff block as the last thing in your output. Do not redo the work.",
            { deliverAs: "followUp" },
          );
        }
        // 畸形不写盘（outbox 保持上一棒；超 2 次则留给 orch 的 mtime 校验升船长）
        return;
      }

      // ── B1 合格后写盘 ──
      bounceCount = 0;
      writeOutbox(text);
      appendLegComplete(v.to);
      return;
    }

    // 无 block = 合法（角色认为工作未完或需要船长）→ 写盘，orch 判读
    bounceCount = 0;
    writeOutbox(text);
    appendLegComplete(null);
  });
}
