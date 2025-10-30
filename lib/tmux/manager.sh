#!/usr/bin/env bash

# tmux セッション管理

# tmuxがインストールされているかチェック
check_tmux() {
  if ! command -v tmux &>/dev/null; then
    log_error "tmux がインストールされていません"
    log_info "インストール方法: brew install tmux (macOS) / apt install tmux (Ubuntu)"
    return 1
  fi
  return 0
}

# セッション名を生成
generate_session_name() {
  local epic_id="$1"
  local task_id="${2:-}"

  if [[ -n "$task_id" ]]; then
    echo "wkd-${epic_id}-${task_id}"
  else
    echo "wkd-${epic_id}"
  fi
}

# tmuxセッションを作成
create_tmux_session() {
  local session_name="$1"
  local initial_dir="${2:-.}"

  if ! check_tmux; then
    return 1
  fi

  # 既存セッションをチェック
  if tmux has-session -t "$session_name" 2>/dev/null; then
    log_warn "tmuxセッションが既に存在します: ${session_name}"
    return 0
  fi

  log_step "tmuxセッションを作成中: ${session_name}"

  # detachedモードでセッション作成
  if tmux new-session -d -s "$session_name" -c "$initial_dir"; then
    log_success "tmuxセッションを作成しました: ${session_name}"
    return 0
  else
    log_error "tmuxセッションの作成に失敗しました: ${session_name}"
    return 1
  fi
}

# ワーカー用のペインを作成
create_worker_pane() {
  local session_name="$1"
  local worker_id="$2"
  local worker_dir="$3"
  local pane_index="${4:-}"

  if ! check_tmux; then
    return 1
  fi

  log_debug "ペインを作成中: ${worker_id} in ${session_name}"

  # 最初のペイン以外は分割して作成
  if [[ -n "$pane_index" ]] && [[ "$pane_index" -gt 0 ]]; then
    # 横分割でペインを作成
    if ! tmux split-window -t "${session_name}" -h -c "$worker_dir"; then
      log_error "ペインの作成に失敗しました: ${worker_id}"
      return 1
    fi
  else
    # 最初のペインはディレクトリを変更するだけ
    tmux send-keys -t "${session_name}:0.0" "cd ${worker_dir}" C-m
  fi

  return 0
}

# レイアウトを設定
set_tmux_layout() {
  local session_name="$1"
  local layout="${2:-tiled}"

  if ! check_tmux; then
    return 1
  fi

  case "$layout" in
    tiled|even-horizontal|even-vertical|main-horizontal|main-vertical)
      log_debug "レイアウトを設定中: ${layout}"
      tmux select-layout -t "$session_name" "$layout" 2>/dev/null || true
      ;;
    *)
      log_warn "未知のレイアウト: ${layout}. デフォルト(tiled)を使用します"
      tmux select-layout -t "$session_name" tiled 2>/dev/null || true
      ;;
  esac

  return 0
}

# ペインにコマンドを送信
send_to_pane() {
  local session_name="$1"
  local pane_index="$2"
  local command="$3"

  if ! check_tmux; then
    return 1
  fi

  log_debug "コマンドを送信中: pane ${pane_index} in ${session_name}"

  # コマンドを送信してEnterキーを押す
  tmux send-keys -t "${session_name}:0.${pane_index}" "$command" C-m

  return 0
}

# セッションにアタッチ
attach_session() {
  local session_name="$1"

  if ! check_tmux; then
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    log_error "セッションが存在しません: ${session_name}"
    return 1
  fi

  log_info "セッションにアタッチします: ${session_name}"
  log_info "デタッチするには: Ctrl-b d"

  # 既にtmux内にいるかチェック
  if [[ -n "${TMUX:-}" ]]; then
    # tmux内からは switch-client を使用
    tmux switch-client -t "$session_name"
  else
    # tmux外からは attach-session を使用
    tmux attach-session -t "$session_name"
  fi

  return 0
}

# すべてのセッションを一覧表示
list_sessions() {
  if ! check_tmux; then
    return 1
  fi

  log_section "tmux セッション一覧"

  if ! tmux list-sessions 2>/dev/null; then
    log_info "アクティブなセッションはありません"
    return 0
  fi

  return 0
}

