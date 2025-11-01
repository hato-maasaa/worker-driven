#!/usr/bin/env bash

# システム情報を取得するユーティリティ関数

# Bashのバージョン情報を取得
# BASH_VERSION変数を使用してバージョン情報を取得し、フォーマットして返す
#
# 戻り値:
#   Bashのバージョン情報（例: "5.2.15(1)-release"）
get_bash_version() {
    echo "${BASH_VERSION}"
}
