#!/usr/bin/env bash

# wkd cleanup - 完了したワーカーのクリーンアップ

cleanup_completed_workers() {
  local keep_branches="${1:-false}"
  local dry_run="${2:-false}"

  log_section "ワーカークリーンアップ"

  # ワーカーメタデータディレクトリの確認
  if [[ ! -d ".workspaces/.workers" ]]; then
    log_info "ワーカーメタデータが存在しません"
    return 0
  fi

  local total_workers=0
  local completed_workers=0
  local running_workers=0
  local cleaned_workers=0

  # 全ワーカーメタデータをスキャン
  for worker_file in .workspaces/.workers/WRK-*.json; do
    if [[ ! -f "$worker_file" ]]; then
      continue
    fi

    ((total_workers++))

    local worker_id status worktree_path branch_name
    worker_id=$(jq -r '.workerId' "$worker_file")
    status=$(jq -r '.status' "$worker_file")
    worktree_path=$(jq -r '.worktreePath' "$worker_file")
    branch_name=$(jq -r '.branchName' "$worker_file")

    if [[ "$status" == "completed" ]]; then
      ((completed_workers++))

      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] 削除対象: ${worker_id} (${status})"
        continue
      fi

      log_step "クリーンアップ中: ${worker_id}"

      # Worktreeを削除
      if [[ -d "$worktree_path" ]]; then
        if git worktree remove "$worktree_path" --force 2>/dev/null; then
          log_debug "Worktreeを削除: ${worktree_path}"
        else
          log_warn "Worktree削除に失敗: ${worktree_path}"
          rm -rf "$worktree_path"
        fi
      fi

      # ブランチを削除（オプション）
      if [[ "$keep_branches" == "false" ]]; then
        if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
          # リモートにプッシュ済みか確認
          if git branch -r | grep -q "origin/${branch_name}"; then
            log_debug "ブランチはリモートに存在するため保持: ${branch_name}"
          else
            git branch -D "$branch_name" 2>/dev/null && log_debug "ブランチを削除: ${branch_name}"
          fi
        fi
      fi

      # メタデータファイルを削除
      rm -f "$worker_file"
      log_success "クリーンアップ完了: ${worker_id}"
      ((cleaned_workers++))

    elif [[ "$status" == "running" ]] || [[ "$status" == "pending" ]]; then
      ((running_workers++))
      log_debug "実行中のためスキップ: ${worker_id} (${status})"
    fi
  done

  # worktree情報をクリーンアップ
  git worktree prune 2>/dev/null || true

  # 統計表示
  echo ""
  log_section "クリーンアップ完了"
  echo "合計ワーカー数: ${total_workers}"
  echo "  - 完了済み: ${completed_workers}"
  echo "  - 実行中/待機中: ${running_workers}"
  echo "  - クリーンアップ: ${cleaned_workers}"
  echo ""

  if [[ $cleaned_workers -gt 0 ]]; then
    log_success "${cleaned_workers} 個のワーカーをクリーンアップしました"
  else
    log_info "クリーンアップ対象のワーカーはありません"
  fi

  return 0
}

# tmuxセッションのクリーンアップ
cleanup_tmux_sessions() {
  local dry_run="${1:-false}"

  if ! command -v tmux &>/dev/null; then
    log_debug "tmuxが利用できません"
    return 0
  fi

  log_section "tmuxセッションクリーンアップ"

  local cleaned_sessions=0

  # wkd-で始まるセッションを探す
  while IFS= read -r session_name; do
    # セッションにアクティブなペインがあるか確認
    local pane_count
    pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)

    if [[ $pane_count -eq 0 ]]; then
      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] 削除対象セッション: ${session_name}"
      else
        tmux kill-session -t "$session_name" 2>/dev/null
        log_success "セッションを削除: ${session_name}"
        ((cleaned_sessions++))
      fi
    fi
  done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^wkd-" || true)

  if [[ $cleaned_sessions -gt 0 ]]; then
    log_success "${cleaned_sessions} 個のセッションをクリーンアップしました"
  else
    log_info "クリーンアップ対象のセッションはありません"
  fi

  return 0
}

# 全クリーンアップ実行
cleanup_all() {
  local keep_branches="${1:-false}"
  local dry_run="${2:-false}"
  local clean_tmux="${3:-true}"

  if [[ "$dry_run" == "true" ]]; then
    log_section "クリーンアップ (DRY RUN モード)"
    echo "実際の削除は行いません。削除対象のみを表示します。"
    echo ""
  fi

  # ワーカークリーンアップ
  cleanup_completed_workers "$keep_branches" "$dry_run"

  # tmuxセッションクリーンアップ
  if [[ "$clean_tmux" == "true" ]]; then
    cleanup_tmux_sessions "$dry_run"
  fi

  return 0
}

# ヘルプ表示
show_cleanup_help() {
  cat <<EOF
Usage: wkd cleanup [OPTIONS]

完了したワーカーのクリーンアップを行います。

Options:
  --keep-branches    ブランチを削除せず保持する
  --dry-run          実際の削除を行わず、削除対象のみ表示
  --no-tmux          tmuxセッションのクリーンアップをスキップ
  -h, --help         このヘルプを表示

Examples:
  wkd cleanup                     # 完了したワーカーをクリーンアップ
  wkd cleanup --dry-run           # 削除対象を確認（実際には削除しない）
  wkd cleanup --keep-branches     # ブランチを保持してクリーンアップ

Description:
  このコマンドは以下をクリーンアップします：
  - 完了したワーカーのworktree
  - 完了したワーカーのメタデータ
  - 未使用のtmuxセッション
  - （オプション）ローカルブランチ

  実行中または待機中のワーカーは削除されません。
EOF
}
