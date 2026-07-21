#!/usr/bin/env bash
# orchestrator.sh — 在当前 pane 启动 herdr-vessel 调度器
#
# 自带 TEAM_HOME / TEAM_ROLE 环境，注入调度 prompt 与 herdr skill。
# 用法: 在 herdr 的任意 pane 里运行（cwd = 团队要干活的 repo）
set -euo pipefail

TEAM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${HERDR_ENV:-}" != "1" ]; then
  echo "警告: 当前不在 herdr pane 内（HERDR_ENV 未设置），调度器将无法驱动团队" >&2
fi

export TEAM_HOME
export TEAM_ROLE=orchestrator

exec pi \
  --append-system-prompt "$(cat "$TEAM_HOME/orchestrator/PROMPT.md")" \
  --skill "$TEAM_HOME/orchestrator/skills/herdr"
