#!/usr/bin/env bash

# 設定ファイル読み込み

# デフォルト設定
WKD_CONFIG_FILE="${WKD_CONFIG_FILE:-.wkdrc.yaml}"

# グローバル設定変数
REPO=""
DEFAULT_BRANCH="main"
PACKAGE_MANAGER="yarn"
NODE_VERSION="22"

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
# グローバル変数 VALIDATION_ERRORS にエラーメッセージを格納
declare -a VALIDATION_ERRORS=()

validate_config() {
  VALIDATION_ERRORS=()

  # 必須フィールドの確認
  if [[ -z "$REPO" ]]; then
    VALIDATION_ERRORS+=("REPO は必須です")
  fi

  if [[ -z "$DEFAULT_BRANCH" ]]; then
    VALIDATION_ERRORS+=("DEFAULT_BRANCH は必須です")
  fi

  if [[ -z "$TASKS_DIR" ]]; then
    VALIDATION_ERRORS+=("TASKS_DIR は必須です")
  fi

  if [[ -z "$TASKS_EPICS_DIR" ]]; then
    VALIDATION_ERRORS+=("TASKS_EPICS_DIR は必須です")
  fi

  if [[ -z "$WORKSPACE_ROOT" ]]; then
    VALIDATION_ERRORS+=("WORKSPACE_ROOT は必須です")
  fi

  # ディレクトリパス形式の検証（相対パスまたは絶対パス）
  if [[ -n "$TASKS_DIR" ]] && [[ ! "$TASKS_DIR" =~ ^(\./|/|\.\./|~/) ]]; then
    VALIDATION_ERRORS+=("TASKS_DIR は有効なディレクトリパス形式ではありません: ${TASKS_DIR}")
  fi

  if [[ -n "$TASKS_EPICS_DIR" ]] && [[ ! "$TASKS_EPICS_DIR" =~ ^(\./|/|\.\./|~/) ]]; then
    VALIDATION_ERRORS+=("TASKS_EPICS_DIR は有効なディレクトリパス形式ではありません: ${TASKS_EPICS_DIR}")
  fi

  if [[ -n "$WORKSPACE_ROOT" ]] && [[ ! "$WORKSPACE_ROOT" =~ ^(\./|/|\.\./|~/) ]]; then
    VALIDATION_ERRORS+=("WORKSPACE_ROOT は有効なディレクトリパス形式ではありません: ${WORKSPACE_ROOT}")
  fi

  # GitHubリポジトリ形式の検証（owner/repo）
  if [[ -n "$REPO" ]] && [[ ! "$REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$ ]]; then
    VALIDATION_ERRORS+=("REPO は有効なGitHubリポジトリ形式（owner/repo）ではありません: ${REPO}")
  fi

  # エラーがある場合は失敗
  if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
    for error in "${VALIDATION_ERRORS[@]}"; do
      log_error "設定エラー: ${error}"
    done
    return 1
  fi

  # 警告レベルのチェック（必須ディレクトリの存在確認）
  if [[ ! -d "$TASKS_EPICS_DIR" ]]; then
    log_debug "Epic ディレクトリが存在しません: ${TASKS_EPICS_DIR}"
  fi

  # Claude Codeコマンドの確認
  if ! command -v "$CLAUDE_COMMAND" >/dev/null 2>&1; then
    log_debug "Claude Code CLI が見つかりません: ${CLAUDE_COMMAND}"
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
