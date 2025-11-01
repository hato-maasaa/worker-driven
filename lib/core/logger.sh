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

# ログレベル定数
LOG_LEVEL_ERROR=0
LOG_LEVEL_WARN=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3

# 現在のログレベル（デフォルトはINFO）
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# 互換性のための従来の変数
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# エラーログ
log_error() {
  echo -e "${COLOR_RED}❌ Error:${COLOR_RESET} $*" >&2
}

# 警告ログ
log_warn() {
  echo -e "${COLOR_YELLOW}⚠️  Warning:${COLOR_RESET} $*" >&2
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

# ログレベル文字列を数値に変換
# 引数: ログレベル文字列 (ERROR, WARN, INFO, DEBUG)
# 戻り値: ログレベル数値 (0-3)、無効な場合はLOG_LEVEL_INFO
parse_log_level() {
  local level
  level=$(echo "$1" | tr '[:lower:]' '[:upper:]')  # 大文字に変換

  case "$level" in
    ERROR)
      echo $LOG_LEVEL_ERROR
      ;;
    WARN|WARNING)
      echo $LOG_LEVEL_WARN
      ;;
    INFO)
      echo $LOG_LEVEL_INFO
      ;;
    DEBUG)
      echo $LOG_LEVEL_DEBUG
      ;;
    *)
      echo $LOG_LEVEL_INFO
      ;;
  esac
}

# WKD_LOG_LEVEL環境変数からログレベルを初期化
init_log_level() {
  if [[ -n "${WKD_LOG_LEVEL:-}" ]]; then
    CURRENT_LOG_LEVEL=$(parse_log_level "$WKD_LOG_LEVEL")
  else
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
  fi
}

# logger.shがsourceされた際に自動的にログレベルを初期化
init_log_level
