#!/usr/bin/env bash

# wkd run - タスクを実行するコマンド

run_task() {
  local task_file="$1"
  local auto_pr="${2:-false}"

  log_section "タスク実行: $(basename "$task_file")"

  # タスクファイルの存在確認
  if [[ ! -f "$task_file" ]]; then
    log_error "タスクファイルが見つかりません: ${task_file}"
    return 1
  fi

  # タスク情報を解析
  log_step "タスクファイルを解析中..."

  local task_json
  task_json=$(parse_task_file "$task_file")

  # デバッグ: parse_task_fileの生出力を保存
  echo "$task_json" > /tmp/wkd-parse-task-output.json
  log_debug "parse_task_file出力を保存: /tmp/wkd-parse-task-output.json"

  if [[ -z "$task_json" ]]; then
    log_error "タスクファイルの解析に失敗しました"
    return 1
  fi

  local task_id
  local task_title
  local task_description
  local epic_id

  task_id=$(echo "$task_json" | jq -r '.task // empty')
  task_title=$(echo "$task_json" | jq -r '.title // empty')
  task_description=$(echo "$task_json" | jq -r '.description // empty')
  epic_id=$(echo "$task_json" | jq -r '.epic // empty')

  # デバッグ出力
  log_debug "task_json: ${task_json}"
  log_debug "task_id: ${task_id}"
  log_debug "task_title: ${task_title}"

  if [[ -z "$task_id" ]] || [[ -z "$task_title" ]]; then
    log_error "タスクIDまたはタイトルが取得できませんでした"
    log_debug "task_json内容:"
    echo "$task_json" | jq . >&2
    return 1
  fi

  log_success "Task: ${task_title} (${task_id})"

  # Claude Code Plan agentでワーカーに分割
  log_step "Claude Code Plan agentでワーカーを分割中..."

  local plan_prompt
  plan_prompt=$(cat <<'EOF_PROMPT'
IMPORTANT: You must respond ONLY with valid JSON. Do not include any explanatory text, markdown formatting, or commentary outside the JSON structure.

Task: Analyze the following task and split it into smaller, parallelizable worker units.

Task Title: ${TASK_TITLE}

Task Description:
${TASK_DESCRIPTION}

Required JSON Output Format:
{
  "workers": [
    {
      "id": "WRK-001",
      "title": "Worker title",
      "prompt": "Specific instructions for Claude Code",
      "files": ["path/to/file1.ts", "path/to/file2.ts"],
      "dependencies": []
    }
  ]
}

Requirements:
1. Each worker must be independently executable (assume parallel execution)
2. Worker IDs follow format: WRK-001, WRK-002, etc.
3. prompt field contains specific implementation instructions that Claude Code can execute directly
4. files array lists target files to modify or create
5. Include dependencies array with prerequisite worker IDs if needed
6. Target ${MAX_WORKERS:-5} workers or less

Output ONLY the JSON object. No markdown code blocks, no explanations, just the JSON.
EOF_PROMPT
)

  # Replace placeholders
  plan_prompt="${plan_prompt//\$\{TASK_TITLE\}/$task_title}"
  plan_prompt="${plan_prompt//\$\{TASK_DESCRIPTION\}/$task_description}"
  plan_prompt="${plan_prompt//\$\{MAX_WORKERS\}/${MAX_WORKERS:-5}}"

  local plan_output
  plan_output=$(execute_claude_plan "$plan_prompt" 2>&1)

  if [[ $? -ne 0 ]]; then
    log_error "Claude Code Plan agentの実行に失敗しました"
    log_debug "出力: ${plan_output}"
    return 1
  fi

  # デバッグ: Claudeの生出力を保存
  echo "$plan_output" > /tmp/wkd-claude-workers-output.txt
  log_debug "Claude出力を保存: /tmp/wkd-claude-workers-output.txt"

  # JSON部分を抽出
  local workers_json
  workers_json=$(echo "$plan_output" | sed -n '/```json/,/```/p' | sed '1d;$d')

  if [[ -z "$workers_json" ]]; then
    workers_json="$plan_output"
  fi

  # デバッグ: 抽出されたJSONを保存
  echo "$workers_json" > /tmp/wkd-workers-json.txt
  log_debug "抽出JSON を保存: /tmp/wkd-workers-json.txt"

  # JSONの妥当性チェック
  if ! echo "$workers_json" | jq empty 2>/dev/null; then
    log_error "Claude Codeからの出力がJSON形式ではありません"
    log_debug "出力の最初の10行:"
    echo "$workers_json" | head -10 | while IFS= read -r line; do
      log_debug "  $line"
    done
    return 1
  fi

  # ワーカー数を取得
  local worker_count
  worker_count=$(echo "$workers_json" | jq '.workers | length')

  if [[ -z "$worker_count" ]] || [[ "$worker_count" -eq 0 ]]; then
    log_error "ワーカーが生成されませんでした"
    return 1
  fi

  log_success "${worker_count} 個のワーカーを生成しました"

  # tmuxセッションを作成
  local session_name
  session_name=$(generate_session_name "$epic_id" "$task_id")

  if ! create_tmux_session "$session_name" "$PWD"; then
    log_error "tmuxセッションの作成に失敗しました"
    return 1
  fi

  # 各ワーカーのセットアップと実行
  log_step "ワーカー環境をセットアップ中..."

  local workers_metadata_dir=".workspaces/.workers"
  mkdir -p "$workers_metadata_dir"

  local worker_ids=()

  for i in $(seq 0 $((worker_count - 1))); do
    local worker_data
    worker_data=$(echo "$workers_json" | jq ".workers[$i]")

    local worker_id
    local worker_title
    local worker_prompt
    local worker_files

    worker_id=$(echo "$worker_data" | jq -r '.id')
    worker_title=$(echo "$worker_data" | jq -r '.title')
    worker_prompt=$(echo "$worker_data" | jq -r '.prompt')
    worker_files=$(echo "$worker_data" | jq -r '.files[]' 2>/dev/null || echo "")

    # ブランチ名を生成（epic-id__task-id__worker-id 形式で衝突を防ぐ）
    local branch_name
    branch_name=$(generate_branch_name "$worker_id" "$task_id" "$epic_id")

    # worktreeを作成
    if ! create_worker_worktree "$worker_id" "$branch_name" "$DEFAULT_BRANCH"; then
      log_error "Worktreeの作成に失敗しました: ${worker_id}"
      continue
    fi

    local worktree_dir="${WORKSPACE_ROOT}/${worker_id}"

    # Claude設定をセットアップ
    if ! setup_claude_settings "$worktree_dir"; then
      log_warn "Claude設定のセットアップに失敗しました: ${worker_id}"
    fi

    # ワーカーメタデータを保存
    local metadata_file="${workers_metadata_dir}/${worker_id}.json"

    cat > "$metadata_file" <<EOF
{
  "workerId": "${worker_id}",
  "taskId": "${task_id}",
  "epicId": "${epic_id}",
  "title": "${worker_title}",
  "prompt": $(echo "$worker_prompt" | jq -R -s .),
  "files": $(echo "$worker_files" | jq -R -s 'split("\n") | map(select(length > 0))'),
  "branchName": "${branch_name}",
  "worktreePath": "${worktree_dir}",
  "status": "pending",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "startedAt": null,
  "completedAt": null
}
EOF

    log_success "ワーカーをセットアップ: ${worker_id} - ${worker_title}"
    worker_ids+=("$worker_id")

    # tmuxペインを作成
    create_worker_pane "$session_name" "$worker_id" "$worktree_dir" "$i"
  done

  # レイアウトを調整
  set_tmux_layout "$session_name" "${TMUX_LAYOUT:-tiled}"

  # 実行確認
  log_section "ワーカー実行準備完了"
  echo "タスク: ${task_title} (${task_id})"
  echo "ワーカー数: ${#worker_ids[@]}"
  echo "tmuxセッション: ${session_name}"
  echo ""
  echo "ワーカー一覧:"
  for worker_id in "${worker_ids[@]}"; do
    local metadata_file="${workers_metadata_dir}/${worker_id}.json"
    local worker_title
    worker_title=$(jq -r '.title' "$metadata_file")
    echo "  - ${worker_id}: ${worker_title}"
  done
  echo ""

  if ! confirm "ワーカーを実行しますか？" "y"; then
    log_info "実行をキャンセルしました"
    log_info "後で実行する場合:"
    echo "  tmux attach -t ${session_name}"
    return 0
  fi

  # 各ワーカーを実行
  log_step "ワーカーを実行中..."

  for i in "${!worker_ids[@]}"; do
    local worker_id="${worker_ids[$i]}"
    local metadata_file="${workers_metadata_dir}/${worker_id}.json"

    # メタデータを更新（実行開始）
    local updated_metadata
    updated_metadata=$(jq '.status = "running" | .startedAt = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$metadata_file")
    echo "$updated_metadata" > "$metadata_file"

    # ワーカープロンプトを取得
    local worker_prompt
    worker_prompt=$(jq -r '.prompt' "$metadata_file")

    # worktree_dirを絶対パスに変換（tmuxペインから実行するため）
    local worktree_dir
    worktree_dir=$(cd "${WORKSPACE_ROOT}/${worker_id}" 2>/dev/null && pwd)

    if [[ -z "$worktree_dir" ]]; then
      log_error "Worktreeディレクトリが見つかりません: ${worker_id}"
      continue
    fi

    # Claude Codeをヘッドレスモードで実行するコマンドを生成
    local claude_command
    claude_command="cd '${worktree_dir}' && ${CLAUDE_COMMAND} --headless \"${worker_prompt}\""

    # tmuxペインにコマンドを送信
    send_to_pane "$session_name" "$i" "$claude_command"

    log_success "ワーカーを実行: ${worker_id}"
  done

  # セッションにアタッチ
  log_section "実行中"
  log_info "tmuxセッションにアタッチします"
  log_info "デタッチするには: Ctrl-b d"
  echo ""
  echo "コマンド:"
  echo "  - セッション一覧: tmux list-sessions"
  echo "  - 再アタッチ: tmux attach -t ${session_name}"
  echo "  - ペイン切替: Ctrl-b o"
  echo ""

  sleep 2

  # セッションにアタッチ
  attach_session "$session_name"

  # アタッチから戻ってきた後の処理
  log_section "実行結果の確認"

  # 各ワーカーの状態をチェック
  check_worker_status "${worker_ids[@]}"

  # PR作成オプション
  if [[ "$auto_pr" == "true" ]]; then
    create_prs_for_workers "${worker_ids[@]}"
  else
    log_info "PRを作成する場合:"
    echo "  wkd pr ${task_id}"
  fi

  return 0
}

# ワーカーの状態をチェック
check_worker_status() {
  local worker_ids=("$@")
  local workers_metadata_dir=".workspaces/.workers"

  log_step "ワーカーステータスを確認中..."

  local completed=0
  local failed=0
  local running=0

  for worker_id in "${worker_ids[@]}"; do
    local metadata_file="${workers_metadata_dir}/${worker_id}.json"

    if [[ ! -f "$metadata_file" ]]; then
      log_warn "メタデータが見つかりません: ${worker_id}"
      continue
    fi

    local status
    local worktree_dir

    status=$(jq -r '.status' "$metadata_file")
    worktree_dir=$(jq -r '.worktreePath' "$metadata_file")

    # Claudeの出力ログをチェック（仮の判定ロジック）
    # 実際にはClaude Codeの終了コードやログを確認する必要がある
    if [[ "$status" == "running" ]]; then
      # 簡易的な判定: worktreeにcommitがあれば完了とみなす
      if cd "$worktree_dir" && [[ $(git log --oneline | wc -l) -gt 1 ]]; then
        status="completed"
        local updated_metadata
        updated_metadata=$(jq '.status = "completed" | .completedAt = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$metadata_file")
        echo "$updated_metadata" > "$metadata_file"
      fi
      cd - >/dev/null
    fi

    case "$status" in
      completed)
        echo "✅ ${worker_id}: 完了"
        ((completed++))
        ;;
      failed)
        echo "❌ ${worker_id}: 失敗"
        ((failed++))
        ;;
      running)
        echo "🔄 ${worker_id}: 実行中"
        ((running++))
        ;;
      *)
        echo "⏸️  ${worker_id}: ${status}"
        ;;
    esac
  done

  echo ""
  echo "サマリー: 完了 ${completed} / 失敗 ${failed} / 実行中 ${running} / 合計 ${#worker_ids[@]}"

  return 0
}

