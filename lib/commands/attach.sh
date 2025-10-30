#!/usr/bin/env bash

# wkd attach - tmuxセッションにアタッチ

attach_tmux() {
  local session_pattern="${1:-wkd-}"

  # tmuxセッション一覧を取得
  if ! check_tmux; then
    return 1
  fi

  # wkd- で始まるセッションを検索
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${session_pattern}" || true)

  if [[ -z "$sessions" ]]; then
    log_info "アクティブなセッションが見つかりません"
    log_info "タスクを実行してください: wkd run <task-file>"
    return 0
  fi

  # セッションが1つの場合は直接アタッチ
  local session_count
  session_count=$(echo "$sessions" | wc -l | tr -d ' ')

  if [[ "$session_count" -eq 1 ]]; then
    local session_name="$sessions"
    attach_session "$session_name"
    return 0
  fi

  # 複数セッションがある場合は選択
  log_section "tmuxセッション一覧"
  echo ""

  local i=1
  declare -a session_array

  while IFS= read -r session_name; do
    echo "${i}. ${session_name}"
    session_array[$i]="$session_name"
    ((i++))
  done <<< "$sessions"

  echo ""
  read -rp "アタッチするセッション番号を選択 (1-${session_count}): " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$session_count" ]]; then
    attach_session "${session_array[$choice]}"
  else
    log_error "無効な選択です"
    return 1
  fi

  return 0
}
