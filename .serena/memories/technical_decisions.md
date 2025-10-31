# Worker-driven Dev CLI - 技術的決定事項

## 重要な技術的決定

### 1. Bash 3.2互換性

**決定**: macOS デフォルトの Bash 3.2 に対応する

**理由**:
- macOS Catalina以降でもBash 3.2がデフォルト
- ユーザーがHomebrewで新しいBashをインストールする必要がない
- 幅広い環境での動作を保証

**制約**:
- `declare -g` は使用不可（Bash 4.0以降）
- 連想配列は使用不可（Bash 4.0以降）
- 代替として通常の変数とグローバルスコープを使用

**実装例**:
```bash
# NG: Bash 4.0以降
declare -g GLOBAL_VAR="value"

# OK: Bash 3.2互換
GLOBAL_VAR="value"
```

### 2. YAML解析戦略

**決定**: yq優先、sed/grepフォールバック

**理由**:
- yqは強力だが必須にしない
- yqがない環境でも基本的な設定読み込みを可能にする
- 複雑なYAML構造はyqに依存

**実装**:
```bash
if has_yq; then
  load_config_with_yq "$config_file"
else
  load_config_with_sed "$config_file"
fi
```

**制約**:
- sed/grepでは単純な `key: value` 形式のみ対応
- ネストが深い構造やリストはyq必須

### 3. データ管理: ファイルベース

**決定**: データベースではなくファイルシステムを使用

**理由**:
- シンプルで依存が少ない
- デバッグが容易
- Gitで管理可能
- Bashから直接操作可能

**データ構造**:
```
.workspaces/
  .workers/
    WRK-001.json         # Workerメタデータ
    WRK-001.prompt.md    # Workerプロンプト
  WRK-001/               # git worktree
    .success             # 成功マーカー
    .failed              # 失敗マーカー
```

**JSON処理**: jqを使用（必須依存）

### 4. 並列実行: tmux

**決定**: tmuxでWorkerを並列実行

**理由**:
- 視覚的な進捗確認が可能
- 各Workerの出力を独立して確認可能
- セッションのデタッチ/アタッチが可能
- シンプルなAPI

**代替案（不採用）**:
- GNU Parallel: 出力の可視性が低い
- 単純なバックグラウンド実行: 管理が複雑

**実装**:
```bash
# セッション作成
tmux new-session -d -s wkd

# ペイン分割してWorker実行
tmux split-window -t wkd
tmux send-keys -t wkd:0.0 "cd .workspaces/WRK-001 && claude-code ..." C-m

# レイアウト調整
tmux select-layout -t wkd tiled
```

### 5. git worktree による分離

**決定**: 各Workerにgit worktreeを使用

**理由**:
- Workerごとに完全に独立した作業ディレクトリ
- ブランチの切り替えが不要
- 並列実行時のコンフリクトがない
- 完了後の削除が簡単

**ブランチ命名規則**:
```
feat/<task-name>__wrk-<id>
例: feat/workspace-list-api__wrk-001
```

**代替案（不採用）**:
- 単一worktreeでブランチ切り替え: 並列実行不可
- 完全なリポジトリクローン: ディスク容量の無駄

### 6. Claude Code統合

**決定**: Plan agentで分割、Headlessで実装

**理由**:
- Plan agentは構造化された出力を返す
- Headlessモードは自動化に適している
- セキュリティ設定で制限可能

**使い分け**:
- **Plan agent**: Epic→Task、Task→Worker分割
- **Headless mode**: Worker実装

**実装**:
```bash
# Plan agent（分割）
claude-code --agent plan \
  --prompt "$(cat epic.md)" \
  --output-format json

# Headless（実装）
claude-code \
  --prompt "$(cat worker.prompt.md)" \
  --dangerously-skip-permissions \
  --output-format stream-json
```

### 7. セキュリティ: deny パターン

**決定**: `.claude/settings.json` でコマンド制限