# ワーカーのPRを作成
create_prs_for_workers() {
  local worker_ids=("$@")
  local workers_metadata_dir=".workspaces/.workers"

  log_section "PR作成"

  for worker_id in "${worker_ids[@]}"; do
    local metadata_file="${workers_metadata_dir}/${worker_id}.json"

    if [[ ! -f "$metadata_file" ]]; then
      continue
    fi

    local status
    local branch_name
    local worker_title
    local worktree_dir

    status=$(jq -r '.status' "$metadata_file")
    branch_name=$(jq -r '.branchName' "$metadata_file")
    worker_title=$(jq -r '.title' "$metadata_file")
    worktree_dir=$(jq -r '.worktreePath' "$metadata_file")

    # 完了したワーカーのみPR作成
    if [[ "$status" != "completed" ]]; then
      log_debug "スキップ (未完了): ${worker_id}"
      continue
    fi

    log_step "PRを作成中: ${worker_id}"

    # worktreeに移動
    if ! cd "$worktree_dir"; then
      log_error "worktreeに移動できません: ${worktree_dir}"
      continue
    fi

    # 変更があるかチェック
    if [[ -z "$(git status --porcelain)" ]] && [[ $(git log --oneline | wc -l) -le 1 ]]; then
      log_info "変更がありません: ${worker_id}"
      cd - >/dev/null
      continue
    fi

    # コミットがない場合はコミット
    if [[ -n "$(git status --porcelain)" ]]; then
      git add -A
      git commit -m "feat: ${worker_title}

Worker: ${worker_id}

🤖 Generated with Claude Code
" || true
    fi

    # プッシュ
    if ! git push -u origin "$branch_name"; then
      log_error "プッシュに失敗しました: ${worker_id}"
      cd - >/dev/null
      continue
    fi

    # gh コマンドでPR作成
    if command -v gh &>/dev/null; then
      local pr_title="${worker_title}"
      local pr_body="## Worker: ${worker_id}

このPRは Worker-driven Dev CLI によって自動生成されました。

### 実装内容

${worker_title}

🤖 Generated with Claude Code
"

      if gh pr create --title "$pr_title" --body "$pr_body" 2>/dev/null; then
        log_success "PRを作成しました: ${worker_id}"
      else
        log_warn "PR作成に失敗しました (手動で作成してください): ${worker_id}"
      fi
    else
      log_warn "gh コマンドがインストールされていません。手動でPRを作成してください"
      log_info "ブランチ: ${branch_name}"
    fi

    cd - >/dev/null
  done

  return 0
}

# parse_task_file は lib/core/parser.sh で定義されているため、ここでは定義不要
