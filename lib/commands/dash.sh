#!/usr/bin/env bash

# wkd dash - ダッシュボード表示コマンド

show_dashboard() {
  log_section "Worker-driven Dev Dashboard"

  log_info "ダッシュボード機能は開発中です"
  log_info "現在の状態を確認するには:"
  echo "  wkd list epics     - Epic一覧"
  echo "  wkd list tasks     - Task一覧"
  echo "  wkd list workers   - Worker一覧"

  return 0
}
