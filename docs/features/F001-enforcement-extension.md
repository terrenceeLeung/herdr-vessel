---
feature_ids: [F001]
related_features: []
topics: [pi-extension, enforcement, audit, orchestration]
doc_kind: spec
created: 2026-07-20
---

# F001: herdr-vessel 强制执行插件（pi extension）

> **Status**: in-progress | **Owner**: tianyiliang | **Priority**: P1

## CVO Page（CVO 验收层）

> 规则：未出现在本节的内容不构成对 CVO 的承诺；本节禁止实现细节；**CVO 未签字 = 未立项，不得开工**。
> 覆盖范围 = 当前现实要交付的内容（Phase A + Phase B）。

- **意图**（两句话，CVO 的语言，永远必填）：现在团队调度里"该做什么"全靠 agent 自觉——忘了记帐、往卡住的 pane 里注入、乒乓 20 次不停，全都防不住。这个插件把这些纪律变成**过不了的门**：不守规矩的操作直接被拦下，审计从"它自己说"变成"机制在看"。
- **非目标**（永远必填）：不改变角色的工作内容与路由规则（TEAM.md / handoff 契约原样）；不做语义判断（球合不合理、该不该打回，仍是模型的事）；不替代 prompt 层，只做执法层。
- **AC-cvo**（三态选一）：
  - ① 可体验（≤5 条"做什么 → 看到什么"句式 + 两分钟 demo 脚本）：
    - [ ] 让 orchestrator 往一个 blocked 的角色 pane 注入任务 → 看到该操作被插件拦下，提示"目标 blocked，升船长或等待"
    - [ ] 让 orchestrator 完成一次路由但**故意不调 hop.sh** → 看到 routes.jsonl 里仍然出现了这条路由记录（插件观察写入）
    - [ ] 构造 20 次返工 → 看到第 21 次注入被拦下，提示必须升船长
    - [ ] 让某角色输出一个字段残缺的 handoff block → 看到该角色 pane 当轮就收到打回指令并补发，orchestrator 无感知
- **CVO 签字**：tianyiliang

## 诉求对照表（CVO 原始诉求 → 归属）

- [ ] "是否有办法通过 extension 重型拦截事件，我觉得更正确" → Phase A
- [ ] "审计/计数靠自觉调用 hop.sh，忘记怎么办"（软点 S1）→ Phase A（自动记帐）
- [ ] "只往 idle 注入，blocked 绝不代答"（软点 S2）→ Phase A（注入门禁）
- [ ] "hop ≥ 20 停下" 从请求变成断路器（软点 S3）→ Phase A（熔断）
- [ ] "角色侧 handoff 形式校验，就地打回" → Phase B

## Why

当前系统的软/硬盘点结论：**"做了之后怎么处理"全是硬的（hop.sh、team-up.sh、integration），"做不做"全是软的（两个 LLM 的自觉）**。最危险的三个软点全部集中在 orchestrator 的纪律上：忘记帐（S1，审计缺失 + 熔断失效）、往 blocked/working 注入（S2，可能替人按权限弹窗）、hop 超限不停（S3，熔断形同虚设）。

已核实的技术事实（pi extension API）：

- `tool_call` 事件可返回 `{ block: true, reason }` **硬拦任何工具调用**（含 bash）；
- `tool_result` 可中间件式观察/改写结果；
- `agent_end` 携带 `event.messages`（结构化消息真相，非屏幕抓取）；
- `pi.sendUserMessage(content, { deliverAs })` 可在 pane 内部注入用户消息并触发新 turn。

## What

一个 pi extension（`herdr-vessel-ext`），装全局 `~/.pi/agent/extensions/`，**按环境变量激活**，未设置时完全 no-op：

| 环境变量 | 激活模式 |
|---|---|
| `TEAM_ROLE=orchestrator` | Phase A 全部能力 |
| `TEAM_ROLE=first-mate` 等角色名 | Phase B 能力 |
| 未设置 | no-op（不影响日常用 pi） |

接线：`team-up.sh` 给角色 pane 加 `--env TEAM_ROLE=<role>`；orchestrator 启动命令加 `--env TEAM_ROLE=orchestrator`。

### Phase A: Orchestrator 侧三件套

**A1. 注入门禁**。拦截 bash `tool_call`，匹配 `herdr pane run <pane>` / `herdr agent send` 时先查 `herdr pane get`：目标非 `idle` → `{ block: true, reason: "目标 <status>，升船长或等待" }`。

