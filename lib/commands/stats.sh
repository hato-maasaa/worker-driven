#!/usr/bin/env bash

# wkd stats - 統計情報表示

show_stats() {
  log_section "Worker-driven Dev 統計情報"

  # Epic統計
  local epics_count=0
  if [[ -d "tasks/epics" ]]; then
    epics_count=$(find tasks/epics -name "*.md" -type f 2>/dev/null | grep -v ".gitkeep" | wc -l | tr -d ' ')
  fi

  # Task統計
  local tasks_count=0
  if [[ -d "tasks" ]]; then
    tasks_count=$(find tasks -name "TASK-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Worker統計
  local workers_total=0
  local workers_completed=0
  local workers_running=0
  local workers_failed=0
  local workers_pending=0

  if [[ -d ".workspaces/.workers" ]]; then
    for worker_file in .workspaces/.workers/*.json; do
      if [[ -f "$worker_file" ]]; then
        ((workers_total++))

        local status
        status=$(jq -r '.status' "$worker_file")

        case "$status" in
          completed) ((workers_completed++)) ;;
          running) ((workers_running++)) ;;
          failed) ((workers_failed++)) ;;
          pending) ((workers_pending++)) ;;
        esac
      fi
    done
  fi

  # Worktree統計
  local worktrees_count=0
  if [[ -d "${WORKSPACE_ROOT:-}" ]]; then
    worktrees_count=$(find "${WORKSPACE_ROOT}" -maxdepth 1 -type d -name "WRK-*" 2>/dev/null | wc -l | tr -d ' ')
  fi

  # tmuxセッション統計
  local sessions_count=0
  if command -v tmux &>/dev/null; then
    sessions_count=$(tmux list-sessions 2>/dev/null | grep "^wkd-" | wc -l | tr -d ' ')
  fi

  # 表示
  echo ""
  echo "【プロジェクト統計】"
  echo "  Epic数:        ${epics_count}"
  echo "  Task数:        ${tasks_count}"
  echo ""

  echo "【Worker統計】"
  echo "  合計:          ${workers_total}"
  echo "  ✅ 完了:       ${workers_completed}"
  echo "  🔄 実行中:     ${workers_running}"
  echo "  ❌ 失敗:       ${workers_failed}"
  echo "  ⏸️  待機中:    ${workers_pending}"
  echo ""

  if [[ $workers_total -gt 0 ]]; then
    local completion_rate=$((workers_completed * 100 / workers_total))
    echo "  完了率:        ${completion_rate}%"
    echo ""
  fi

  echo "【環境統計】"
  echo "  Worktree数:    ${worktrees_count}"
  echo "  tmuxセッション: ${sessions_count}"
  echo ""

  return 0
}
