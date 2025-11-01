#!/usr/bin/env bash

# ログ出力ユーティリティ

# カラー定義
if [[ -t 1 ]]; then
  COLOR_RESET="\033[0m"
  COLOR_RED="\033[31m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  COLOR_BLUE="\033[34m"
  COLOR_MAGENTA="\033[35m"
  COLOR_CYAN="\033[36m"
  COLOR_GRAY="\033[90m"
else
  COLOR_RESET=""
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_MAGENTA=""
  COLOR_CYAN=""
  COLOR_GRAY=""
fi

# ログレベル
LOG_LEVEL="${LOG_LEVEL:-INFO}"
CURRENT_LOG_LEVEL="${CURRENT_LOG_LEVEL:-INFO}"

# ログレベルを数値に変換
get_log_level_value() {
  local level="$1"
  case "$level" in
    ERROR) echo 1 ;;
    WARN) echo 2 ;;
    INFO) echo 3 ;;
    DEBUG) echo 4 ;;
    *) echo 3 ;; # デフォルトはINFO
  esac
}

# ログレベルチェック関数
should_log() {
  local message_level="$1"
  local current_level="${CURRENT_LOG_LEVEL:-INFO}"

  local message_value
  local current_value

  message_value=$(get_log_level_value "$message_level")
  current_value=$(get_log_level_value "$current_level")

  # メッセージレベルが現在のレベル以下なら出力
  [[ $message_value -le $current_value ]]
}

# エラーログ
log_error() {
  if should_log "ERROR"; then
    echo -e "${COLOR_RED}❌ Error:${COLOR_RESET} $*" >&2
  fi
}

# 警告ログ
log_warn() {
  if should_log "WARN"; then
    echo -e "${COLOR_YELLOW}⚠️  Warning:${COLOR_RESET} $*" >&2
  fi
}

# 情報ログ
log_info() {
  if should_log "INFO"; then
    echo -e "${COLOR_BLUE}ℹ️  ${COLOR_RESET}$*"
  fi
}

# 成功ログ
log_success() {
  if should_log "INFO"; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
  fi
}

# デバッグログ
log_debug() {
  if should_log "DEBUG"; then
    echo -e "${COLOR_GRAY}🔍 Debug:${COLOR_RESET} $*" >&2
  fi
}

# ステップログ（進捗表示）
log_step() {
  echo -e "${COLOR_CYAN}▸${COLOR_RESET} $*"
}

# セクション開始
log_section() {
  echo ""
  echo -e "${COLOR_MAGENTA}═══${COLOR_RESET} $* ${COLOR_MAGENTA}═══${COLOR_RESET}"
}

# スピナー表示（バックグラウンドプロセス用）
spinner() {
  local pid=$1
  local message="${2:-処理中}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 10 ))
    printf "\r${COLOR_CYAN}${spin:$i:1}${COLOR_RESET} %s" "$message"
    sleep 0.1
  done

  printf "\r"
}

# プログレスバー表示
progress_bar() {
  local current=$1
  local total=$2
  local width=50
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "\r["
  printf "${COLOR_GREEN}%${filled}s${COLOR_RESET}" | tr ' ' '='
  printf "%${empty}s" | tr ' ' ' '
  printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total"

  if [[ $current -eq $total ]]; then
    echo ""
  fi
}

# 確認プロンプト
confirm() {
  local message="$1"
  local default="${2:-n}"

  if [[ "$default" == "y" ]]; then
    local prompt="${message} (Y/n): "
  else
    local prompt="${message} (y/N): "
  fi

  read -p "$prompt" -r response

  response=${response:-$default}

  case "$response" in
    [yY]|[yY][eE][sS])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
