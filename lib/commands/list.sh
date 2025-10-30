#!/usr/bin/env bash

# wkd list - 一覧表示コマンド

list_items() {
  local type="${1:-all}"

  case "$type" in
    epics)
      # create.sh にある list_epics を使用
      source "${LIB_DIR}/commands/create.sh"
      list_epics
      ;;

    tasks)
      local epic_id="${2:-}"
      source "${LIB_DIR}/commands/create.sh"
      list_tasks "$epic_id"
      ;;

    workers)
      list_workers
      ;;

    all)
      log_section "プロジェクト概要"
      echo ""

      source "${LIB_DIR}/commands/create.sh"
      list_epics
      echo ""

      list_tasks
      echo ""

      list_workers
      ;;

    *)
      log_error "未知のタイプ: ${type}"
      log_info "使用方法: wkd list [epics|tasks|workers|all]"
      return 1
      ;;
  esac

  return 0
}

# Worker一覧を表示
list_workers() {
  log_section "Worker一覧"

  local workers_dir=".workspaces/.workers"

  if [[ ! -d "$workers_dir" ]]; then
    log_info "Workerディレクトリが存在しません"
    return 0
  fi

  local worker_files=("$workers_dir"/*.json)

  if [[ ! -f "${worker_files[0]}" ]]; then
    log_info "Workerが見つかりません"
    return 0
  fi

  local count=0

  for worker_file in "${worker_files[@]}"; do
    if [[ -f "$worker_file" ]]; then
      local worker_id
      local task_id
      local title
      local status

      worker_id=$(jq -r '.workerId // empty' "$worker_file")
      task_id=$(jq -r '.taskId // empty' "$worker_file")
      title=$(jq -r '.title // empty' "$worker_file")
      status=$(jq -r '.status // empty' "$worker_file")

      local status_icon
      case "$status" in
        completed) status_icon="✅" ;;
        running) status_icon="🔄" ;;
        failed) status_icon="❌" ;;
        pending) status_icon="⏸️ " ;;
        *) status_icon="❓" ;;
      esac

      echo "${status_icon} ${worker_id} (${task_id}): ${title}"
      ((count++))
    fi
  done

  echo ""
  log_success "合計: ${count} 個のWorker"

  return 0
}