**参考**: [wasabeef's blog](https://wasabeef.jp/blog/claude-code-secure-bash)

**アプローチ**:
1. デフォルトdenyパターンをテンプレートで定義
2. プロジェクト固有の設定を `.wkdrc.yaml` で追加
3. 両者をマージして各Workerに配置

**カテゴリ**:
- システム設定変更の禁止 (`git config`, `brew install`)
- 破壊的操作の禁止 (`rm -rf`, `git push --force`)
- 権限昇格の禁止 (`sudo`, `su`)
- 危険なダウンロード実行の禁止 (`curl | bash`)
- 機密ファイルの保護 (`.env`, `.ssh/*`, `*.lock`)

**実装**:
```bash
setup_claude_settings() {
  local worker_dir="$1"
  
  # デフォルトdenyパターン
  local default_deny='[...]'
  
  # プロジェクト固有のdenyパターン
  local custom_deny=$(yq eval '.claude.settings.deny' .wkdrc.yaml -o json)
  
  # マージ
  local merged_deny=$(jq -s '.[0] + .[1]' \
    <(echo "$default_deny") \
    <(echo "$custom_deny"))
  
  # settings.json生成
  jq -n --argjson deny "$merged_deny" \
    '{permissions: {deny: $deny}}' \
    > "${worker_dir}/.claude/settings.json"
}
```

### 8. コミットメッセージ: 日本語

**決定**: コミットメッセージは日本語で記述

**理由**:
- ユーザー要件
- 日本語プロジェクトでの可読性向上
- Claudeは日本語のコミットメッセージを生成可能

**フォーマット**:
```
<type>: <subject>

<body>
```

**例**:
```
feat: コア機能の実装 (create, run, worktree, tmux管理)

- lib/commands/create.sh: Epic→Task分割
- lib/commands/run.sh: Task→Worker実行
- lib/git/worktree.sh: Git worktree管理
- lib/tmux/manager.sh: tmuxセッション管理
```

### 9. テンプレートパス: 相対パス

**決定**: `./templates` を使用

**問題**:
- 初期実装では `../templates` を使用していたが解決に失敗

**解決策**:
- プロジェクトルートからの相対パス `./templates` を使用
- `SCRIPT_DIR` を基準にパスを構築

**実装**:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates"
```

### 10. ログ出力: カラフル + 絵文字

**決定**: カラーコードと絵文字を使用したログ

**理由**:
- 視認性の向上
- エラー/警告/成功の区別が容易
- ターミナル環境での使いやすさ

**実装**:
```bash
log_error()   # ❌ 赤
log_warn()    # ⚠️  黄
log_info()    # ℹ️  青
log_success() # ✓ 緑
log_debug()   # 🔍 グレー
```

**制約**:
- ターミナルがカラー対応していない場合は自動でプレーンテキスト化

## 未解決の技術的課題

### 1. Claude Code実際の統合

**問題**: Claude Code CLIの実際の挙動が仕様と異なる可能性

**対応**:
- 実際にClaude Code CLIをテスト実行
- Plan agentの出力形式を検証
- `--agent plan` オプションの動作確認
- `execute_claude_plan()` の調整が必要か確認

### 2. Worker完了判定

**現状**: 簡易的な判定（commitがあるか）

**改善案**:
- Claude Codeの終了コードを正しく取得
- ログファイルの解析
- `.success` / `.failed` マーカーの活用

### 3. Markdown titleの抽出

**問題**: `lib/core/parser.sh` の `extract_title()` が空文字を返す

**現状**:
- frontmatterの `title` のみ使用

**改善案**:
- Markdown本文の `# Title` 形式の抽出を実装

## 性能上の考慮事項

### 並列数の制限

**設定**: `.wkdrc.yaml` の `parallel.maxWorkers`

**デフォルト**: 8

**理由**:
- CPUコア数に応じた適切な並列数
- tmuxペインの視認性
- Claude Code APIのレート制限

### リソース使用量

**考慮点**:
- 各Workerごとにgit worktreeが作成される（ディスク容量）
- tmuxセッションがメモリを消費
- Claude Code実行がCPUを使用

**最適化**:
- 不要なworktreeの自動クリーンアップ
- 完了したWorkerのペイン閉じる
- ログファイルのローテーション

## 将来の拡張性

### プラグインシステム

**アイデア**: カスタムコマンドの追加

**実装案**:
```
lib/plugins/
  my-custom-command.sh
```

### 通知機能

**アイデア**: Worker完了時にSlack/Email通知

**設定**:
```yaml
notifications:
  slack:
    enabled: true
    webhook: "https://..."
```

### ダッシュボードUI

**アイデア**: Web UIでのリアルタイム進捗監視

**技術**: Node.js + WebSocket / Python + Flask

**現状**: CLI dashboardのみ実装予定
