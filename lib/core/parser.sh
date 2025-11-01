#!/usr/bin/env bash

# Markdown/YAMLパーサー

# YAMLフロントマターを抽出
extract_frontmatter() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "{}"
    return 1
  fi

  # ---で囲まれた部分を抽出
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

# Markdown本文を抽出（フロントマター以降）
extract_markdown_body() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # 最初の---以降、2番目の---以降を出力
  sed '1,/^---$/d' "$file" | sed '1,/^---$/d'
}

# フロントマターから値を取得
get_frontmatter_value() {
  local frontmatter="$1"
  local key="$2"

  echo "$frontmatter" | grep "^${key}:" | cut -d':' -f2- | xargs
}

# Markdownセクションを抽出
extract_section() {
  local markdown="$1"
  local section_name="$2"

  # セクション開始から次のセクション（または終端）まで
  echo "$markdown" | sed -n "/^## ${section_name}/,/^##/p" | sed '1d;$d'
}

# Markdownリスト項目を抽出
extract_list_items() {
  local markdown="$1"

  echo "$markdown" | grep '^- ' | sed 's/^- //'
}

# Epic ファイルをパース
parse_epic_file() {
  local epic_file="$1"

  if [[ ! -f "$epic_file" ]]; then
    log_error "Epic file not found: ${epic_file}"
    return 1
  fi

  # ファイル名からepic名を取得（デフォルト値として使用）
  local filename
  filename=$(basename "$epic_file" .md)

  # Frontmatterを試す（なくてもOK）
  local frontmatter
  frontmatter=$(extract_frontmatter "$epic_file")

  # Markdown本文を取得
  local markdown
  markdown=$(extract_markdown_body "$epic_file")

  # Frontmatterがない場合、ファイル全体をmarkdownとして扱う
  if [[ -z "$markdown" ]] || [[ $(echo "$markdown" | wc -l) -lt 2 ]]; then
    markdown=$(cat "$epic_file")
  fi

  # 主要な値を抽出（Frontmatterがあれば使用、なければデフォルト）
  local epic_name
  epic_name=$(get_frontmatter_value "$frontmatter" "epic")
  if [[ -z "$epic_name" ]]; then
    epic_name="$filename"
  fi

  local priority
  priority=$(get_frontmatter_value "$frontmatter" "priority")

  local estimated
  estimated=$(get_frontmatter_value "$frontmatter" "estimated")

  # Markdownセクションを抽出
  local title
  title=$(echo "$markdown" | grep -m1 '^# ' | sed 's/^# //')
  if [[ -z "$title" ]]; then
    title="$filename"
  fi

  # セクションを抽出（存在すれば使用、なければ本文全体を説明として使用）
  local description
  description=$(extract_section "$markdown" "概要")
  if [[ -z "$description" ]]; then
    description=$(extract_section "$markdown" "問題")
  fi
  if [[ -z "$description" ]]; then
    # セクションがない場合、本文全体を使用
    description="$markdown"
  fi

  local acceptance_criteria
  acceptance_criteria=$(extract_section "$markdown" "受け入れ条件")
  if [[ -z "$acceptance_criteria" ]]; then
    acceptance_criteria=$(extract_section "$markdown" "修正依頼")
  fi

  local references
  references=$(extract_section "$markdown" "参考実装")

  # JSON形式で出力
  cat <<EOF
{
  "epic": "${epic_name}",
  "title": "${title}",
  "priority": "${priority:-medium}",
  "estimated": "${estimated}",
  "description": $(echo "$description" | jq -Rs .),
  "acceptanceCriteria": $(echo "$acceptance_criteria" | jq -Rs .),
  "references": $(echo "$references" | jq -Rs .)
}
EOF
}

# Task ファイルをパース
parse_task_file() {
  local task_file="$1"

  if [[ ! -f "$task_file" ]]; then
    log_error "Task file not found: ${task_file}"
    return 1
  fi

  local frontmatter
  frontmatter=$(extract_frontmatter "$task_file")

  local markdown
  markdown=$(extract_markdown_body "$task_file")

  # 主要な値を抽出
  local task_name
  task_name=$(get_frontmatter_value "$frontmatter" "task")

  local epic
  epic=$(get_frontmatter_value "$frontmatter" "epic")

  local priority
  priority=$(get_frontmatter_value "$frontmatter" "priority")

  # scopeは配列なので特別処理
  local scope
  scope=$(echo "$frontmatter" | sed -n '/^scope:/,/^[a-z]*:/p' | grep '^\s*-' | sed 's/^\s*- //' | jq -R . | jq -s .)

  # Markdownセクションを抽出
  local title
  title=$(echo "$markdown" | grep -m1 '^# ' | sed 's/^# //')

  local description
  description=$(extract_section "$markdown" "概要")

  local requirements
  requirements=$(extract_section "$markdown" "要件")

  local constraints
  constraints=$(extract_section "$markdown" "制約")

  local references
  references=$(extract_section "$markdown" "参考実装")

  # JSON形式で出力
  cat <<EOF
{
  "task": "${task_name}",
  "epic": "${epic}",
  "title": "${title}",
  "priority": "${priority:-medium}",
  "scope": ${scope},
  "description": $(echo "$description" | jq -Rs .),
  "requirements": $(echo "$requirements" | jq -Rs .),
  "constraints": $(echo "$constraints" | jq -Rs .),
  "references": $(echo "$references" | jq -Rs .)
}
EOF
}

# JSON から Markdown タスクファイルを生成
generate_task_markdown() {
  local task_json="$1"
  local epic_file="$2"

  # Task情報の抽出
  local task_dir
  task_dir=$(echo "$task_json" | jq -r '.directory')

  local task_title
  task_title=$(echo "$task_json" | jq -r '.title')

  local task_description
  task_description=$(echo "$task_json" | jq -r '.description')

  local task_priority
  task_priority=$(echo "$task_json" | jq -r '.priority // "medium"')

  # Epic情報の抽出
  local epic_frontmatter
  epic_frontmatter=$(extract_frontmatter "$epic_file")

  local epic_name
  epic_name=$(get_frontmatter_value "$epic_frontmatter" "epic")

  # task.md の生成
  cat <<EOF
---
task: ${task_dir}
epic: ${epic_name}
priority: ${task_priority}
scope:
$(echo "$task_json" | jq -r '.scope[]?' 2>/dev/null | sed 's/^/  - /' || echo "  - backend")
---

# ${task_title}

## 概要
${task_description}

## 要件
$(echo "$task_json" | jq -r '.requirements[]?' 2>/dev/null | sed 's/^/- /' || echo "- TBD")

## 制約
- レイヤードアーキテクチャに従う
- ユニットテストカバレッジ 80%以上
- TypeScript strict mode 準拠

## 参考実装
$(extract_section "$(extract_markdown_body "$epic_file")" "参考実装" | grep '^-' || echo "- TBD")

## 期待される成果物
- Domain 型定義
- Repository 実装
- UseCase 実装
- Controller 実装
- ユニットテスト
- E2E テスト

## 備考
この Task は wkd run で自動的に Worker に分割され、
各 Worker が独立した PR として作成されます。
EOF
}
