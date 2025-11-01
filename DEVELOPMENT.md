# Worker-driven Dev CLI - 開発ログ

このファイルは開発コンテキストを保持するためのログです。
PCを再起動しても、このファイルを読めば開発状況を復元できます。

**最終更新**: 2025-10-31

---

## プロジェクト概要

### 目的
Epic → Task → Worker の3階層で開発タスクを自動分割し、Claude Code Plan agentと連携して並列実行する開発ツール。

### 技術スタック
- **実装言語**: Pure Bash (NOT TypeScript/Node.js)
- **アーキテクチャ**: CLI tool (NOT API/NestJS)
- **並列実行**: Git worktree + tmux
- **AI連携**: Claude Code CLI (Plan agent for splitting, headless mode for execution)
- **データ管理**: Filesystem-based (JSON files in `.workspaces/.workers/`)
- **設定管理**: YAML (.wkdrc.yaml) - yqまたはsed/grepでパース
- **セキュリティ**: `.claude/settings.json` with deny patterns + PreToolUse hook

### 重要な技術的決定事項
1. **Bash 3.2互換性**: macOSデフォルトのBash 3.2に対応するため `declare -g` を使用しない
2. **YAML parsing**: yqがあれば使用、なければsed/grepフォールバック
3. **JSON processing**: jqを使用（必須依存）
4. **テンプレートパス**: `./templates/claude` (相対パスの問題を修正済み)
5. **コミットメッセージ**: 日本語で記述する（ユーザー要件）

---

## 現在の実装状態

### ✅ 完了した実装

#### コア機能
1. **bin/wkd** - メインCLIエントリーポイント
   - コマンドルーティング
   - 全ライブラリの自動ロード
   - 設定ファイルの自動読み込み

2. **lib/core/config.sh** - 設定管理
   - `.wkdrc.yaml` の読み込み (yq/sed fallback)
   - グローバル変数の定義
   - Bash 3.2互換性対応済み

3. **lib/core/logger.sh** - ログ出力
   - カラフルなログ出力
   - プログレスバー
   - ユーザー確認プロンプト

4. **lib/core/parser.sh** - Markdown/YAMLパース
   - Epic/TaskファイルのFrontmatter抽出
   - JSON変換
   - タスクMarkdown生成

5. **lib/claude/executor.sh** - Claude Code連携
   - Plan agent実行機能
   - Headlessモード実行
   - セキュリティ設定のセットアップ
   - Workerプロンプト生成

6. **lib/git/worktree.sh** - Git worktree管理
   - Workerごとの独立したworktree作成/削除
   - ブランチ名自動生成 (`feat/task-name__wrk-001`)
   - クリーンアップ機能

7. **lib/tmux/manager.sh** - tmuxセッション管理
   - セッション/ペイン作成
   - レイアウト調整 (tiled/horizontal/vertical)
   - アタッチ/デタッチ
   - 実行状態監視

8. **lib/commands/init.sh** - プロジェクト初期化
   - `.wkdrc.yaml` テンプレートコピー
   - ディレクトリ構造作成

9. **lib/commands/create.sh** - Epic→Task分割
   - Claude Plan agentでEpic分割
   - タスクファイル自動生成
   - Epic/Task一覧表示

10. **lib/commands/run.sh** - Task→Worker実行
    - Claude Plan agentでTask分割
    - Git worktree + tmuxセットアップ
    - Worker並列実行
    - ステータス管理
    - PR自動作成

#### 補助コマンド
11. **lib/commands/list.sh** - 一覧表示
12. **lib/commands/stats.sh** - 統計情報
13. **lib/commands/attach.sh** - tmuxアタッチ
14. **lib/commands/logs.sh** - ログ表示
15. **lib/commands/dash.sh** - ダッシュボード（スタブ）
16. **lib/commands/retry.sh** - 再実行（スタブ）

#### セキュリティ設定
17. **templates/claude/settings.json** - デフォルトdenyパターン
18. **templates/claude/hooks/PreToolUse** - 実行前検証フック

