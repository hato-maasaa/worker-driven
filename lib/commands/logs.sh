#!/usr/bin/env bash

# wkd logs - Workerのログ表示

show_logs() {
  local worker_id="$1"

  if [[ -z "$worker_id" ]]; then
    log_error "Worker IDを指定してください"
    log_info "使用方法: wkd logs <worker-id>"
    return 1
  fi

  log_section "Workerログ: ${worker_id}"

  # ログディレクトリ
  local log_dir="${WORKSPACE_ROOT}/.logs/${worker_id}"

  if [[ ! -d "$log_dir" ]]; then
    log_error "ログディレクトリが見つかりません: ${log_dir}"
    return 1
  fi

  # ログファイル
  local log_file="${log_dir}/claude-output.log"
  local error_log="${log_dir}/claude-error.log"

  # 標準出力ログ
  if [[ -f "$log_file" ]]; then
    echo "=== 標準出力 ==="
    cat "$log_file"
    echo ""
  else
    log_info "出力ログがありません"
  fi

  # エラーログ
  if [[ -f "$error_log" ]] && [[ -s "$error_log" ]]; then
    echo "=== エラー出力 ==="
    cat "$error_log"
    echo ""
  fi

  return 0
}
