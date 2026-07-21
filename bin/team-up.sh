#!/usr/bin/env bash
# team-up.sh — 在当前 herdr 会话内拉起 herdr-vessel 团队（2×2 象限布局）
#
# 用法:
#   team-up.sh [工作目录]     # 默认 = 当前目录；团队在该目录的代码上工作
#
# 布局（在你运行本脚本的那个 pane 所在 tab 上搭建）：
#   ┌──────────────┬──────────────┐
#   │ 当前 pane     │ first-mate   │
#   │(orchestrator) │              │
#   ├──────────────┼──────────────┤
#   │chief-engineer│  reviewer    │
#   └──────────────┴──────────────┘
#   左上 = 调用者 pane（留给 orchestrator），其余三个象限按 roster.conf 顺序填角色。
#
# 前提:
#   - 在 herdr 会话内运行（HERDR_ENV=1）
#   - pi 在 PATH 上
#   - 已安装 pi integration（herdr integration install pi）
set -euo pipefail

TEAM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CWD="$(cd "${1:-.}" && pwd)"

if [ "${HERDR_ENV:-}" != "1" ]; then
  echo "错误: 请在 herdr 会话内运行（HERDR_ENV 未设置）" >&2
  exit 1
fi
command -v herdr >/dev/null 2>&1 || { echo "错误: herdr 不在 PATH" >&2; exit 1; }
command -v pi    >/dev/null 2>&1 || { echo "错误: pi 不在 PATH" >&2; exit 1; }

ROSTER="$TEAM_HOME/roster.conf"
[ -f "$ROSTER" ] || { echo "错误: 找不到花名册 $ROSTER" >&2; exit 1; }

SELF_PANE="${HERDR_PANE_ID:?错误: 缺少 HERDR_PANE_ID（必须在 herdr pane 内运行）}"

# 从 split 返回的 JSON 里提取新 pane_id
new_pane_id() { grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4; }

role_exists() { herdr agent get "$1" >/dev/null 2>&1; }

# 读花名册（保持文件顺序）
ROLES=()
while read -r role _model _rest; do
  [[ -z "${role:-}" || "$role" == \#* ]] && continue
  [ -f "$TEAM_HOME/role-packs/$role/SYSTEM.md" ] || { echo "警告: role-packs/$role 不存在，跳过" >&2; continue; }
  ROLES+=("$role")
done < "$ROSTER"

# 统计缺员
MISSING=()
for role in "${ROLES[@]}"; do
  if role_exists "$role"; then
    echo "· $role 已在场，跳过"
  else
    MISSING+=("$role")
  fi
done

if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "团队已齐整。"
elif [ "${#MISSING[@]}" -eq "${#ROLES[@]}" ] && [ "${#ROLES[@]}" -eq 3 ]; then
  # ── 首次启动（三角色全缺）：搭 2×2 象限 ──
  echo "+ 搭建 2×2 布局（当前 pane = 左上/orchestrator 位）"
  Q2=$(herdr pane split "$SELF_PANE" --direction right --no-focus | new_pane_id)
  Q3=$(herdr pane split "$SELF_PANE" --direction down  --no-focus | new_pane_id)
  Q4=$(herdr pane split "$Q2"        --direction down  --no-focus | new_pane_id)
  QUADS=("$Q2" "$Q3" "$Q4")

  for i in 0 1 2; do
    role="${ROLES[$i]}"
    pane="${QUADS[$i]}"
    echo "+ 启动 $role → $pane"
    herdr pane run "$pane" "cd $(printf '%q' "$CWD") && $(printf '%q' "$TEAM_HOME")/bin/role.sh $(printf '%q' "$role")" >/dev/null
  done

  echo "· 等角色会话就绪（15s）…"
  sleep 15
  for i in 0 1 2; do
    herdr agent rename "${QUADS[$i]}" "${ROLES[$i]}" >/dev/null 2>&1 \
      && echo "✓ ${ROLES[$i]} 已登记名册（${QUADS[$i]}）" \
      || echo "⚠ ${ROLES[$i]} 登记失败，稍后可手动: herdr agent rename ${QUADS[$i]} ${ROLES[$i]}"
  done
else
  # ── 补员模式：缺谁补谁（简单右分屏，布局自行调整） ──
  for role in "${MISSING[@]}"; do
    echo "+ 补员 $role（右分屏；如需象限布局，建议全关后重跑本脚本）"
    NEW=$(herdr pane split "$SELF_PANE" --direction right --no-focus | new_pane_id)
    herdr pane run "$NEW" "cd $(printf '%q' "$CWD") && $(printf '%q' "$TEAM_HOME")/bin/role.sh $(printf '%q' "$role")" >/dev/null
    sleep 12
    herdr agent rename "$NEW" "$role" >/dev/null 2>&1 || true
  done
fi

cat <<EOF

检查状态:
  herdr agent list

接下来在左上 pane 启动调度器（详见 README.md「启动调度器」）:
  cd $CWD
  $TEAM_HOME/bin/orchestrator.sh

提示: 角色 pane 首次在新 repo 启动 pi 可能弹项目信任确认，切过去按一次即可。
EOF