#### 設定ファイル
19. **.wkdrc.yaml.example** - 設定テンプレート
20. **.gitignore** - 適切な除外設定

#### ドキュメント
21. **description.md** - 仕様書（492行、Bash実装版）
22. **README.md** - プロジェクト説明

---

## ファイル構成

```
worker-driven/
├── bin/
│   └── wkd                          # メインCLI (実行可能)
├── lib/
│   ├── core/
│   │   ├── config.sh                # 設定管理
│   │   ├── logger.sh                # ログ出力
│   │   └── parser.sh                # Markdown/YAMLパース
│   ├── claude/
│   │   └── executor.sh              # Claude Code連携
│   ├── git/
│   │   └── worktree.sh              # Git worktree管理
│   ├── tmux/
│   │   └── manager.sh               # tmuxセッション管理
│   └── commands/
│       ├── init.sh                  # 初期化コマンド
│       ├── create.sh                # Epic→Task分割
│       ├── run.sh                   # Task→Worker実行
│       ├── list.sh                  # 一覧表示
│       ├── stats.sh                 # 統計情報
│       ├── attach.sh                # tmuxアタッチ
│       ├── logs.sh                  # ログ表示
│       ├── dash.sh                  # ダッシュボード（スタブ）
│       └── retry.sh                 # 再実行（スタブ）
├── templates/
│   └── claude/
│       ├── settings.json            # セキュリティ設定
│       └── hooks/
│           └── PreToolUse           # 実行前フック
├── tasks/
│   ├── epics/                       # Epicファイル格納
│   │   └── .gitkeep
│   └── .gitkeep
├── .workspaces/                     # Git worktreeとWorkerメタデータ
│   └── .workers/                    # Workerメタデータ (JSON)
├── .wkdrc.yaml.example              # 設定テンプレート
├── .gitignore
├── description.md                   # 仕様書
├── description.old.md               # 旧仕様書（バックアップ）
└── README.md
```

---

## 使用方法

### 1. 初期化

```bash
./bin/wkd init
```

- `.wkdrc.yaml` を作成
- `tasks/epics/` ディレクトリを作成
- `.workspaces/.workers/` ディレクトリを作成

### 2. Epicファイルの作成

`tasks/epics/your-epic.md` を手動作成:

```markdown
---
id: EPIC-001
title: ユーザー認証機能の実装
description: JWTベースの認証システムを構築する
---

# Epic: ユーザー認証機能の実装

## 背景
現在、認証機能がないため、ユーザー管理ができない。

## 目標
- ユーザー登録/ログイン機能
- JWT トークン発行
- 認証ミドルウェア

## 受け入れ基準
- [ ] ユーザー登録API
- [ ] ログインAPI
- [ ] 認証ミドルウェア
- [ ] テストカバレッジ80%以上
```

### 3. Epic → Task 分割

```bash
./bin/wkd create tasks your-epic
```

- Claude Code Plan agentがEpicを分析
- 複数のTaskファイルを自動生成 (`tasks/EPIC-001/TASK-001.md`, `TASK-002.md`, ...)

### 4. Task → Worker 実行

```bash
./bin/wkd run tasks/EPIC-001/TASK-001.md
```

実行フロー:
1. Claude Plan agentがTaskをWorkerに分割
2. 各Workerごとにgit worktreeを作成
3. tmuxセッションでペインを分割
4. 各ペインでClaude Code headless実行
5. 完了後、PR作成オプション

### 5. 進捗確認

```bash
# 統計情報
./bin/wkd stats

# Worker一覧
./bin/wkd list workers

# tmuxセッションにアタッチ
./bin/wkd attach
```

---

## コマンド一覧

