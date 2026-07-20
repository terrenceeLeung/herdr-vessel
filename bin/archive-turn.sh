#!/usr/bin/env bash
# archive-turn.sh <pane> <role> <leg-marker> [lines]
#
# 抓取一棒的完整输出，按 leg 标记裁剪，落盘 turns/，打印文件路径。
# 两层保真（自动选择）：
#   1. 精确层：从 pi 会话文件提取（session-leg.py）——结构化消息原文，无渲染失真
#   2. 降级层：终端 scrollback（非 pi 角色 / 会话文件不可用时）
# leg 标记 = 注入任务首行的 <!-- leg:<UTC时间戳> -->，orchestrator 生成。
# 找不到标记则保留全量并标注，不丢数据。
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

# ── 优先精确层：pi 会话文件（ground truth，无渲染失真）──
sess_path="$(herdr pane get "$pane" 2>/dev/null | grep -o '"agent_session":{[^}]*}' | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')"
if [ -n "$sess_path" ] && [ -f "$sess_path" ] && command -v python3 >/dev/null 2>&1; then
  if python3 "$TEAM_HOME/bin/session-leg.py" "$sess_path" "$marker" "$out" >/dev/null 2>&1; then
    printf '%s\n' "$out"
    exit 0
  fi
fi

# ── 降级屏幕层：终端 scrollback（非 pi 角色 / 会话文件不可用时）──
herdr pane read "$pane" --source recent-unwrapped --lines "$lines" > "$out.full"

if grep -n "$marker" "$out.full" >/dev/null 2>&1; then
  start=$(grep -n "$marker" "$out.full" | tail -1 | cut -d: -f1)
  sed -n "${start},\$p" "$out.full" > "$out"
  rm "$out.full"
else
  mv "$out.full" "$out"
fi

printf '%s\n' "$out"
