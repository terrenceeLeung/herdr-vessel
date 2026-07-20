// @ts-nocheck
// herdr-vessel-ext — 团队纪律执法插件（F001）
//
// 激活方式（环境变量）：
//   TEAM_ROLE=orchestrator      → orchestrator 模式：注入门禁 + 自动记帐 + hop 熔断 + 船长输入自动 reset
//   TEAM_ROLE=<role>            → 角色模式：handoff 形式校验 + git push 红线（Phase B，本版为占位）
//   未设置                       → 完全 no-op
// 紧急总开关：HERDR_VESSEL_EXT=off
//
// 设计原则（F001 KD-2/KD-3）：
//   - 只做形式执法，不做语义判断；
//   - 审计走"观察 tool_result 推导"，不信 orchestrator 自报；
//   - 存储底座复用 $TEAM_HOME/bin/hop.sh，与 prompt 层写同一本账。

import { execFile } from "node:child_process";
import { readFileSync } from "node:fs";
import { promisify } from "node:util";

const execFileP = promisify(execFile);

const TEAM_HOME = process.env.TEAM_HOME ?? `${process.env.HOME}/projects/herdr-vessel`;
const ROLE = process.env.TEAM_ROLE ?? "";
const DISABLED = process.env.HERDR_VESSEL_EXT === "off";
const HOP_BUDGET = 20;
const HOP_SH = `${TEAM_HOME}/bin/hop.sh`;

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
  } catch { /* 读不到就当没有回边（计数恒 0，熔断不触发——fail open，门禁仍工作） */ }
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
// 注意排除 --flag 形式的 target（target 必为第一个非 flag 参数）
const INJECT_RE = /\bherdr\s+pane\s+run\s+([^\s-]\S*)|\bherdr\s+agent\s+send\s+([^\s-]\S*)/;

// git 对外红线（角色模式）：push / publish / release 类
const GIT_REDLINE_RE = /\bgit\s+push\b/;

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

  // ═══════════════ 角色模式（Phase B 占位）═══════════════
  // 计划：agent_end 时校验尾部 handoff block 形式，畸形则 sendUserMessage 就地打回。
  // 本期先落 git 对外红线（OQ-4 窄拦）。
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
}
