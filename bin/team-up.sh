#!/usr/bin/env bash
# team-up.sh — 在当前 herdr 会话内拉起 herdr-vessel 的三个角色 pane
#
# 用法:
#   team-up.sh [工作目录]     # 默认 = 当前目录；团队将在该目录的代码上工作
#
# 前提:
#   - 在 herdr 会话内运行（HERDR_ENV=1）
#   - pi 在 PATH 上
#   - 已安装 pi integration（herdr integration install pi），否则状态检测不准
#
# 每个角色 pane 的启动方式:
#   pi --append-system-prompt <role SYSTEM.md> --skill <role skills 目录>
# 并通过 --env TEAM_HOME=... 注入团队目录，供角色定位 contracts/ 与 shared/。
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

while read -r role model _rest; do
  # 跳过注释与空行
  [[ -z "${role:-}" || "$role" == \#* ]] && continue
  model="${model:--}"

  if [ ! -f "$TEAM_HOME/role-packs/$role/SYSTEM.md" ]; then
    echo "警告: role-packs/$role 不存在，跳过" >&2
    continue
  fi
  if herdr agent get "$role" >/dev/null 2>&1; then
    echo "· $role 已在场，跳过"
    continue
  fi

  echo "+ 启动 ${role}（cwd=$CWD, model=${model}）"
  pi_args=(
    --append-system-prompt "$(cat "$TEAM_HOME/role-packs/$role/SYSTEM.md")"
    --skill "$TEAM_HOME/role-packs/$role/skills"
  )
  [ "$model" != "-" ] && pi_args+=(--model "$model")

  herdr agent start "$role" \
    --cwd "$CWD" \
    --split right --no-focus \
    --env "TEAM_HOME=$TEAM_HOME" \
    --env "TEAM_ROLE=$role" \
    -- pi "${pi_args[@]}" \
    >/dev/null
done < "$ROSTER"

cat <<EOF

团队已就位。检查状态:
  herdr agent list

接下来在 orchestrator pane 启动调度器（详见 README.md「启动调度器」）:
  cd $CWD
  export TEAM_HOME=$TEAM_HOME TEAM_ROLE=orchestrator
  pi --append-system-prompt "\$(cat \$TEAM_HOME/orchestrator/PROMPT.md)" \\
     --skill "\$TEAM_HOME/orchestrator/skills/herdr"

提示: 角色 pane 首次在新 repo 启动 pi 可能弹项目信任确认，切过去按一次即可。
EOF