**A2. 自动记帐**。拦截上述调用的 `tool_result`，成功即由插件解析目标 pane 的角色名、按 TEAM.md 边表分类（正向/回边）、调 `hop.sh route/incr`（全字段 + 会话引用）。orchestrator 忘调 hop.sh 不再影响审计完整性——**观察推导，不是自报**。

**A3. hop 真熔断**。插件从 `state/<session>/routes.jsonl` 读计数，≥20 时 block 一切注入类调用，reason 写明"必须升船长"，直到出现 reset 标记。船长的任何输入仍由 `hop.sh reset` 清零（插件检测到 captain 输入事件时也可自动 reset——见 OQ-2）。

### Phase B: 角色侧 handoff 校验 + outbox 精确导出

`agent_end` 时取 `event.messages` 最后一条 assistant 消息文本，做两件事：

**B1. outbox 导出（精确内容层）**。将本棒完整文本（含 handoff block）写到 `$TEAM_HOME/state/<herdr-session>/outbox/<crew>/<UTC>.md`（每棒新建不覆盖），并刷新同目录 `latest.md`。插件从 `HERDR_SOCKET_PATH` 推导 session 名（与 hop.sh 同逻辑）。同一刻向 `routes.jsonl` 追加 `{"type":"leg_complete","role":...,"ts":...,"outbox":"..."}`，与 orch 的 route 事件按时间线天然关联。orchestrator 读 `latest.md`（校验 mtime ≥ 注入时间防陈旧件）——**精确、不啃 pi 内部格式、插件硬化不靠角色自觉**。时序保障：integration 的 idle 上报在 `agent_end` 后 250ms 防抖，插件在同一事件 drain 内 `writeFileSync` 同步落盘，必然先于 orch 被唤醒。`bin/session-leg.py`（直接解析会话 jsonl）与 `bin/archive-turn.sh` 降级为无插件环境的备胎。**注入不再携带 leg 标记**（KD-6）。

