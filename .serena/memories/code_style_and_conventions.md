# Worker-driven Dev CLI - コードスタイルと規約

## 基本方針

### Bash互換性
- **macOS Bash 3.2互換**: macOSデフォルトのBash 3.2に対応する
- `declare -g` は使用しない（Bash 4.0以降の機能）
- 連想配列は使用しない（Bash 4.0以降の機能）
- `set -euo pipefail` を各スクリプトの先頭に記載

### シェルスクリプト標準
- Shebang: `#!/usr/bin/env bash`
- エラーハンドリング: `set -euo pipefail`
- 関数名: スネークケース (`create_tasks`, `load_config`)
- 変数名: 大文字スネークケース（グローバル変数）、小文字スネークケース（ローカル変数）

## ディレクトリ構造

```
worker-driven/
├── bin/                 # 実行可能ファイル
│   └── wkd             # メインエントリーポイント
├── lib/                # ライブラリスクリプト
│   ├── core/           # コア機能
│   ├── commands/       # コマンド実装
│   ├── git/            # Git操作
│   ├── tmux/           # tmux操作
│   └── claude/         # Claude Code連携
├── templates/          # テンプレートファイル
│   ├── claude/         # Claude設定テンプレート
│   └── prompts/        # プロンプトテンプレート
├── tasks/              # タスク管理
│   └── epics/          # Epic格納
└── .workspaces/        # Worker実行環境
    ├── .workers/       # Workerメタデータ
    └── WRK-XXX/        # git worktree
```

## コーディングスタイル

### ファイル構造
1. Shebang (`#!/usr/bin/env bash`)
2. ファイル概要コメント
3. `set -euo pipefail`
4. 定数定義
5. 関数定義
6. メインロジック（必要な場合）

### 関数定義
```bash
# 関数の説明
function_name() {
  local param1="$1"
  local param2="${2:-default_value}"
  
  # 処理
  
  return 0
}
```

### 変数命名規則
- **グローバル変数**: 大文字スネークケース
  - 例: `WORKSPACE_ROOT`, `CLAUDE_COMMAND`, `MAX_WORKERS`
- **ローカル変数**: 小文字スネークケース
  - 例: `epic_file`, `worker_id`, `task_dir`
- **環境変数**: 大文字スネークケース（既存の慣例に従う）
  - 例: `WKD_CONFIG_FILE`, `LOG_LEVEL`

### ログ出力
- `log_error()`: エラーメッセージ（赤）
- `log_warn()`: 警告メッセージ（黄）
- `log_info()`: 情報メッセージ（青）
- `log_success()`: 成功メッセージ（緑）
- `log_debug()`: デバッグメッセージ（グレー）
- `log_step()`: ステップメッセージ（シアン）
- `log_section()`: セクション区切り（マゼンタ）

### エラーハンドリング
```bash
if [[ ! -f "$file" ]]; then
  log_error "ファイルが見つかりません: ${file}"
  return 1
fi
```

### コマンド存在確認
```bash
if ! command -v jq >/dev/null 2>&1; then
  log_error "jq が見つかりません"
  return 1
fi
```

## ファイル命名規則

### スクリプトファイル
- `*.sh` 拡張子
- スネークケース: `config.sh`, `worktree.sh`, `executor.sh`

### テンプレートファイル
- `.template` または `.example` サフィックス
- 例: `.wkdrc.yaml.example`, `settings.json.template`

## 設定管理

### YAML解析
- yqがあれば使用
- なければsed/grepでフォールバック
- デフォルト値を常に定義

### 設定ファイル
- `.wkdrc.yaml`: プロジェクト設定
- グローバル変数として `lib/core/config.sh` で定義

## セキュリティ

### deny パターン
- `.claude/settings.json` で危険なコマンドを制限
- システム設定変更、破壊的操作、権限昇格、機密ファイルの保護

### PreToolUse フック
- `.claude/hooks/PreToolUse` でコマンド実行前検証
- jq を使用してdenyパターンをチェック

## コミットメッセージ

### フォーマット
```
<type>: <subject>

<body>
```

### タイプ
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: その他

### 言語
- **日本語**でコミットメッセージを記述する（ユーザー要件）

### 例
```
feat: コア機能の実装 (create, run, worktree, tmux管理)

- lib/commands/create.sh: Epic→Task分割
- lib/commands/run.sh: Task→Worker実行
- lib/git/worktree.sh: Git worktree管理
- lib/tmux/manager.sh: tmuxセッション管理
```

## データ管理

### Worker メタデータ
- JSON形式: `.workspaces/.workers/WRK-XXX.json`
- jqで処理

### 状態管理
- ファイルマーカー方式:
  - `.success`: 成功
  - `.failed`: 失敗

## テスト

### テストファイル
- `test_*.sh` 形式
- 各機能のユニットテスト
- 実行可能権限を付与

### 例
```bash
#!/usr/bin/env bash
# test_config.sh

source lib/core/config.sh
source lib/core/logger.sh

# テスト実行
load_config
show_config
```

## コメント

### ファイルヘッダー
```bash
#!/usr/bin/env bash

# ファイル名 - 簡潔な説明
```

### 関数コメント
```bash
# 関数の説明
# 引数1: 説明
# 引数2: 説明（デフォルト値）
# 戻り値: 0=成功, 1=失敗
function_name() {
  # ...
}
```

### インラインコメント
- 複雑なロジックには説明を追加
- 日本語または英語（プロジェクトで統一）
