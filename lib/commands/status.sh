#!/usr/bin/env bash

# wkd status - ワークスペースとワーカーの実行状況表示

show_status() {
  local session_filter="${1:-}"

  log_section "ワークスペース実行状況"

  # ワーカーメタデータディレクトリの確認
  if [[ ! -d ".workspaces/.workers" ]]; then
    log_info "実行中のワーカーはありません"
    return 0
  fi

  # ワーカーファイルの取得
  local worker_files=(.workspaces/.workers/*.json)

  if [[ ! -f "${worker_files[0]}" ]]; then
    log_info "実行中のワーカーはありません"
    return 0
  fi

  # タスクIDの一覧を取得（重複を除く）
  local task_ids=()
  for worker_file in "${worker_files[@]}"; do
    if [[ -f "$worker_file" ]]; then
      local task_id
      task_id=$(jq -r '.taskId' "$worker_file")

      # task_idsに既に存在するかチェック
      local found=false
      for tid in "${task_ids[@]:-}"; do
        if [[ "$tid" == "$task_id" ]]; then
          found=true
          break
        fi
      done

      if [[ "$found" == "false" ]]; then
        task_ids+=("$task_id")
      fi
    fi
  done

  # タスクごとに表示
  for task_id in "${task_ids[@]}"; do
    # このタスクに属するワーカーファイルを集める
    local task_worker_files=()
    for worker_file in "${worker_files[@]}"; do
      if [[ -f "$worker_file" ]]; then
        local wf_task_id
        wf_task_id=$(jq -r '.taskId' "$worker_file")
        if [[ "$wf_task_id" == "$task_id" ]]; then
          task_worker_files+=("$worker_file")
        fi
      fi
    done

    local first_worker_file="${task_worker_files[0]}"

    local epic_id
    epic_id=$(jq -r '.epicId' "$first_worker_file")

    local session_name
    session_name="wkd-${epic_id}-${task_id}"

    # セッションフィルタが指定されている場合はチェック
    if [[ -n "$session_filter" ]] && [[ "$session_name" != "$session_filter" ]]; then
      continue
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Task: ${task_id} (Epic: ${epic_id})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # tmuxセッションの状態
    if command -v tmux &>/dev/null && tmux has-session -t "$session_name" 2>/dev/null; then
      echo "🖥️  tmuxセッション: ${session_name} (アクティブ)"
      echo "   接続: tmux attach -t ${session_name}"
    else
      echo "🖥️  tmuxセッション: なし"
    fi

    echo ""
    echo "Workers:"
    echo "┌─────────┬──────────────────────────────────────────────┬────────────┬─────────────────────┐"
    echo "│ ID      │ タイトル                                     │ ステータス │ 最終更新            │"
    echo "├─────────┼──────────────────────────────────────────────┼────────────┼─────────────────────┤"

    # ワーカーを表示
    for worker_file in "${task_worker_files[@]}"; do
      local worker_id title status started_at completed_at

      worker_id=$(jq -r '.workerId' "$worker_file")
      title=$(jq -r '.title' "$worker_file")
      status=$(jq -r '.status' "$worker_file")
      started_at=$(jq -r '.startedAt // ""' "$worker_file")
      completed_at=$(jq -r '.completedAt // ""' "$worker_file")

      # タイトルを40文字に切り詰め
      local display_title
      if [[ ${#title} -gt 40 ]]; then
        display_title="${title:0:37}..."
      else
        display_title="$title"
      fi

      # ステータス表示
      local status_icon
      case "$status" in
        pending)   status_icon="⏸️  待機中" ;;
        running)   status_icon="🔄 実行中" ;;
        completed) status_icon="✅ 完了" ;;
        failed)    status_icon="❌ 失敗" ;;
        *)         status_icon="❓ 不明" ;;
      esac

      # 最終更新時刻
      local last_update
      if [[ -n "$completed_at" ]] && [[ "$completed_at" != "null" ]]; then
        last_update=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$completed_at" "+%m/%d %H:%M" 2>/dev/null || echo "$completed_at")
      elif [[ -n "$started_at" ]] && [[ "$started_at" != "null" ]]; then
        last_update=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" "+%m/%d %H:%M" 2>/dev/null || echo "$started_at")
      else
        last_update="---"
      fi

      printf "│ %-7s │ %-44s │ %-10s │ %-19s │\n" "$worker_id" "$display_title" "$status_icon" "$last_update"
    done

    echo "└─────────┴──────────────────────────────────────────────┴────────────┴─────────────────────┘"

    # 統計情報
    local total=0 pending=0 running=0 completed=0 failed=0

    for worker_file in "${task_worker_files[@]}"; do
      ((total++))
      local status
      status=$(jq -r '.status' "$worker_file")

      case "$status" in
        pending)   ((pending++)) ;;
        running)   ((running++)) ;;
        completed) ((completed++)) ;;
        failed)    ((failed++)) ;;
      esac
    done

    echo ""
    echo "📊 統計: 合計 ${total} / 完了 ${completed} / 実行中 ${running} / 待機中 ${pending} / 失敗 ${failed}"

    if [[ $total -gt 0 ]]; then
      local completion_rate=$((completed * 100 / total))
      echo "   進捗率: ${completion_rate}%"
    fi
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  return 0
}

# 特定のワーカーの詳細表示
show_worker_detail() {
  local worker_id="$1"

  local worker_file=".workspaces/.workers/${worker_id}.json"

  if [[ ! -f "$worker_file" ]]; then
    log_error "ワーカーが見つかりません: ${worker_id}"
    return 1
  fi

  log_section "ワーカー詳細: ${worker_id}"

  # メタデータを読み込み
  local metadata
  metadata=$(cat "$worker_file")

  echo "ID:          $(echo "$metadata" | jq -r '.workerId')"
  echo "タイトル:    $(echo "$metadata" | jq -r '.title')"
  echo "タスクID:    $(echo "$metadata" | jq -r '.taskId')"
  echo "Epic ID:     $(echo "$metadata" | jq -r '.epicId')"
  echo "ステータス:  $(echo "$metadata" | jq -r '.status')"
  echo "作成日時:    $(echo "$metadata" | jq -r '.createdAt')"
  echo "開始日時:    $(echo "$metadata" | jq -r '.startedAt // "---"')"
  echo "完了日時:    $(echo "$metadata" | jq -r '.completedAt // "---"')"
  echo "ブランチ:    $(echo "$metadata" | jq -r '.branchName')"
  echo "Worktree:    $(echo "$metadata" | jq -r '.worktreePath')"
  echo ""
  echo "プロンプト:"
  echo "$(echo "$metadata" | jq -r '.prompt')"
  echo ""
  echo "対象ファイル:"
  echo "$metadata" | jq -r '.files[]' | sed 's/^/  - /'
  echo ""

  # tmuxペインの出力を表示
  local task_id epic_id
  task_id=$(echo "$metadata" | jq -r '.taskId')
  epic_id=$(echo "$metadata" | jq -r '.epicId')

  local session_name="wkd-${epic_id}-${task_id}"

  if command -v tmux &>/dev/null && tmux has-session -t "$session_name" 2>/dev/null; then
    echo "最新の出力 (最後の20行):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # ペイン番号を取得（worker_idから）
    local pane_index
    pane_index=$(echo "$worker_id" | sed 's/WRK-0*//' | awk '{print $1 - 1}')

    tmux capture-pane -t "${session_name}:0.${pane_index}" -p 2>/dev/null | tail -20 || echo "出力を取得できませんでした"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  return 0
}
