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

# ログレベル文字列を数値に変換
# 引数: ログレベル文字列（ERROR/WARN/INFO/DEBUG、大文字小文字を区別しない）
# 戻り値: 対応する数値（0-3）を標準出力に出力
#   ERROR → 0, WARN → 1, INFO → 2, DEBUG → 3
#   無効な入力の場合はデフォルトでINFO（2）を返す
parse_log_level() {
  local level="${1:-INFO}"
  # 大文字に正規化
  level=$(echo "$level" | tr '[:lower:]' '[:upper:]')

  case "$level" in
    ERROR)
      echo "0"
      ;;
    WARN|WARNING)
      echo "1"
      ;;
    INFO)
      echo "2"
      ;;
    DEBUG)
      echo "3"
      ;;
    *)
      # 無効な入力の場合はデフォルトでINFO（2）
      echo "2"
      ;;
  esac
}

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
