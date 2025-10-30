#!/usr/bin/env bash

# wkd create - Epicからタスクを生成するコマンド

# Epic名からタスクを生成（CLIエントリーポイント）
create_tasks() {
  local epic_name="$1"
  local auto_run="${2:-false}"

  if [[ -z "$epic_name" ]]; then
    log_error "Epic名を指定してください"
    log_info "使用方法: wkd create tasks <epic-name>"
    return 1
  fi

  # Epic ファイルパスを生成
  local epic_file="tasks/epics/${epic_name}.md"

  # .md拡張子がない場合は追加
  if [[ "$epic_name" != *.md ]]; then
    epic_file="tasks/epics/${epic_name}.md"
  else
    epic_file="tasks/epics/${epic_name}"
  fi

  # ファイル存在確認
  if [[ ! -f "$epic_file" ]]; then
    log_error "Epicファイルが見つかりません: ${epic_file}"
    log_info "利用可能なEpic:"
    list_epics
    return 1
  fi

  # Epic から Task を生成
  create_tasks_from_epic "$epic_file" "$auto_run"
}

create_tasks_from_epic() {
  local epic_file="$1"
  local auto_run="${2:-false}"

  log_section "タスク生成: $(basename "$epic_file")"

  # Epicファイルの存在確認
  if [[ ! -f "$epic_file" ]]; then
    log_error "Epicファイルが見つかりません: ${epic_file}"
    return 1
  fi

  # Epic情報を解析
  log_step "Epicファイルを解析中..."
  local epic_json
  epic_json=$(parse_epic_file "$epic_file")

  if [[ -z "$epic_json" ]]; then
    log_error "Epicファイルの解析に失敗しました"
    return 1
  fi

  local epic_id
  local epic_title
  local epic_content

  epic_id=$(echo "$epic_json" | jq -r '.id // empty')
  epic_title=$(echo "$epic_json" | jq -r '.title // empty')
  epic_content=$(echo "$epic_json" | jq -r '.content // empty')

  if [[ -z "$epic_id" ]] || [[ -z "$epic_title" ]]; then
    log_error "Epic IDまたはタイトルが取得できませんでした"
    return 1
  fi

  log_success "Epic: ${epic_title} (${epic_id})"

  # タスク生成ディレクトリを作成
  local tasks_dir="tasks/${epic_id}"
  mkdir -p "$tasks_dir"

  # Claude Code Plan agentを使ってタスク分割
  log_step "Claude Code Plan agentでタスクを分割中..."

  local plan_prompt
  plan_prompt=$(cat <<EOF
あなたは開発タスクを分割する専門家です。
以下のEpicを分析し、実装可能な具体的なタスクに分割してください。

# Epic: ${epic_title}

${epic_content}

# 出力形式

以下のJSON形式で出力してください:

\`\`\`json
{
  "tasks": [
    {
      "id": "TASK-001",
      "title": "タスクタイトル",
      "description": "タスクの詳細説明",
      "acceptance_criteria": [
        "受け入れ基準1",
        "受け入れ基準2"
      ],
      "dependencies": [],
      "estimated_lines": 100
    }
  ]
}
\`\`\`

# 要件

1. 各タスクは独立して実装可能であること
2. タスクIDは TASK-001, TASK-002 のように連番
3. 各タスクの変更行数は${MAX_CHANGED_LINES:-400}行以内を目安にすること
4. 依存関係がある場合はdependenciesに先行タスクIDを記載
5. 受け入れ基準は具体的かつ検証可能であること
EOF
)

  local plan_output
  plan_output=$(execute_claude_plan "$plan_prompt" 2>&1)

  if [[ $? -ne 0 ]]; then
    log_error "Claude Code Plan agentの実行に失敗しました"
    log_debug "出力: ${plan_output}"
    return 1
  fi

  # JSON部分を抽出（```json ... ``` で囲まれている場合）
  local tasks_json
  tasks_json=$(echo "$plan_output" | sed -n '/```json/,/```/p' | sed '1d;$d')

  # JSON形式でない場合は全体を試す
  if [[ -z "$tasks_json" ]]; then
    tasks_json="$plan_output"
  fi

  # JSONの妥当性チェック
  if ! echo "$tasks_json" | jq empty 2>/dev/null; then
    log_error "Claude Codeからの出力がJSON形式ではありません"
    log_debug "出力: ${plan_output}"
    return 1
  fi

  # タスク数を取得
  local task_count
  task_count=$(echo "$tasks_json" | jq '.tasks | length')

  if [[ -z "$task_count" ]] || [[ "$task_count" -eq 0 ]]; then
    log_error "タスクが生成されませんでした"
    return 1
  fi

  log_success "${task_count} 個のタスクを生成しました"

  # 各タスクファイルを作成
  log_step "タスクファイルを作成中..."

  local created_tasks=()

  for i in $(seq 0 $((task_count - 1))); do
    local task_data
    task_data=$(echo "$tasks_json" | jq ".tasks[$i]")

    local task_id
    local task_title
    local task_description
    local task_criteria
    local task_dependencies
    local task_lines

    task_id=$(echo "$task_data" | jq -r '.id')
    task_title=$(echo "$task_data" | jq -r '.title')
    task_description=$(echo "$task_data" | jq -r '.description')
    task_criteria=$(echo "$task_data" | jq -r '.acceptance_criteria[]' 2>/dev/null || echo "")
    task_dependencies=$(echo "$task_data" | jq -r '.dependencies[]' 2>/dev/null || echo "")
    task_lines=$(echo "$task_data" | jq -r '.estimated_lines // 0')

    # タスクファイルを生成
    local task_file="${tasks_dir}/${task_id}.md"

    generate_task_markdown "$task_id" "$task_title" "$task_description" "$task_criteria" "$task_dependencies" "$epic_id" "$task_lines" > "$task_file"

    if [[ -f "$task_file" ]]; then
      log_success "作成: ${task_file}"
      created_tasks+=("$task_id")
    else
      log_error "タスクファイルの作成に失敗: ${task_id}"
    fi
  done

  # 結果サマリー
  log_section "タスク生成完了"
  echo "Epic: ${epic_title} (${epic_id})"
  echo "生成タスク数: ${#created_tasks[@]}"
  echo "保存先: ${tasks_dir}/"
  echo ""
  echo "生成されたタスク:"
  for task_id in "${created_tasks[@]}"; do
    echo "  - ${task_id}"
  done
  echo ""

  # 自動実行オプション
  if [[ "$auto_run" == "true" ]]; then
    log_section "タスクの自動実行"

    if confirm "すべてのタスクを実行しますか？" "y"; then
      # 各タスクを順番に実行
      for task_id in "${created_tasks[@]}"; do
        local task_file="${tasks_dir}/${task_id}.md"
        log_info "タスク実行: ${task_id}"

        # run コマンドを呼び出し
        run_task "$task_file" "false" # auto_prはfalse（手動確認）

        if [[ $? -ne 0 ]]; then
          log_warn "タスク ${task_id} の実行に失敗しました"

          if ! confirm "次のタスクに進みますか？" "y"; then
            log_info "実行を中断しました"
            break
          fi
        fi
      done
    else
      log_info "手動で実行する場合:"
      echo "  wkd run ${tasks_dir}/${created_tasks[0]}.md"
    fi
  else
    log_info "タスクを実行するには:"
    echo "  wkd run ${tasks_dir}/${created_tasks[0]}.md"
  fi

  return 0
}

# Epic一覧を表示
list_epics() {
  log_section "Epic一覧"

  local epics_dir="tasks/epics"

  if [[ ! -d "$epics_dir" ]]; then
    log_info "Epicディレクトリが存在しません: ${epics_dir}"
    return 0
  fi

  local epic_files=("$epics_dir"/*.md)

  if [[ ! -f "${epic_files[0]}" ]]; then
    log_info "Epicファイルが見つかりません"
    return 0
  fi

  local count=0

  for epic_file in "${epic_files[@]}"; do
    if [[ -f "$epic_file" ]] && [[ "$(basename "$epic_file")" != ".gitkeep" ]]; then
      local epic_json
      epic_json=$(parse_epic_file "$epic_file")

      local epic_id
      local epic_title

      epic_id=$(echo "$epic_json" | jq -r '.id // empty')
      epic_title=$(echo "$epic_json" | jq -r '.title // empty')

      if [[ -n "$epic_id" ]] && [[ -n "$epic_title" ]]; then
        echo "[${epic_id}] ${epic_title}"
        echo "  ファイル: ${epic_file}"

        # タスク数をカウント
        local tasks_dir="tasks/${epic_id}"
        if [[ -d "$tasks_dir" ]]; then
          local task_count
          task_count=$(find "$tasks_dir" -name "TASK-*.md" 2>/dev/null | wc -l)
          echo "  タスク数: ${task_count}"
        else
          echo "  タスク数: 0 (未生成)"
        fi

        echo ""
        ((count++))
      fi
    fi
  done

  if [[ $count -eq 0 ]]; then
    log_info "Epicファイルが見つかりません"
  else
    log_success "合計: ${count} 個のEpic"
  fi

  return 0
}

# タスク一覧を表示
list_tasks() {
  local epic_id="${1:-}"

  if [[ -z "$epic_id" ]]; then
    # 全Epicのタスクを表示
    log_section "全タスク一覧"

    for tasks_dir in tasks/*/; do
      if [[ -d "$tasks_dir" ]]; then
        local dir_epic_id
        dir_epic_id=$(basename "$tasks_dir")

        if [[ "$dir_epic_id" == "epics" ]]; then
          continue
        fi

        echo "Epic: ${dir_epic_id}"
        list_tasks_for_epic "$dir_epic_id"
        echo ""
      fi
    done
  else
    # 特定EpicのタスクのみFを表示
    log_section "タスク一覧: ${epic_id}"
    list_tasks_for_epic "$epic_id"
  fi

  return 0
}

# 特定Epicのタスク一覧を表示（内部関数）
list_tasks_for_epic() {
  local epic_id="$1"
  local tasks_dir="tasks/${epic_id}"

  if [[ ! -d "$tasks_dir" ]]; then
    log_info "  タスクディレクトリが存在しません"
    return 0
  fi

  local task_files=("$tasks_dir"/TASK-*.md)

  if [[ ! -f "${task_files[0]}" ]]; then
    log_info "  タスクが見つかりません"
    return 0
  fi

  for task_file in "${task_files[@]}"; do
    if [[ -f "$task_file" ]]; then
      local task_id
      task_id=$(basename "$task_file" .md)

      # frontmatterからタイトルを取得
      local title
      title=$(extract_frontmatter "$task_file" | grep "^title:" | sed 's/^title: *//' | tr -d '"')

      # ワーカーステータスをチェック
      local worker_status=""
      local workers_dir=".workspaces/.workers"

      if [[ -d "$workers_dir" ]]; then
        local worker_file
        worker_file=$(find "$workers_dir" -name "*.json" -exec grep -l "\"taskId\": \"${task_id}\"" {} \; 2>/dev/null | head -1)

        if [[ -n "$worker_file" ]]; then
          local status
          status=$(jq -r '.status // empty' "$worker_file" 2>/dev/null)
          worker_status=" [${status}]"
        fi
      fi

      echo "  ${task_id}: ${title}${worker_status}"
    fi
  done

  return 0
}