| コマンド | 説明 | ステータス |
|---------|------|-----------|
| `wkd init` | プロジェクト初期化 | ✅ 完了 |
| `wkd create tasks <epic-name>` | Epic→Task分割 | ✅ 完了 |
| `wkd run <task-file>` | Task→Worker実行 | ✅ 完了 |
| `wkd list [epics\|tasks\|workers]` | 一覧表示 | ✅ 完了 |
| `wkd stats` | 統計情報 | ✅ 完了 |
| `wkd attach` | tmuxアタッチ | ✅ 完了 |
| `wkd logs <worker-id>` | ログ表示 | ✅ 完了 |
| `wkd dash` | ダッシュボード | ⚠️ スタブ |
| `wkd retry [--failed\|worker-id]` | 再実行 | ⚠️ スタブ |

---

## 既知の問題と制限事項

### 未実装機能
1. **ダッシュボード機能** (`lib/commands/dash.sh`)
   - リアルタイム進捗表示
   - watch コマンドとの統合

2. **Worker再実行機能** (`lib/commands/retry.sh`)
   - 失敗したWorkerの再実行ロジック
   - 依存関係の考慮

3. **Claude Code実際の統合**
   - Claude Code CLIの実際のコマンド形式が仕様と異なる可能性
   - `--agent plan` オプションの実際の挙動を確認する必要あり
   - Plan agentの出力形式の検証

### 技術的制約
1. **Bash 3.2互換性**
   - macOSのデフォルトBashでは一部の機能が制限される
   - 連想配列が使えない（Bash 4.0以降の機能）

2. **依存ツール**
   - `jq`: 必須（JSON処理）
   - `yq`: 推奨（YAML処理、なくてもsed/grepで動作）
   - `tmux`: Worker並列実行に必須
   - `gh`: PR自動作成に必要（オプション）
   - `claude`: AI連携に必須

3. **Markdown titleの抽出**
   - `lib/core/parser.sh` の `extract_title()` が空文字を返す
   - 現状は frontmatter の title のみ使用
   - Markdown本文の `# Title` 形式の抽出が未完成

---

## 修正済みの問題

### 1. declare -g 非互換性
**問題**: macOS Bash 3.2で `declare -g` が使えない
**修正**: lib/core/config.sh から `-g` フラグを削除
**コミット**: fb1113e

### 2. テンプレートパスの問題
**問題**: TEMPLATE_DIR が `../templates` で解決に失敗
**修正**: `./templates` に変更
**コミット**: fb1113e

### 3. 仕様書の不一致
**問題**: description.md がTypeScript/API仕様になっていた
**修正**: 全面書き直し（2,835行 → 492行、Bash実装版）
**コミット**: 初期コミット

---

## Git履歴

```bash
# 最新コミット
b42d1fe - feat: コア機能の実装 (create, run, worktree, tmux管理) (2025-10-31)
fb1113e - feat: Worker-driven Dev CLI の初期実装 (2025-10-31)

# リモートリポジトリ
git@github.com:hato-maasaa/worker-driven.git
ブランチ: main
```

---

## 開発の経緯

### フェーズ1: 仕様策定 (メッセージ 1-10)
- TypeScript/NestJSからBash/CLI実装に方針転換
- description.md を大幅にリライト（83%削減）
- 全コード例をBashに変換

### フェーズ2: セキュリティ設計 (メッセージ 11-13)
- wasabeefのブログを参考にdenyパターン実装
- `.claude/settings.json` と PreToolUse hook の設計
- テンプレートシステムの構築

### フェーズ3: 初期実装 (メッセージ 14-20)
- コアライブラリの実装 (config, logger, parser, executor)
- メインCLI (bin/wkd) の実装
- テンプレートファイルの作成

### フェーズ4: テストと修正 (メッセージ 21-27)
- `declare -g` 問題の発見と修正
- TEMPLATE_DIR パス問題の修正
- 全機能のテスト実行と検証

### フェーズ5: Gitセットアップ (メッセージ 28-32)
- .gitignore 作成
- 初期コミット（日本語メッセージ）
- GitHubへpush

### フェーズ6: 機能完成 (メッセージ 33-現在)
- 残りのコマンド実装 (create, run, list, stats, etc.)
- Git worktree管理
- tmuxセッション管理
- Claude Plan agent連携
- コミットとpush (b42d1fe)

---