# 特定のセッションの詳細を表示
show_session_details() {
  local session_name="$1"

  if ! check_tmux; then
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    log_error "セッションが存在しません: ${session_name}"
    return 1
  fi

  log_section "セッション詳細: ${session_name}"

  # セッション情報
  echo "【セッション情報】"
  tmux list-sessions -F "#{session_name}: #{session_windows} windows (created #{session_created_string})" 2>/dev/null | grep "^${session_name}:"

  # ペイン情報
  echo ""
  echo "【ペイン情報】"
  tmux list-panes -t "$session_name" -F "Pane #{pane_index}: #{pane_current_path} (#{pane_width}x#{pane_height})" 2>/dev/null

  return 0
}

# セッションを削除
kill_session() {
  local session_name="$1"
  local force="${2:-false}"

  if ! check_tmux; then
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    log_debug "セッションが存在しません: ${session_name}"
    return 0
  fi

  if [[ "$force" != "true" ]]; then
    if ! confirm "セッション '${session_name}' を削除しますか？" "n"; then
      log_info "キャンセルしました"
      return 0
    fi
  fi

  log_step "セッションを削除中: ${session_name}"

  if tmux kill-session -t "$session_name" 2>/dev/null; then
    log_success "セッションを削除しました: ${session_name}"
    return 0
  else
    log_error "セッションの削除に失敗しました: ${session_name}"
    return 1
  fi
}

# すべてのwkdセッションを削除
cleanup_all_sessions() {
  if ! check_tmux; then
    return 1
  fi

  log_section "全tmuxセッションのクリーンアップ"

  # wkd- で始まるセッションを取得
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^wkd-" || true)

  if [[ -z "$sessions" ]]; then
    log_info "クリーンアップ対象のセッションはありません"
    return 0
  fi

  local count=0
  while IFS= read -r session_name; do
    if [[ -n "$session_name" ]]; then
      log_step "セッションを削除中: ${session_name}"
      tmux kill-session -t "$session_name" 2>/dev/null || true
      ((count++))
    fi
  done <<< "$sessions"

  log_success "${count} 個のセッションをクリーンアップしました"

  return 0
}

# ペインの出力をキャプチャ
capture_pane_output() {
  local session_name="$1"
  local pane_index="$2"
  local lines="${3:-100}"

  if ! check_tmux; then
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    log_error "セッションが存在しません: ${session_name}"
    return 1
  fi

  # ペインの内容をキャプチャ
  tmux capture-pane -t "${session_name}:0.${pane_index}" -p -S "-${lines}" 2>/dev/null || {
    log_error "ペインの出力キャプチャに失敗しました"
    return 1
  }

  return 0
}

# ペインのプロセスが実行中かチェック
is_pane_running() {
  local session_name="$1"
  local pane_index="$2"

  if ! check_tmux; then
    return 1
  fi

  # ペインのプロセスIDを取得
  local pane_pid
  pane_pid=$(tmux list-panes -t "${session_name}:0.${pane_index}" -F "#{pane_pid}" 2>/dev/null)

  if [[ -z "$pane_pid" ]]; then
    return 1
  fi

  # プロセスが実行中かチェック（子プロセスがあるかで判断）
  local child_count
  child_count=$(pgrep -P "$pane_pid" | wc -l)

  if [[ "$child_count" -gt 0 ]]; then
    return 0 # 実行中
  else
    return 1 # 待機中
  fi
}

# すべてのペインの実行状態をチェック
check_all_panes_status() {
  local session_name="$1"

  if ! check_tmux; then
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    log_error "セッションが存在しません: ${session_name}"
    return 1
  fi

  # ペイン数を取得
  local pane_count
  pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)

  log_section "ペイン実行状態: ${session_name}"

  local running=0
  local idle=0

  for ((i=0; i<pane_count; i++)); do
    if is_pane_running "$session_name" "$i"; then
      echo "Pane ${i}: 🔄 実行中"
      ((running++))
    else
      echo "Pane ${i}: ⏸️  待機中"
      ((idle++))
    fi
  done

  echo ""
  echo "実行中: ${running} / 待機中: ${idle} / 合計: ${pane_count}"

  return 0
}
