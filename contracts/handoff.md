# Handoff 契约（结构化路由保障）

> 本文件是 herdr-vessel 的**硬契约**，不是风格建议。
> Orchestrator 是程序化解析：它读角色输出的末尾、提取 handoff block、据此路由。
> **结构 = 路由正确性的唯一保障。**

## 为什么需要它

团队只有一个调度 session（orchestrator），它不靠"理解"角色的整段输出，而靠**机器可解析的结构**做路由。角色的自然语言写得再好，没有固定结构，路由就只能靠猜。因此：

- 角色到边界要传球时，**必须**输出规定格式的 handoff block；
- block 无效 = 打回重发；两次无效 = 升船长；
- 没有 block = orchestrator 不许猜，升船长定夺。

## 格式

角色输出的**最后一个**内容必须恰好是一个 fenced code block：

~~~markdown
```handoff
to: first-mate                    # 必填。枚举：first-mate | chief-engineer | reviewer | captain
what: Product Contract v1 完成     # 必填。一句话：递出的球是什么
artifacts:                        # 必填（可为 []）。接球方需要的仓内文件，repo 相对路径
  - docs/product-contract.md
why: 契约已足以支撑工程设计         # 必填。一句话
trade_off: 本轮不覆盖移动端边界     # 可选。一句话
open_questions: []                # 必填（可为 []）
next_action: 通读契约，起草 Engineering Design   # 必填。一句话：接球方第一步做什么
```
~~~

规则：

1. 全文**只允许一个** handoff block，且必须在输出的**最末尾**（orchestrator 只读尾部 ~80 行）。
2. `to` 不在枚举内、缺必填字段、YAML 无法解析 = **无效**。
3. 不到真正的角色边界**不许发**——不制造 handoff。没有 handoff 就不带 block 结束输出。
4. 球必须可行动：`next_action` 要让接球方第一步就知道干什么；只喊"请看看"不是球。

## 接球检查（receive-side）

角色收到任务后、动手前先验球。以下情况**不许即兴发挥**，直接以 handoff block 打回（`to` 填正确角色或 `captain`，`why` 写明问题）：

- 任务不属于本角色职责（如让 reviewer 写实现）；
- `artifacts` 指向的文件缺失或明显不对；
- 涉及产品意图变更（只能 first-mate / captain 裁决）。

## Orchestrator 校验与打回流程

1. 把该棒完整输出转存到 `$TEAM_HOME/state/<session>/turns/`（重定向进文件，不进 orchestrator 上下文）；
2. 从存档文件中提取最后一个 ` ```handoff ` block，按上面规则校验，并核对 `to` 在 TEAM.md 路由表的允许下游内；
3. 无效 → 向**原 pane** 注入打回话术（原样注入，不要改写）：

   > Your handoff block was invalid: \<原因\>. Re-emit ONLY the corrected \`\`\`handoff block as the last thing in your output. Do not redo the work.

4. 等它重发（`wait agent-status ... done`），重新校验。同一棒累计两次无效 → 升船长。

## `to: captain` 的语义

升级。适用：需要产品裁决、需要 git/外部交付动作、角色间争议无法自决、hop 预算将尽。
Orchestrator 见到 `to: captain` **停止自动路由**，向船长汇报：发生了什么、现场摘要、建议动作。

## 无 block 的语义

角色结束输出但没有 block = 它认为工作未完、或它在等人。Orchestrator 不许猜测路由，升船长并附尾部摘要。
