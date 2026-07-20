#!/usr/bin/env bash
# archive-turn.sh <pane> <role> <leg-marker> [lines]
#
# 抓取 pane 最近 scrollback，按 leg 标记裁剪出【本棒】内容，落盘 turns/，打印文件路径。
# leg 标记 = 注入任务时写在任务首行的 <!-- leg:<UTC时间戳> -->，由 orchestrator 生成。
# 找不到标记（如 TUI 未回显）则保留全量，不丢数据。
set -euo pipefail

TEAM_HOME="${TEAM_HOME:-$HOME/projects/herdr-vessel}"
pane="${1:?用法: archive-turn.sh <pane> <role> <leg-marker> [lines]}"
role="${2:?}"
marker="${3:?}"
lines="${4:-400}"

# session 推导与 hop.sh 一致
sock="${HERDR_SOCKET_PATH:-}"
d1="$(basename "$(dirname "$sock")" 2>/dev/null || echo x)"
d2="$(basename "$(dirname "$(dirname "$sock")")" 2>/dev/null || echo x)"
if [ "$d2" = "sessions" ]; then sess="$d1"; else sess="default"; fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
dir="$TEAM_HOME/state/$sess/turns"
mkdir -p "$dir"
out="$dir/$ts-$role.md"

herdr pane read "$pane" --source recent-unwrapped --lines "$lines" > "$out.full"

if grep -n "$marker" "$out.full" >/dev/null 2>&1; then
  start=$(grep -n "$marker" "$out.full" | tail -1 | cut -d: -f1)
  sed -n "${start},\$p" "$out.full" > "$out"
  rm "$out.full"
else
  mv "$out.full" "$out"
fi

printf '%s\n' "$out"
