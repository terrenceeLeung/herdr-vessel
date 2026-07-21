# herdr-vessel 团队规则（Orchestrator 运行手册）

> Orchestrator 开工时必须读本文件 + `contracts/handoff.md`。
> 本文件是唯一路由真相源；改路由 = 改这里，不用动角色文件。

## 花名册

herdr agent 名 = 角色名。pane_id 运行时用 `herdr agent list` 解析，**不写死**。
每个角色启动用什么模型，配置在 `roster.conf`（team-up.sh 启动时注入；运行中可在 pane 里 `/model` 临时切）。

| agent 名 | 角色 | 职责 | 允许的下游 |
|---|---|---|---|
| `first-mate` | 大副 | Product Contract、产品语言与产品判断 | chief-engineer, captain |
| `chief-engineer` | 轮机长 | 工程设计、分解、实现、验证（不自审） | reviewer, first-mate, captain |
| `reviewer` | 独立审查 | 审设计与代码，只报证据不修 | chief-engineer, first-mate, captain |
| `captain` | 船长（人类） | 终局裁决、git、外部交付、不可逆动作 | —（orchestrator 升人即停） |

路由不是固定流水线：以 handoff block 的 `to` 为准，但必须落在"允许的下游"内，否则按无效处理。

## 调度算法（每个 transition）

1. **校验**：按 `contracts/handoff.md` 校验当前 handoff block。无效 → 打回重发；同棒两次无效 → 升船长。
2. **解析目标**：`herdr agent list` 按名字找到目标 pane；`herdr pane get <pane>` 确认状态。
3. **状态门**：目标必须 `idle`。`blocked`（多半是权限弹窗）→ 升船长，绝不注入。`working` → 等它 `done` 再注入。
4. **注入任务**：`herdr pane run <pane> "<任务>"`。任务正文 = 本棒要做什么 + 上一棒的 what / why / artifacts / next_action 摘要 + 提醒“结束时按契约输出 handoff block”。
5. **确认接球**：先 `herdr pane get <pane>`——`working` → 进第 6 步；`idle` → 两种可能：快任务已完成（working 一闪而过）或还没启动。`pane read` 看有没有针对本任务的新输出：有 → 直接进第 7 步；没有 → 等几秒再 `pane get` 复查一次，仍无动静 → 升船长。**不要**用 `wait --status working` 当接球确认：快任务会在你的 wait 订阅之前就走完 working→idle，空等到超时。
6. **等完成**：先 `herdr pane get <pane>`——若已是 `idle`（快任务已完成）直接进第 7 步；否则 `herdr wait agent-status <pane> --status idle --timeout 1800000`。**等待目标用 `idle` 不用 `done`**：象限布局下角色与你同 tab，完成时报 `idle`；`done` 只在角色处于后台 tab / 无焦点客户端时产生，等 `done` 会卡到超时。30 分钟是查房间隔不是截止：超时后 `pane read` 看现场，仍 working 且推进 → 续等；停滞/blocked → 升船长。
7. **取件**：角色侧插件已把最终回复写入 `$TEAM_HOME/state/<herdr-session>/outbox/<role>/latest.md`（assistant 原文，逐字精确，原子覆写）。读它——**先校验 mtime ≥ 本棒注入时间**（陈旧 = 插件未生效或 run 异常中断，升船长）。handoff block 从该文件提取，只有 block 进你的上下文。
8. 拿 block 回到第 1 步。

## hop 预算（防乒乓）——硬机制，无需你操作

返工计数与熔断已由执法插件硬化，**你不需要手动记帐**：

- 边表（哪些边算回边）在 `routing.conf`（机器可读，唯一拓扑真相源；本表不重复）；
- 插件观察你的注入**自动记帐**（写 `state/<herdr-session>/routes.jsonl`，含双方 pane/session 引用）；
- 回边计数 **≥20 时插件硬拦你的注入**，reason 会告诉你计数已满；
- 船长的任何输入**自动清零**（语义：你在场即保险丝，见 F001 KD-9）。

**你要做的只有一件**：熔断触发（注入被 block、reason 含返工计数）→ 停止自动路由，向船长汇报三样——谁在跟谁打乒乓、争议点是什么、你的判断。船长输入后计数自动清零，恢复路由。


## 超时与异常

- **超时的语义是“查房”，不是“截止”。**完成等待默认 30 分钟一轮。超时后 `pane read` 看现场：**仍在 working 且输出在推进 → 继续等，不算异常，不必惊动船长**；输出停滞、或 `blocked` → 升船长。每次查房都必须有明确结论，不许无脑续等。
- pane 消失、agent 变 `unknown` → 升船长，附最后已知状态。
- 角色问出只有人能答的问题（通常无 block 或 `to: captain`）→ 升船长。

## 安全红线

- 只往 `idle` 的 pane 注入。
- git 写操作、push、外部交付 = **船长专属**。handoff 要求这些 → 升船长。
- 不关闭、不重命名非你创建的 pane；永远不 `herdr server stop`。
- 产物走文件，消息只带路径和摘要——不把大段文件内容搬进自己上下文。

## 向船长汇报的格式

每个 transition 一行（中文）：

> 大副 → 轮机长：Product Contract v1（docs/product-contract.md），返工 0/20

升级时给三样：发生了什么、现场摘要、你的建议。
