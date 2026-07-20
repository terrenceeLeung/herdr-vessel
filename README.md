# herdr-vessel

脱离 vessel 的轻量多 agent 团队：三个角色（大副 / 轮机长 / 独立审查）各居一个 [Herdr](https://herdr.dev) pane，一个 **Orchestrator**（pi 会话）自动路由，船长（你）从"复制粘贴传球的人"退为"盯着侧边栏的监督者"。

角色规则来自 `pi-feishu-channel-F001/.pi/role-packs`，已按自动化需要改造（见文末[改动清单](#与-f001-的差异)）。**本目录即团队规则的家（TEAM_HOME），独立于任何工作 repo**——跨项目复用，不污染代码仓。

## 架构

```
            船长（你）
              │ 派 Feature / 处理升级 / 独握 git
              ▼
      ┌────────────────┐
      │  Orchestrator  │  pi + herdr skill
      │  （调度 session）│  读 TEAM.md + contracts/handoff.md
      └───────┬────────┘
              │  herdr pane run / wait / read（注入任务、等完成、解析 handoff）
   ┌──────────┼──────────┐
   ▼          ▼          ▼
first-mate  chief-     reviewer        各是一个 herdr pane 里的 pi 会话
（大副）    engineer   （独立审查）      产物落文件，handoff block 传球
           （轮机长）
```

- **Orchestrator 是唯一知道路由的脑**：它解析每个角色输出末尾的 ` ```handoff ` 块，按 `TEAM.md` 的路由表注入下一棒。角色之间**从不直接通信**，天然无回声。
- **结构化保障**：单 session 调度 = 机器解析输出，所以 handoff 是硬契约（格式、末尾位置、校验、打回、升人），见 `contracts/handoff.md`。
- **你随时可看任何 pane**、可插手；`blocked`（权限弹窗）、争议、hop 超限、git/交付动作，一律升级给你。

## 目录结构

```
herdr-vessel/
├── README.md                  ← 本文件
├── TEAM.md                    ← 花名册 + 路由表 + 调度算法 + 安全红线（orchestrator 的规则书）
├── orchestrator/
│   ├── PROMPT.md              ← orchestrator 的角色 prompt（--append-system-prompt 注入）
│   └── skills/herdr/          ← vendor 的 herdr skill（仅 orchestrator 用 --skill 挂载）
├── roster.conf                ← 花名册：角色 → 启动模型（team-up.sh 读取）
├── contracts/
│   └── handoff.md             ← 结构化 handoff 契约（路由正确性的唯一保障）
├── role-packs/                ← 角色定义（从 F001 复制改造）
│   ├── first-mate/      SYSTEM.md + skills/（to-product-spec, grill-product-goal）
│   ├── chief-engineer/  SYSTEM.md + skills/（to-engineering-spec, to-tickets, tdd, grill-software-design）
│   ├── reviewer/        SYSTEM.md + skills/（code-review）
│   └── shared/                格式约定（ticket/adr/feature-spec/context/architecture-taste/software-sop）
├── bin/
│   ├── team-up.sh             ← 一键拉起三个角色 pane（读 roster.conf）
│   └── hop.sh                 ← hop 计数 + 路由审计（state/<herdr-session>/routes.jsonl + turns/ 存档）
└── herdr/
    └── config.toml.example    ← herdr 可选配置
```

## 一次性配置

### 1. Herdr 本体

已装可跳过。未装：`curl -fsSL https://herdr.dev/install.sh | sh`。

### 2. Agent integrations（状态检测的权威来源）

**三个角色都用 pi 是有意的**：pi 的 integration 是 lifecycle authority（钩子事件直接裁定 `idle/working/blocked`），orchestrator 的状态门才可靠。claude/codex 的 integration 只管 session 恢复，状态仍靠屏幕检测。

```bash
herdr integration install pi
herdr integration status   # 确认 pi: current
```

### 3. herdr skill：已 vendor 进项目，只挂给 orchestrator

**不要用** `npx skills add ogulcancelik/herdr -g`：`-g` 装进 `~/.pi/agent/skills/`，那是**本机所有 pi 会话共享**的目录——三个角色 pane 也是 pi，照样会看到 skill，"角色是哑终端"就破了。`skills add` 不加 `-g` 也不合适：它会把整个 herdr 仓库（Rust 源码 + vendor）拖进项目，而 skill 本体只有一个 `SKILL.md`。

所以本项目把 skill 单文件 vendor 在 `orchestrator/skills/herdr/SKILL.md`，启动 orchestrator 时用 pi 的 `--skill` 显式挂载；角色 pane 的启动命令（`team-up.sh`）里没有它——**物理隔离，不是纪律隔离**。

升级 skill 时重新下载即可：

```bash
curl -fsSL https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md \
  -o ~/projects/herdr-vessel/orchestrator/skills/herdr/SKILL.md
```

### 4. Herdr 配置（可选）

Herdr 零配置即可用。如需调整，参考 `herdr/config.toml.example`（更新通道、cwd 继承、session 恢复），复制到 `~/.config/herdr/config.toml` 后 `herdr server reload-config`。

## 启动团队

在 herdr 会话里（`herdr` 进入），**cd 到要干活的 repo**，然后：

```bash
# 1. 拉起三个角色 pane（幂等，已存在会跳过）
~/projects/herdr-vessel/bin/team-up.sh "$PWD"
```

### 启动调度器

在任意一个 shell pane（建议就是当前 pane）：

```bash
export TEAM_HOME=~/projects/herdr-vessel
pi --append-system-prompt "$(cat $TEAM_HOME/orchestrator/PROMPT.md)" \
   --skill "$TEAM_HOME/orchestrator/skills/herdr"
```

Orchestrator 启动后会读 TEAM.md + handoff 契约、核对花名册、向你报告待命。

### 派第一个 Feature

对 orchestrator 说（人话即可）：

> 团队已就位。Feature：为 XXX 实现 YYY。先让 first-mate 出 Product Contract，之后按 TEAM.md 路由，hop 到 20 或有争议就停下来找我。

之后每个 transition 它会向你汇报一行：`大副 → 轮机长：Product Contract v1（docs/product-contract.md），返工 0/20`。

> 首次在新 repo 启动 pi 的角色 pane 可能弹项目信任确认——切到那个 pane 按一次即可。想让脚本免确认，可在 `team-up.sh` 的 pi 参数里加 `-a`（权衡见 `pi --help`）。

## 日常：船长的职责

| 你做 | 你不做 |
|---|---|
| 派 Feature、定优先级 | 复制粘贴传球（orchestrator 干了） |
| 盯侧边栏状态、随时点开任何 pane 看现场 | 记路由规则（TEAM.md 干了） |
| 处理升级：blocked、争议、hop 超限、无 block | 替角色干活 |
| **git 写操作、push、外部交付（红线，不自动化）** | |

你的任何输入（派活、裁决、直接干预）都是人工保险丝——orchestrator 会用 `hop.sh reset` 清零。hop 只数**返工边**（reviewer 打回、工程/审查回退产品），健康推进不消耗预算；返工 ≥20 它就停下来找你。

角色 pane 是持久会话：回家/关终端后 `herdr` 重连，团队还在；herdr server 重启后 integration 会恢复 pi 会话（`resume_agents_on_restore`）。

## 调整指南（你说要改 F001 的 skills——就在这里改）

| 想改什么 | 改哪里 | 生效方式 |
|---|---|---|
| 某角色的行为/边界 | `role-packs/<role>/SYSTEM.md` | 重启该角色 pane |
| 某角色的技能 | `role-packs/<role>/skills/<skill>/SKILL.md` | 角色下次 read 即生效（skill 按需加载，不用重启） |
| 路由关系/角色增减 | `TEAM.md` 花名册 + `roster.conf` 增删行 | orchestrator 下个 session / 重跑 team-up.sh |
| 角色用哪个模型 | `roster.conf`（启动默认）；运行中 pane 里 `/model` 临时切 | 重启该角色 pane 生效 |
| handoff 结构 | `contracts/handoff.md` + 三个 SYSTEM.md 里的内联 block（**两处要同步改**） | 重启各 pane |
| 调度行为（超时、hop 预算、汇报格式） | `TEAM.md` 或 `orchestrator/PROMPT.md` | 重启 orchestrator |

已知重复点：handoff block 的简式同时存在于三个 SYSTEM.md（内联）和 `contracts/handoff.md`（完整版）。内联是为了角色输出时不依赖再读一次文件；改结构时四处同步。

## 与 F001 的差异（改动清单）

1. **Handoff 结构化**：`## Handoff` 自然语言段落 → ` ```handoff ` YAML 块（机器可解析；新增 `artifacts` 字段；`trade_off` 保留为可选）。这是"一个 session 调度"的硬性前提。
2. **新增接球检查（receive-side）**：球不可行动（错角色/缺产物/涉产品意图）→ 不许即兴，handoff 打回。原设计里这道检查由你人工承担，自动化后必须显式化。
3. **路由者换人**：`The Captain routes work manually` → orchestrator 机械路由 + 船长监督否决。`software-sop.md` 同步更新。
4. **规则出仓**：`.pi/role-packs` → 本目录（跨 repo 复用；角色加载改走 `pi --append-system-prompt` + `--skill`，不写工作 repo）。
5. **角色 skills 原封未动**——那是留给你调的部分。

## 故障排查

| 症状 | 怎么办 |
|---|---|
| orchestrator 说某角色状态不对 | `herdr agent list`；`herdr agent explain <role> --json` 看检测依据 |
| 角色没被识别成 agent | 确认 `herdr integration status` 中 pi 为 current；角色必须是 herdr pane 里起的 pi |
| 某 pane 卡住 | 切过去看——多半是权限弹窗（blocked）或信任确认，处理完 orchestrator 下轮继续 |
| 启动报错/socket 异常 | 日志：`~/.config/herdr/herdr-server.log`；`herdr status` |
| 想先演练 | 拿一个小 repo + 小任务跑一轮；或用 `herdr --session vessel-test` 开隔离 session |

## 已知边界（设计使然）

- Orchestrator 上下文随棒数累积——产物落文件、只搬摘要就是为了延缓；真到极限，重开 orchestrator pane 即可（规则全在文件里，无记忆负担）。
- 打回重发、hop 预算是**纪律级**保障（prompt 约束），不是服务端强制。agent 严重不守约时，最后防线是你——这正是侧边栏全程可视的意义。
