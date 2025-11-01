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

# ログレベル定義
declare -A LOG_LEVELS=(
  [DEBUG]=0
  [INFO]=1
  [WARN]=2
  [ERROR]=3
)

# 現在のログレベル
CURRENT_LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ログレベルチェック関数
should_log() {
  local level="$1"
  local current_level_value="${LOG_LEVELS[$CURRENT_LOG_LEVEL]:-1}"
  local target_level_value="${LOG_LEVELS[$level]:-1}"

  [[ $current_level_value -le $target_level_value ]]
}

# エラーログ
log_error() {
  echo -e "${COLOR_RED}❌ Error:${COLOR_RESET} $*" >&2
}

# 警告ログ
log_warn() {
  if should_log "WARN"; then
    echo -e "${COLOR_YELLOW}⚠️  Warning:${COLOR_RESET} $*" >&2
  fi
}

# 情報ログ
log_info() {
  echo -e "${COLOR_BLUE}ℹ️  ${COLOR_RESET}$*"
}

# 成功ログ
log_success() {
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

# デバッグログ
log_debug() {
  if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
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
