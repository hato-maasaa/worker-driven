#!/usr/bin/env bash

# 設定ファイル読み込み

# デフォルト設定
WKD_CONFIG_FILE="${WKD_CONFIG_FILE:-.wkdrc.yaml}"

# グローバル設定変数
REPO=""
DEFAULT_BRANCH="main"
PACKAGE_MANAGER="yarn"
NODE_VERSION="22"

CONFIG_GITHUB_TOKEN=""
CONFIG_GITHUB_REPO=""

TASKS_DIR="./tasks"
TASKS_EPICS_DIR="./tasks/epics"

CLAUDE_COMMAND="claude"
CLAUDE_HEADLESS_ENABLED="true"

WORKSPACE_ROOT="./.workspaces"
WORKSPACE_STRATEGY="worktree"
BRANCH_PREFIX="feat"

MAX_CHANGED_LINES="400"
ALLOWED_PATHS=""
DENIED_PATHS=""
SECRETS_SCAN="true"

MAX_WORKERS="8"
TMUX_SESSION_NAME="wkd"
TMUX_LAYOUT="tiled"

# yqが利用可能かチェック
has_yq() {
  command -v yq >/dev/null 2>&1
}

# 設定ファイルの存在確認
check_config_file() {
  if [[ ! -f "$WKD_CONFIG_FILE" ]]; then
    log_error "設定ファイルが見つかりません: ${WKD_CONFIG_FILE}"
    log_info "以下のコマンドで初期化してください:"
    log_info "  wkd init"
    return 1
  fi
  return 0
}

# yqを使用した設定読み込み
load_config_with_yq() {
  local config_file="$1"

  REPO=$(yq eval '.repo' "$config_file" 2>/dev/null || echo "")
  DEFAULT_BRANCH=$(yq eval '.defaultBranch' "$config_file" 2>/dev/null || echo "main")
  PACKAGE_MANAGER=$(yq eval '.packageManager' "$config_file" 2>/dev/null || echo "yarn")
  NODE_VERSION=$(yq eval '.node' "$config_file" 2>/dev/null || echo "22")

  # GitHub設定（環境変数を優先）
  CONFIG_GITHUB_TOKEN="${GITHUB_TOKEN:-$(yq eval '.github.token' "$config_file" 2>/dev/null || echo "")}"
  CONFIG_GITHUB_REPO="${GITHUB_REPO:-$(yq eval '.github.repo' "$config_file" 2>/dev/null || echo "")}"

  TASKS_DIR=$(yq eval '.tasks.directory' "$config_file" 2>/dev/null || echo "./tasks")
  TASKS_EPICS_DIR=$(yq eval '.tasks.epicsDirectory' "$config_file" 2>/dev/null || echo "./tasks/epics")

  CLAUDE_COMMAND=$(yq eval '.claude.command' "$config_file" 2>/dev/null || echo "claude-code")
  CLAUDE_HEADLESS_ENABLED=$(yq eval '.claude.headless.enabled' "$config_file" 2>/dev/null || echo "true")

  WORKSPACE_ROOT=$(yq eval '.workspace.root' "$config_file" 2>/dev/null || echo "./.workspaces")
  WORKSPACE_STRATEGY=$(yq eval '.workspace.strategy' "$config_file" 2>/dev/null || echo "worktree")
  BRANCH_PREFIX=$(yq eval '.workspace.branchPrefix' "$config_file" 2>/dev/null || echo "feat")

  MAX_CHANGED_LINES=$(yq eval '.policies.maxChangedLines' "$config_file" 2>/dev/null || echo "400")
  SECRETS_SCAN=$(yq eval '.policies.secretsScan' "$config_file" 2>/dev/null || echo "true")

  MAX_WORKERS=$(yq eval '.parallel.maxWorkers' "$config_file" 2>/dev/null || echo "8")
  TMUX_SESSION_NAME=$(yq eval '.parallel.tmux.sessionName' "$config_file" 2>/dev/null || echo "wkd")
  TMUX_LAYOUT=$(yq eval '.parallel.tmux.layout' "$config_file" 2>/dev/null || echo "tiled")

  # 配列の読み込み（allowedPaths, deniedPaths）
  ALLOWED_PATHS=$(yq eval '.policies.allowedPaths[]' "$config_file" 2>/dev/null | tr '\n' ',' || echo "")
  DENIED_PATHS=$(yq eval '.policies.deniedPaths[]' "$config_file" 2>/dev/null | tr '\n' ',' || echo "")
}

