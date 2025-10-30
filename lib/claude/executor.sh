#!/usr/bin/env bash

# Claude Code 実行とセキュリティ設定

# テンプレートディレクトリ（SCRIPT_DIRが未定義の場合は相対パスから取得）
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  EXECUTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEMPLATE_DIR="${EXECUTOR_SCRIPT_DIR}/../../templates/claude"
else
  TEMPLATE_DIR="${SCRIPT_DIR}/templates/claude"
fi

# Claude設定ディレクトリをセットアップ
setup_claude_settings() {
  local worker_dir="$1"
  local worker_id="${2:-unknown}"

  local claude_dir="${worker_dir}/.claude"
  local hooks_dir="${claude_dir}/hooks"

  # ディレクトリ作成
  mkdir -p "$hooks_dir"

  log_debug "Claude設定ディレクトリを作成: ${claude_dir}"

  # デフォルトのdenyパターン（テンプレートから読み込み）
  local default_settings
  if [[ -f "${TEMPLATE_DIR}/settings.json" ]]; then
    default_settings=$(cat "${TEMPLATE_DIR}/settings.json")
  else
    # テンプレートがない場合は最小限の設定
    default_settings='{
  "permissions": {
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf /* *)",
      "Write(**/.env*)"
    ]
  }
}'
  fi

  # .wkdrc.yamlからカスタムdeny設定を読み込み
  local custom_deny="[]"
  if has_yq && [[ -f "$WKD_CONFIG_FILE" ]]; then
    custom_deny=$(yq eval '.claude.settings.deny' "$WKD_CONFIG_FILE" -o json 2>/dev/null || echo "[]")
  fi

  # デフォルトとカスタムをマージ
  local merged_settings
  if command -v jq >/dev/null 2>&1; then
    local default_deny
    default_deny=$(echo "$default_settings" | jq '.permissions.deny')

    local merged_deny
    merged_deny=$(jq -s '.[0] + .[1] | unique' <(echo "$default_deny") <(echo "$custom_deny"))

    merged_settings=$(jq -n --argjson deny "$merged_deny" '{permissions: {deny: $deny}}')
  else
    # jqがない場合はデフォルト設定のみ使用
    merged_settings="$default_settings"
  fi

  # settings.jsonを生成
  echo "$merged_settings" > "${claude_dir}/settings.json"
  log_debug "settings.json を配置: ${claude_dir}/settings.json"

  # PreToolUseフックをコピー
  if [[ -f "${TEMPLATE_DIR}/hooks/PreToolUse" ]]; then
    cp "${TEMPLATE_DIR}/hooks/PreToolUse" "${hooks_dir}/"
    chmod +x "${hooks_dir}/PreToolUse"
    log_debug "PreToolUse フックを配置: ${hooks_dir}/PreToolUse"
  fi

  log_success "Claude設定を配置しました: ${worker_id}"
}

# Claude Code headlessモードで実行
execute_claude_headless() {
  local worker_dir="$1"
  local prompt_file="$2"
  local worker_id="${3:-unknown}"

  if [[ ! -d "$worker_dir" ]]; then
    log_error "Worker directory not found: ${worker_dir}"
    return 1
  fi

  if [[ ! -f "$prompt_file" ]]; then
    log_error "Prompt file not found: ${prompt_file}"
    return 1
  fi

  # ワーカーディレクトリに移動
  cd "$worker_dir" || return 1

  log_step "Claude Code を実行中: ${worker_id}"

  # ログディレクトリ
  local log_dir="${WORKSPACE_ROOT}/.logs/${worker_id}"
  mkdir -p "$log_dir"

  local log_file="${log_dir}/claude-output.log"
  local error_log="${log_dir}/claude-error.log"

  # Claude Code実行
  "$CLAUDE_COMMAND" \
    --prompt "$(cat "$prompt_file")" \
    --dangerously-skip-permissions \
    --output-format stream-json \
    > "$log_file" 2> "$error_log"

  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    log_success "Claude Code 実行完了: ${worker_id}"
    return 0
  else
    log_error "Claude Code 実行失敗: ${worker_id} (exit code: ${exit_code})"
    log_error "エラーログ: ${error_log}"
    return $exit_code
  fi
}

# Workerプロンプトファイルを生成
generate_worker_prompt() {
  local worker_json="$1"
  local task_file="$2"
  local output_file="$3"

  # Worker情報の抽出
  local worker_id
  worker_id=$(echo "$worker_json" | jq -r '.id')

  local worker_title
  worker_title=$(echo "$worker_json" | jq -r '.title')

  local worker_layer
  worker_layer=$(echo "$worker_json" | jq -r '.layer // "unknown"')

  local target_files
  target_files=$(echo "$worker_json" | jq -r '.targetFiles[]?' 2>/dev/null | sed 's/^/- /' || echo "- TBD")

  local description
  description=$(echo "$worker_json" | jq -r '.description // ""')

  local dependencies
  dependencies=$(echo "$worker_json" | jq -r '.dependencies[]?' 2>/dev/null | sed 's/^/- /' || echo "- なし")

  # Task情報の読み込み
  local task_json
  task_json=$(parse_task_file "$task_file")

  local task_title
  task_title=$(echo "$task_json" | jq -r '.title')

  local task_constraints
  task_constraints=$(echo "$task_json" | jq -r '.constraints')

  local task_references
  task_references=$(echo "$task_json" | jq -r '.references')

  # プロンプト生成
  cat > "$output_file" <<EOF
# Worker ${worker_id}: ${worker_title}

あなたは${worker_layer}層の実装を担当します。

## タスク情報
- Task: ${task_title}
- Worker ID: ${worker_id}
- Title: ${worker_title}
- Layer: ${worker_layer}

## 実装内容
${description}

## 対象ファイル
${target_files}

## 制約条件
- 変更可能なファイル: 上記「対象ファイル」のみ
- 最大変更行数: ${MAX_CHANGED_LINES}行
${task_constraints}

## 依存関係
以下のWorkerが完了していることが前提です：
${dependencies}

## 参考実装
${task_references}

## 実装要件
1. 既存のアーキテクチャパターンに従う
2. TypeScript strict mode で実装
3. ユニットテストを作成
4. コードレビューに耐えうる品質

## 出力
実装完了後、以下を確認してください：
- [ ] TypeScriptコンパイルが通る
- [ ] ユニットテストが全て成功
- [ ] Lintエラーがない
- [ ] 変更行数が ${MAX_CHANGED_LINES}行以内

実装が完了したら、変更内容のサマリーを出力してください。
EOF

  log_debug "Workerプロンプトを生成: ${output_file}"
}

# Claude Code Plan agentを実行
execute_claude_plan() {
  local prompt="$1"

  log_debug "Claude Code Plan agentを実行中..."

  # 一時ファイルにプロンプトを保存
  local temp_prompt
  temp_prompt=$(mktemp)
  echo "$prompt" > "$temp_prompt"

  # Claude Code Plan agentを実行
  local output
  if output=$("$CLAUDE_COMMAND" --agent plan "$(cat "$temp_prompt")" 2>&1); then
    rm -f "$temp_prompt"
    echo "$output"
    return 0
  else
    local exit_code=$?
    rm -f "$temp_prompt"
    log_error "Claude Code Plan agentの実行に失敗しました (exit code: ${exit_code})"
    echo "$output" >&2
    return $exit_code
  fi
}
