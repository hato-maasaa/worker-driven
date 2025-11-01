#!/usr/bin/env bash

# システム情報取得ユーティリティ

# OS名とバージョンを取得する
# 戻り値: "OS_NAME OS_VERSION" の形式の文字列
get_os_info() {
    local os_name="Unknown"
    local os_version="Unknown"

    # macOSの場合
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v sw_vers &>/dev/null; then
            os_name=$(sw_vers -productName 2>/dev/null || echo "macOS")
            os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
        else
            os_name="macOS"
        fi
    # Linuxの場合
    elif [[ "$OSTYPE" == "linux"* ]]; then
        if [[ -f /etc/os-release ]]; then
            # /etc/os-releaseから情報を取得
            # shellcheck disable=SC1091
            source /etc/os-release
            os_name="${NAME:-Linux}"
            os_version="${VERSION_ID:-${VERSION:-Unknown}}"
        elif command -v lsb_release &>/dev/null; then
            # lsb_releaseコマンドがある場合
            os_name=$(lsb_release -si 2>/dev/null || echo "Linux")
            os_version=$(lsb_release -sr 2>/dev/null || echo "Unknown")
        else
            os_name="Linux"
        fi
    # その他のUnix系OS
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        os_name="FreeBSD"
        os_version=$(freebsd-version 2>/dev/null || uname -r 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "openbsd"* ]]; then
        os_name="OpenBSD"
        os_version=$(uname -r 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "netbsd"* ]]; then
        os_name="NetBSD"
        os_version=$(uname -r 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "solaris"* ]]; then
        os_name="Solaris"
        os_version=$(uname -r 2>/dev/null || echo "Unknown")
    # その他の場合はunameを試す
    else
        if command -v uname &>/dev/null; then
            os_name=$(uname -s 2>/dev/null || echo "Unknown")
            os_version=$(uname -r 2>/dev/null || echo "Unknown")
        fi
    fi

    echo "${os_name} ${os_version}"
}