# sed/grepを使用したフォールバック設定読み込み
load_config_with_sed() {
  local config_file="$1"

  # 簡易的なYAMLパーサー（キー: 値 形式のみ対応）
  REPO=$(grep '^repo:' "$config_file" | cut -d':' -f2- | xargs || echo "")
  DEFAULT_BRANCH=$(grep '^defaultBranch:' "$config_file" | cut -d':' -f2- | xargs || echo "main")
  PACKAGE_MANAGER=$(grep '^packageManager:' "$config_file" | cut -d':' -f2- | xargs || echo "yarn")
  NODE_VERSION=$(grep '^node:' "$config_file" | cut -d':' -f2- | xargs || echo "22")

  # GitHub設定（環境変数を優先）
  local github_token_from_file=$(grep '^\s*token:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "")
  local github_repo_from_file=$(grep '^\s*repo:' "$config_file" | grep -A 10 '^github:' | grep '^\s*repo:' | cut -d':' -f2- | xargs || echo "")
  CONFIG_GITHUB_TOKEN="${GITHUB_TOKEN:-$github_token_from_file}"
  CONFIG_GITHUB_REPO="${GITHUB_REPO:-$github_repo_from_file}"

  TASKS_DIR=$(grep '^\s*directory:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "./tasks")
  TASKS_EPICS_DIR=$(grep '^\s*epicsDirectory:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "./tasks/epics")

  CLAUDE_COMMAND=$(grep '^\s*command:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "claude-code")

  WORKSPACE_ROOT=$(grep '^\s*root:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "./.workspaces")
  BRANCH_PREFIX=$(grep '^\s*branchPrefix:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "feat")

  MAX_CHANGED_LINES=$(grep '^\s*maxChangedLines:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "400")

  MAX_WORKERS=$(grep '^\s*maxWorkers:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "8")
  TMUX_SESSION_NAME=$(grep '^\s*sessionName:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "wkd")
  TMUX_LAYOUT=$(grep '^\s*layout:' "$config_file" | head -1 | cut -d':' -f2- | xargs || echo "tiled")
}

# 設定読み込み（メイン関数）
load_config() {
  local config_file="${1:-$WKD_CONFIG_FILE}"

  # 設定ファイルが存在しない場合はデフォルト設定を使用
  if [[ ! -f "$config_file" ]]; then
    log_debug "設定ファイルが見つかりません。デフォルト設定を使用します: ${config_file}"
    return 0
  fi

  log_debug "設定ファイルを読み込み中: ${config_file}"

  # yqが利用可能な場合は使用、そうでなければフォールバック
  if has_yq; then
    load_config_with_yq "$config_file"
    log_debug "設定を読み込みました（yq使用）"
  else
    log_debug "yqが見つかりません。sed/grepで読み込みます"
    load_config_with_sed "$config_file"
    log_debug "設定を読み込みました（sed/grep使用）"
  fi

  # 設定の検証
  validate_config
}

# 設定の検証
validate_config() {
  VALIDATION_ERRORS=()

  # 必須ディレクトリの確認
  if [[ ! -d "$TASKS_EPICS_DIR" ]]; then
    log_debug "Epic ディレクトリが存在しません: ${TASKS_EPICS_DIR}"
  fi

  # Claude Codeコマンドの確認
  if ! command -v "$CLAUDE_COMMAND" >/dev/null 2>&1; then
    log_debug "Claude Code CLI が見つかりません: ${CLAUDE_COMMAND}"
  fi

  # GitHub Token の検証
  if [[ -n "$CONFIG_GITHUB_TOKEN" ]]; then
    # 形式チェック（ghp_, gho_, ghs_, ghr_, github_pat_ で始まるトークン）
    if [[ ! "$CONFIG_GITHUB_TOKEN" =~ ^(ghp_|gho_|ghs_|ghr_|github_pat_) ]]; then
      VALIDATION_ERRORS+=("GitHub Token の形式が不正です。有効なプレフィックス（ghp_, gho_, ghs_, ghr_, github_pat_）で始まる必要があります。")
    fi

    # 長さチェック（最低40文字）
    if [[ ${#CONFIG_GITHUB_TOKEN} -lt 40 ]]; then
      VALIDATION_ERRORS+=("GitHub Token が短すぎます（最低40文字必要、現在: ${#CONFIG_GITHUB_TOKEN}文字）")
    fi
  fi

  # GitHub Repo の検証
  if [[ -n "$CONFIG_GITHUB_REPO" ]]; then
    # スラッシュの数をカウント
    local slash_count=$(echo "$CONFIG_GITHUB_REPO" | tr -cd '/' | wc -c | xargs)

    # スラッシュが1つだけであることを確認
    if [[ "$slash_count" -ne 1 ]]; then
      VALIDATION_ERRORS+=("GitHub Repo は 'owner/repo' 形式である必要があります（スラッシュは1つのみ）")
    else
      # owner名とrepo名を抽出
      local owner="${CONFIG_GITHUB_REPO%%/*}"
      local repo="${CONFIG_GITHUB_REPO##*/}"

      # owner名が空でないことを確認
      if [[ -z "$owner" ]]; then
        VALIDATION_ERRORS+=("GitHub Repo の owner 名が空です")
      fi

      # repo名が空でないことを確認
      if [[ -z "$repo" ]]; then
        VALIDATION_ERRORS+=("GitHub Repo の repo 名が空です")
      fi
    fi
  fi

  # エラーがある場合は表示
  if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
    log_error "設定の検証エラー:"
    for error in "${VALIDATION_ERRORS[@]}"; do
      log_error "  - $error"
    done
    return 1
  fi

  return 0
}

# 設定の表示（デバッグ用）
show_config() {
  cat <<EOF
=== Worker-driven Dev 設定 ===
Repo: ${REPO}
Default Branch: ${DEFAULT_BRANCH}
Package Manager: ${PACKAGE_MANAGER}
Node: ${NODE_VERSION}

Tasks Directory: ${TASKS_DIR}
Epics Directory: ${TASKS_EPICS_DIR}

Claude Command: ${CLAUDE_COMMAND}
Headless Enabled: ${CLAUDE_HEADLESS_ENABLED}

Workspace Root: ${WORKSPACE_ROOT}
Workspace Strategy: ${WORKSPACE_STRATEGY}
Branch Prefix: ${BRANCH_PREFIX}

Max Changed Lines: ${MAX_CHANGED_LINES}
Secrets Scan: ${SECRETS_SCAN}

Max Workers: ${MAX_WORKERS}
Tmux Session: ${TMUX_SESSION_NAME}
Tmux Layout: ${TMUX_LAYOUT}
================================
EOF
}

# 設定ファイルが存在しない場合にデフォルトで読み込まない
# 各コマンドで必要に応じて load_config を呼ぶ
