#!/usr/bin/env bash

# wkd init - プロジェクト初期化コマンド

init_config() {
  log_section "Worker-driven Dev CLI 初期化"

  # 既存の設定ファイルをチェック
  if [[ -f "$WKD_CONFIG_FILE" ]]; then
    log_warn "設定ファイルが既に存在します: ${WKD_CONFIG_FILE}"

    if ! confirm "上書きしますか？" "n"; then
      log_info "初期化をキャンセルしました"
      return 0
    fi
  fi

  # テンプレートから設定ファイルをコピー
  local template_file="${SCRIPT_DIR}/.wkdrc.yaml.example"

  if [[ ! -f "$template_file" ]]; then
    log_error "設定ファイルのテンプレートが見つかりません: ${template_file}"
    return 1
  fi

  log_step "設定ファイルを作成中..."
  cp "$template_file" "$WKD_CONFIG_FILE"
  log_success "設定ファイルを作成しました: ${WKD_CONFIG_FILE}"

  # 必要なディレクトリを作成
  log_step "ディレクトリ構造を作成中..."

  mkdir -p tasks/epics
  mkdir -p .workspaces/.workers

  # .gitkeepを配置
  touch tasks/.gitkeep
  touch tasks/epics/.gitkeep

  log_success "ディレクトリ構造を作成しました"

  # 設定ファイルの編集を促す
  log_section "次のステップ"
  echo "1. 設定ファイルを編集してください:"
  echo "   ${WKD_CONFIG_FILE}"
  echo ""
  echo "2. 以下の項目を設定してください:"
  echo "   - repo: GitHubリポジトリURL"
  echo "   - allowedPaths: 変更を許可するパス"
  echo "   - claude.settings.deny: プロジェクト固有の禁止パターン"
  echo ""
  echo "3. Epicファイルを作成してください:"
  echo "   tasks/epics/your-epic.md"
  echo ""

  log_success "初期化が完了しました！"

  return 0
}
