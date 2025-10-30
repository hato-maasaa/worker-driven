#!/usr/bin/env bash

# wkd retry - Workerの再実行

retry_workers() {
  local option="${1:-}"

  if [[ -z "$option" ]]; then
    log_error "オプションを指定してください"
    log_info "使用方法:"
    echo "  wkd retry --failed        失敗したWorkerを再実行"
    echo "  wkd retry <worker-id>     特定のWorkerを再実行"
    return 1
  fi

  case "$option" in
    --failed)
      retry_failed_workers
      ;;
    *)
      retry_specific_worker "$option"
      ;;
  esac

  return 0
}

# 失敗したWorkerを再実行
retry_failed_workers() {
  log_section "失敗したWorkerの再実行"

  local workers_dir=".workspaces/.workers"

  if [[ ! -d "$workers_dir" ]]; then
    log_info "Workerディレクトリが存在しません"
    return 0
  fi

  local failed_workers=()

  for worker_file in "$workers_dir"/*.json; do
    if [[ -f "$worker_file" ]]; then
      local status
      status=$(jq -r '.status' "$worker_file")

      if [[ "$status" == "failed" ]]; then
        local worker_id
        worker_id=$(jq -r '.workerId' "$worker_file")
        failed_workers+=("$worker_id")
      fi
    fi
  done

  if [[ ${#failed_workers[@]} -eq 0 ]]; then
    log_info "失敗したWorkerはありません"
    return 0
  fi

  log_info "失敗したWorker: ${#failed_workers[@]} 個"

  for worker_id in "${failed_workers[@]}"; do
    retry_specific_worker "$worker_id"
  done

  return 0
}

# 特定のWorkerを再実行
retry_specific_worker() {
  local worker_id="$1"

  log_step "Workerを再実行中: ${worker_id}"

  local workers_dir=".workspaces/.workers"
  local metadata_file="${workers_dir}/${worker_id}.json"

  if [[ ! -f "$metadata_file" ]]; then
    log_error "Workerメタデータが見つかりません: ${worker_id}"
    return 1
  fi

  # TODO: 実際の再実行ロジックを実装
  log_info "再実行機能は開発中です"

  return 0
}
