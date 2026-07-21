---
name: herdr
description: "herdr-vessel 编排专用：在 herdr 会话内向角色 pane 注入任务、等待角色完成事件、查询花名册状态。不读屏幕——内容一律从 outbox 文件取。仅当 HERDR_ENV=1 且任务是调度 herdr-vessel 团队时使用。"
---

# Herdr（herdr-vessel 编排专用）

> 本文件是 herdr-vessel 的定制 skill，不是 herdr 上游 SKILL.md。
> 设计约束（F001 KD-8）：orchestrator 只用 herdr 做两件事——**发消息**和**等事件**；
> 内容通道不经过终端（不读屏幕），一律走 outbox 文件。

先决条件：`test "${HERDR_ENV:-}" = 1`，否则你不在 herdr 管理的 pane 里，停止。

## 花名册与状态（只读状态位，不读内容）

```bash
herdr agent list                 # 全员花名册：名册名、pane_id、agent_status
herdr agent get <name>           # 单个角色（名册名寻址：first-mate 等）
herdr pane get <pane>            # pane 状态，看 agent_status 字段
herdr agent rename <target> <name>   # 登记/修正名册名
```

- ID 一律从 JSON 输出解析，不手搓、不按位置猜。
- 状态语义：`idle`（空闲可注入）/ `working`（干活中）/ `blocked`（等人操作，升船长）。

## 发任务（唯一的写入动作）

```bash
herdr pane run <pane> "<任务文本>"
```

- 文本+回车一起注入，角色视作一条用户消息。
- **铁律：只往 `idle` 注入**（执法插件会硬拦非 idle 目标，blocked 一律升船长）。
- 注入前先 `herdr pane get <pane>` 确认状态。

## 等完成（事件驱动，不是轮询）

```bash
herdr wait agent-status <pane> --status idle --timeout 1800000
```

- 阻塞等待状态翻转，完成即刻返回，中间不耗 token。
- **等待目标用 `idle`，不用 `done`**：象限布局下同 tab 完成报 `idle`；`done` 仅产生于后台 tab，等它会卡死。
- 等待前若 `pane get` 已是 `idle`（快任务），直接取件，不用等。
- 超时是**查房间隔**不是截止：超时后先 `pane get`，仍 `working` 且进展正常 → 继续等；停滞 → 升船长。

## 内容从哪取（不是屏幕！）

角色完成后的产出读这个文件，**不要** `pane read` / `agent read`：

```
$TEAM_HOME/state/<herdr-session>/outbox/<crew>/latest.md
```

- 角色侧插件在每条最终回复完成时原子覆写此文件（内容 = assistant 原文，逐字精确）。
- 读前校验 mtime ≥ 本棒注入时间，防陈旧件。
- 历史追溯：`$TEAM_HOME/state/<herdr-session>/routes.jsonl` 事件的 `from_session` 字段 → pi 会话文件。

**唯一例外**：角色 `blocked` 或停滞时的现场诊断，允许一次性 `herdr pane read <pane> --source recent-unwrapped --lines 50`——那是升船长前的取证，属于异常路径，不属于调度路径。

## 禁令

- 不关闭、不重命名非你创建的 pane。
- 永不 `herdr server stop`。
- 不向角色 pane 转发大段文件内容；消息只带路径和摘要（产物落文件）。
