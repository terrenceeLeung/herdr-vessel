#!/usr/bin/env bash
# hop.sh — herdr-vessel 路由审计与返工计数（v3）
#
# 存储: $TEAM_HOME/state/<herdr-session>/routes.jsonl   （按 herdr session 分目录）
#        $TEAM_HOME/state/<herdr-session>/turns/         （每棒完整输出存档，由 orchestrator 写入）
#
# 计数语义: hop = 自上次 reset 以来的回边（rework）数，预算与边表见 TEAM.md。
# 脚本不管拓扑：正向用 route（只审计），回边用 incr（审计+计数）。
#
# 用法:
#   hop.sh route|incr --from R --to R [--what ".."] [--why ".."] [--artifacts ".."]
#                     [--open-questions ".."] [--next-action ".."] [--trade-off ".."]
#                     [--turn <存档文件路径>]
#   hop.sh reset [原因]     # 船长输入后清零；同时追加一条 roster 元数据快照
#   hop.sh count            # 打印当前计数
set -euo pipefail

TEAM_HOME="${TEAM_HOME:-$HOME/projects/herdr-vessel}"

# 从 HERDR_SOCKET_PATH 推断 herdr session 名：
#   .../herdr.sock                 -> default
#   .../sessions/<name>/herdr.sock -> <name>
session_name() {
  local sock="${HERDR_SOCKET_PATH:-}"
  [ -z "$sock" ] && { echo default; return; }
  local d1 d2
  d1="$(basename "$(dirname "$sock")")"
  d2="$(basename "$(dirname "$(dirname "$sock")")")"
  if [ "$d2" = "sessions" ]; then echo "$d1"; else echo default; fi
}

SESSION="$(session_name)"
STATE_DIR="$TEAM_HOME/state/$SESSION"
LOG="$STATE_DIR/routes.jsonl"
mkdir -p "$STATE_DIR/turns"
touch "$LOG"

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '; }

# 尽力解析角色的 pane_id 与 pi session 文件路径（不在 herdr 内或查询失败则返回空）
pane_of() {
  command -v herdr >/dev/null 2>&1 || return 0
  herdr agent get "$1" 2>/dev/null | sed -n 's/.*"pane_id":"\([^"]*\)".*/\1/p' | head -1
}
session_of() {
  command -v herdr >/dev/null 2>&1 || return 0
  herdr agent get "$1" 2>/dev/null \
    | grep -o '"agent_session":{[^}]*}' | sed -n 's/.*"value":"\([^"]*\)".*/\1/p' | head -1
}

count_since_reset() {
  awk '
    /"type":"reset"/  { c=0; next }
    /"type":"rework"/ { c++ }
    END { print c+0 }
  ' "$LOG"
}

cmd="${1:-}"
case "$cmd" in
  route|incr)
    shift
    from="" to="" what="" why="" artifacts="" oq="" next="" tradeoff="" turn=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --from)           from="$2";      shift 2;;
        --to)             to="$2";        shift 2;;
        --what)           what="$2";      shift 2;;
        --why)            why="$2";       shift 2;;
        --artifacts)      artifacts="$2"; shift 2;;
        --open-questions) oq="$2";        shift 2;;
        --next-action)    next="$2";      shift 2;;
        --trade-off)      tradeoff="$2";  shift 2;;
        --turn)           turn="$2";      shift 2;;
        *) echo "未知参数: $1" >&2; exit 2;;
      esac
    done
    [ -n "$from" ] && [ -n "$to" ] || { echo "route/incr 需要 --from 和 --to" >&2; exit 2; }
    [ "$cmd" = incr ] && type="rework" || type="route"
    printf '{"type":"%s","ts":"%s","session":"%s","from":"%s","from_pane":"%s","from_session":"%s","to":"%s","to_pane":"%s","to_session":"%s","what":"%s","why":"%s","artifacts":"%s","open_questions":"%s","next_action":"%s","trade_off":"%s","turn":"%s"}\n' \
      "$type" "$(date -u +%FT%TZ)" "$SESSION" \
      "$(esc "$from")" "$(pane_of "$from")" "$(session_of "$from")" \
      "$(esc "$to")" "$(pane_of "$to")" "$(session_of "$to")" \
      "$(esc "$what")" "$(esc "$why")" "$(esc "$artifacts")" "$(esc "$oq")" \
      "$(esc "$next")" "$(esc "$tradeoff")" "$(esc "$turn")" >> "$LOG"
    count_since_reset
    ;;
  reset)
    printf '{"type":"reset","ts":"%s","session":"%s","reason":"%s"}\n' \
      "$(date -u +%FT%TZ)" "$SESSION" "$(esc "${2:-captain decision}")" >> "$LOG"
    # 追加 roster 元数据快照（agent list 原始 JSON，含 pane/terminal/agent_session 等）
    if command -v herdr >/dev/null 2>&1; then
      roster="$(herdr agent list 2>/dev/null | tr -d '\n')"
      [ -n "$roster" ] && printf '{"type":"meta","ts":"%s","session":"%s","roster_raw":%s}\n' \
        "$(date -u +%FT%TZ)" "$SESSION" "$roster" >> "$LOG"
    fi
    echo 0
    ;;
  count)
    count_since_reset
    ;;
  *)
    sed -n '2,16p' "$0" >&2
    exit 2
    ;;
esac