## 次のステップ

### 優先度: 高
1. **Claude Code CLIの動作確認**
   - `claude --agent plan` コマンドの実際の動作を確認
   - Plan agentの出力形式を検証
   - execute_claude_plan() の調整が必要か確認

2. **実際のEpicでのテスト**
   - サンプルEpicを作成
   - create → run の一連の流れを実行
   - 問題があれば修正

3. **エラーハンドリング強化**
   - Claude Code実行失敗時の処理
   - JSON parse エラーの詳細表示
   - ユーザーフレンドリーなエラーメッセージ

### 優先度: 中
4. **dash コマンドの実装**
   - リアルタイム進捗表示
   - watch コマンドとの統合
   - tmuxペインの状態監視

5. **retry コマンドの完成**
   - 失敗したWorkerの再実行
   - 依存関係を考慮した再実行順序

6. **Worker完了判定の改善**
   - 現在は簡易的な判定（commitがあるか）
   - Claude Code の終了コードを正しく取得
   - ログファイルの解析

### 優先度: 低
7. **パフォーマンス最適化**
   - 並列数の制御
   - リソース使用量の監視

8. **ドキュメント充実**
   - ユーザーガイドの作成
   - トラブルシューティングガイド
   - アーキテクチャ図

---

## 設定ファイル例

### .wkdrc.yaml

```yaml
# リポジトリ情報
repo: git@github.com:yourorg/yourproject.git
defaultBranch: main
branchPrefix: feat

# Claude Code設定
claude:
  command: claude
  settings:
    deny:
      # プロジェクト固有の禁止パターン
      - "Bash(firebase deploy *)"
      - "Bash(npm publish *)"

# ポリシー
policies:
  maxChangedLines: 400
  maxWorkers: 5
  allowedPaths:
    - frontend/**
    - backend/**
    - shared/**

# ワークスペース
workspace:
  root: ./.workspaces
  tmuxLayout: tiled  # tiled, even-horizontal, even-vertical

# 通知
notifications:
  slack:
    enabled: false
    webhook: ""
```

---

## トラブルシューティング

### tmuxが起動しない
```bash
# tmuxのインストール確認
which tmux

# macOS
brew install tmux

# Ubuntu
sudo apt install tmux
```

### yqがなくて設定が読めない
yqがなくても基本的な設定は読み込めますが、複雑なYAMLは対応できません。
```bash
# yqのインストール（推奨）
brew install yq
```

### Claude Code が見つからない
```bash
# Claude Code CLIのインストール
# （実際のインストール方法は公式ドキュメント参照）

# パスを指定する場合
# .wkdrc.yaml に記載
claude:
  command: /path/to/claude
```

### Workerが実行されない
1. tmuxセッションを確認: `tmux list-sessions`
2. セッションにアタッチ: `./bin/wkd attach`
3. ログを確認: `./bin/wkd logs <worker-id>`

---

## 参考情報

### 参考にしたブログ
- wasabeef: Claude Code セキュリティ設定
  https://wasabeef.jp/blog/claude-secure-bash

### Git worktree ドキュメント
```bash
git worktree --help
```

### tmux チートシート
- Ctrl-b d: デタッチ
- Ctrl-b o: ペイン切替
- Ctrl-b [: スクロールモード
- Ctrl-b ": 水平分割
- Ctrl-b %: 垂直分割

---

## 開発環境

```bash
# macOS情報
Darwin 24.6.0

# Bashバージョン
bash --version
# GNU bash, version 3.2.57(1)-release (arm64-apple-darwin24)

# 必須ツール
jq --version       # jq-1.6 (例)
yq --version       # yq (https://github.com/mikefarah/yq/) version 4.x
tmux -V            # tmux 3.x
git --version      # git version 2.x
```

---

## まとめ

現時点で Worker-driven Dev CLI の最低限の機能は実装完了しています。
実際にClaude Code CLIとの統合をテストし、動作確認を行う段階に入りました。

**このファイルを定期的に更新することで、開発コンテキストを維持できます。**
