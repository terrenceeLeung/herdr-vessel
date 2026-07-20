#!/usr/bin/env bash
# role.sh <role> — 在当前 pane 内启动指定角色会话
#
# 从 roster.conf 读该角色的模型，注入 TEAM_HOME / TEAM_ROLE，然后 exec pi。
# 供 team-up.sh 之外的场景使用（比如手动布局后在指定 pane 里拉起角色）。
set -euo pipefail

TEAM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
role="${1:?用法: role.sh <first-mate|chief-engineer|reviewer>}"

SYSTEM_MD="$TEAM_HOME/role-packs/$role/SYSTEM.md"
[ -f "$SYSTEM_MD" ] || { echo "错误: role-packs/$role 不存在" >&2; exit 1; }

model="$(awk -v r="$role" '$1==r && $1 !~ /^#/ {print $2}' "$TEAM_HOME/roster.conf")"

args=(
  --append-system-prompt "$(cat "$SYSTEM_MD")"
  --skill "$TEAM_HOME/role-packs/$role/skills"
)
[ -n "${model:-}" ] && [ "$model" != "-" ] && args+=(--model "$model")

export TEAM_HOME
export TEAM_ROLE="$role"
exec pi "${args[@]}"
