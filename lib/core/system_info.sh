#!/usr/bin/env bash

# システム情報取得ライブラリ

# OS情報を取得
get_os_info() {
  local os_type=""
  local os_version=""

  case "$(uname -s)" in
    Darwin*)
      os_type="macOS"
      os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
      ;;
    Linux*)
      os_type="Linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        os_version="${PRETTY_NAME:-${NAME:-Unknown}}"
      else
        os_version=$(uname -r)
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      os_type="Windows"
      os_version=$(uname -r)
      ;;
    *)
      os_type=$(uname -s)
      os_version=$(uname -r)
      ;;
  esac

  echo "${os_type} ${os_version}"
}

# Bashバージョンを取得
get_bash_version() {
  echo "${BASH_VERSION}"
}

# システム情報を表示
show_system_info() {
  local os_info
  local bash_version

  os_info=$(get_os_info)
  bash_version=$(get_bash_version)

  cat <<EOF

System Information:
  OS:           ${os_info}
  Bash Version: ${bash_version}
EOF
}