**B2. handoff 形式校验**。从 `event.messages` 中按“最后一条含 text 且不含 toolCall 的 assistant 消息”取最终回复（无 toolCall 的 assistant 消息必然是该 run 的最后一条——没有工具结果喂回，loop 必然终止），提取尾部 ` ```handoff ` block：

- 最后一条 assistant 消息 `stopReason !== "stop"`（abort/error 中断）→ **不校验不导出**（B1 同样跳过）：outbox 保持陈旧，orch 的 mtime 校验会判定“无新件”并升船长——失败方向安全；
- 无 block → 放行（合法，意为“需要船长”）；
- 有 block 但畸形（缺必填字段 / `to` 越枚举 / YAML 不可解析 / 不在最末尾）→ 插件立即 `sendUserMessage` 注入打回话术（与 `contracts/handoff.md` 规定的原文一致），角色当轮补发，闭环不出 pane；
- 同一 run 连续 2 次畸形 → 不再自动打回，留给 orchestrator 升船长（防插件-角色死循环）。

**不做**：语义校验（球是否有意义）、`to` 是否在 TEAM.md 允许下游内（那是 orchestrator 的路由职责）。

## Acceptance Criteria

### Phase A（Orchestrator 侧三件套）
- [ ] AC-A1: 目标 pane 为 blocked/working 时，`herdr pane run` 被 block 且 reason 可读；idle 时放行
- [ ] AC-A2: orchestrator 不调 hop.sh 的情况下完成一次路由，routes.jsonl 出现对应 route/rework 记录且字段完整（from/to/pane/session/turn）
- [ ] AC-A3: 计数 ≥20 后注入类调用被 block；`hop.sh reset` 后恢复
- [ ] AC-A4: `TEAM_ROLE` 未设置时插件零行为（普通 pi 会话无感知）

### Phase B（角色侧校验 + 导出）
- [ ] AC-B1: 畸形 block 触发 pane 内即时打回，角色补发后 block 合格
- [ ] AC-B2: 无 block 的输出不被打扰
- [ ] AC-B3: 连续 2 次畸形后插件停止自动打回
- [ ] AC-B4: 打回话术与 `contracts/handoff.md` 规定原文一致（单一真相源）
- [ ] AC-B5: 角色完成一棒后，`outbox/<crew>/` 出现 `<UTC>.md` 与 `latest.md`，内容与 assistant 原文逐字一致；`routes.jsonl` 出现对应 `leg_complete` 事件

## Dependencies

- **Evolved from**: herdr-vessel 的 prompt 纪律层（TEAM.md / contracts/handoff.md / orchestrator/PROMPT.md——本插件是它们的执法者，规格以这些文档为准）
- **Blocked by**: 无（pi extension API 已核实可用）
- **Related**: tutu-vessel ADR-027（不可信 caller 自报、服务端盖章原则——A2 自动记帐同源思想）；F027 KD-11（语义判断只能 receive-time 推理，机制管形式——本插件的能力边界）

## Risk

| 风险 | 缓解 |
|------|------|
| 插件拦截规则与 TEAM.md 边表漂移（两处拓扑） | 边表数据化：插件读 TEAM.md 旁生成的机器可读边表（或解析 TEAM.md 表格），OQ-1 |
| 插件自身 bug 导致误拦，orchestrator 瘫痪 | block 一律带可读 reason；提供 `HERDR_VESSEL_EXT=off` 环境变量总开关，一键绕过 |
| role 侧连续打回死循环 | 同一 run 最多自动打回 2 次（AC-B3） |
| `agent_end` 后 auto-retry/compaction 干扰校验时机 | 校验只在最后一条 assistant 消息含 block 特征时触发；`agent_settled` 作为备选挂钩留 OQ-3 |

## Open Questions

| # | 问题 | 状态 |
|---|------|------|
| OQ-1 | 边表（哪些边算回边）放哪：插件内嵌 vs 机器可读文件（如 roster.conf 加列）vs 解析 TEAM.md？ | ⬜ 未定 |
| OQ-2 | 船长输入的 reset 能否也自动化（检测交互输入事件）？还是保持 orchestrator 调 hop.sh reset 的纪律？ | ⬜ 未定 |
| OQ-3 | 角色侧校验用 `agent_end` 还是 `agent_settled`？（后者排除 auto-retry 干扰但消息可达性待验证） | ⬜ 未定 |
| OQ-4 | git 红线（git push/交付命令）是否也在 Phase B 对角色 pane 做硬拦截？ | ⬜ 未定 |

## Key Decisions

| # | 决策 | 理由 | 日期 |
|---|------|------|------|
| KD-1 | 单插件 + `TEAM_ROLE` 环境变量激活，而不是两个插件 | 一份代码两种模式；全局安装但默认 no-op，不污染日常 pi 会话 | 2026-07-20 |
| KD-2 | 插件只做形式执法，不做语义判断 | F027 KD-11：意义只能推理时刻判出；机制管形状，prompt 管语义 | 2026-07-20 |
| KD-3 | 审计走"观察 tool_result 推导"，不走"要求 orchestrator 自报" | ADR-027 同源：caller 自报不可信；观察到的行为才是真相 | 2026-07-20 |
| KD-4 | hop.sh 继续作为存储/计数底座，插件复用而非重写 | 已实测正确；单一存储真相源，prompt 层与插件层写同一本账 | 2026-07-20 |
| KD-5 | Phase B 后：archive-turn.sh 退役为备胎；leg 标记随之一并退役——曾被降级为“审计关联 ID”，最终确认无必要 | 插件写的就是本棒，无需裁剪切分点；关联改由 leg_complete 事件（时间线相邻）+ mtime 校验承担，标记彻底多余（修正：本条推翻了上一版“保留标记”的结论，CVO 推动） | 2026-07-20 |

## Timeline

| 日期 | 事件 |
|------|------|
| 2026-07-20 | 立项（spec 落盘） |
| 2026-07-20 | CVO 口头放行（"按你说的来"），Phase A 代码落地并推送（commit cae0ca5），待真机验收 AC-A1~A4 |

## Review Gate

- Phase A: 对照 AC-A1~A4 逐条真机演示；重点审"误拦率"（合法注入被误 block 的场景枚举）
- Phase B: 对照 AC-B1~B4；重点审打回话术与 contracts/handoff.md 的一致性

## Links

| 类型 | 路径 | 说明 |
|------|------|------|
| **规则书** | `TEAM.md` | 花名册/边表/调度算法，插件的执法依据 |
| **契约** | `contracts/handoff.md` | handoff block schema 与打回话术原文 |
| **底座** | `bin/hop.sh` | 存储/计数/会话引用，插件复用 |
| **Orchestrator** | `orchestrator/PROMPT.md` | prompt 层纪律（插件硬化后仍保留为语义层） |
