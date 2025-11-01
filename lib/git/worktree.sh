#!/usr/bin/env bash

# git worktree 操作

# Workerのworktreeを作成
create_worker_worktree() {
  local worker_id="$1"
  local branch_name="$2"
  local base_branch="${3:-$DEFAULT_BRANCH}"

  local worktree_dir="${WORKSPACE_ROOT}/${worker_id}"

  log_step "Worktreeを作成中: ${worker_id}"

  # worktreeディレクトリが既に存在する場合は削除
  if [[ -d "$worktree_dir" ]]; then
    log_warn "既存のworktreeを削除します: ${worktree_dir}"
    remove_worker_worktree "$worker_id"
  fi

  # ベースブランチから新しいブランチを作成してworktree追加
  if git worktree add -b "$branch_name" "$worktree_dir" "$base_branch" 2>/dev/null; then
    log_success "Worktreeを作成しました: ${worktree_dir}"
    return 0
  else
    log_error "Worktreeの作成に失敗しました: ${worker_id}"
    return 1
  fi
}

# Workerのworktreeを削除
remove_worker_worktree() {
  local worker_id="$1"
  local worktree_dir="${WORKSPACE_ROOT}/${worker_id}"

  if [[ ! -d "$worktree_dir" ]]; then
    log_debug "Worktreeが存在しません: ${worktree_dir}"
    return 0
  fi

  log_step "Worktreeを削除中: ${worker_id}"

  # worktreeを削除
  if git worktree remove "$worktree_dir" --force 2>/dev/null; then
    log_success "Worktreeを削除しました: ${worker_id}"
    return 0
  else
    # 削除に失敗した場合は手動で削除
    log_warn "通常の削除に失敗しました。ディレクトリを直接削除します"
    rm -rf "$worktree_dir"
    git worktree prune 2>/dev/null
    return 0
  fi
}

# すべてのworktreeを一覧表示
list_worktrees() {
  log_section "Git Worktrees"
  git worktree list
}

# Workerのworktreeが存在するかチェック
worktree_exists() {
  local worker_id="$1"
  local worktree_dir="${WORKSPACE_ROOT}/${worker_id}"

  [[ -d "$worktree_dir" ]]
}

# ブランチ名を生成
generate_branch_name() {
  local worker_id="$1"
  local task_name="${2:-task}"

  # ブランチ名: feat/task-name__worker-id (小文字)
  local branch_name="${BRANCH_PREFIX}/${task_name}__${worker_id}"
  echo "$branch_name" | tr '[:upper:]' '[:lower:]' # 小文字に変換 (Bash 3.2互換)
}

# Workerの作業完了後のクリーンアップ
cleanup_worker_worktree() {
  local worker_id="$1"
  local keep_branch="${2:-false}"

  local worktree_dir="${WORKSPACE_ROOT}/${worker_id}"

  # worktreeを削除
  remove_worker_worktree "$worker_id"

  # ブランチも削除する場合
  if [[ "$keep_branch" != "true" ]]; then
    local branch_name
    branch_name=$(generate_branch_name "$worker_id")

    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
      log_step "ブランチを削除中: ${branch_name}"
      git branch -D "$branch_name" 2>/dev/null || true
    fi
  fi
}

# すべてのWorker worktreeをクリーンアップ
cleanup_all_worktrees() {
  log_section "全Worktreeのクリーンアップ"

  if [[ ! -d "$WORKSPACE_ROOT" ]]; then
    log_info "Workspaceディレクトリが存在しません"
    return 0
  fi

  local count=0

  for worker_dir in "${WORKSPACE_ROOT}"/WRK-*; do
    if [[ -d "$worker_dir" ]]; then
      local worker_id
      worker_id=$(basename "$worker_dir")

      remove_worker_worktree "$worker_id"
      ((count++))
    fi
  done

  # worktree情報をクリーンアップ
  git worktree prune 2>/dev/null || true

  log_success "${count} 個のWorktreeをクリーンアップしました"
}
