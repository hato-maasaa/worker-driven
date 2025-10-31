# Worker-driven Dev CLI - コードベース構造

## プロジェクトツリー

```
worker-driven/
├── bin/                           # 実行可能ファイル
│   └── wkd                        # メインCLIエントリーポイント
│
├── lib/                           # ライブラリスクリプト
│   ├── core/                      # コア機能
│   │   ├── config.sh              # 設定管理（.wkdrc.yaml読み込み）
│   │   ├── logger.sh              # ログ出力（カラー、プログレスバー）
│   │   └── parser.sh              # Markdown/YAMLパーサー
│   │
│   ├── commands/                  # コマンド実装
│   │   ├── init.sh                # 初期化コマンド
│   │   ├── create.sh              # Epic→Task分割
│   │   ├── run.sh                 # Task→Worker実行
│   │   ├── list.sh                # 一覧表示
│   │   ├── stats.sh               # 統計情報
│   │   ├── attach.sh              # tmuxアタッチ
│   │   ├── logs.sh                # ログ表示
│   │   ├── dash.sh                # ダッシュボード（スタブ）
│   │   └── retry.sh               # 再実行（スタブ）
│   │
│   ├── git/                       # Git操作
│   │   └── worktree.sh            # git worktree管理
│   │
│   ├── tmux/                      # tmux操作
│   │   └── manager.sh             # tmuxセッション管理
│   │
│   └── claude/                    # Claude Code連携
│       └── executor.sh            # Claude Code実行、セキュリティ設定
│
├── templates/                     # テンプレートファイル
│   ├── claude/                    # Claude設定テンプレート
│   │   ├── settings.json          # セキュリティ設定（denyパターン）
│   │   └── hooks/
│   │       └── PreToolUse         # 実行前検証フック
│   │
│   └── prompts/                   # プロンプトテンプレート（未実装）
│
├── tasks/                         # タスク管理（gitignore対象）
│   ├── epics/                     # Epic格納（手動作成）
│   │   ├── .gitkeep
│   │   └── *.md                   # Epicファイル
│   │
│   └── <epic-dir>/                # Task格納（AI生成）
│       └── <task-dir>/
│           └── task.md            # Taskファイル
│
├── .workspaces/                   # Worker実行環境（gitignore対象）
│   ├── .workers/                  # Workerメタデータ
│   │   ├── WRK-XXX.json           # Worker情報
│   │   └── WRK-XXX.prompt.md      # Workerプロンプト
│   │
│   └── WRK-XXX/                   # git worktree
│       ├── .claude/               # Claude設定
│       │   ├── settings.json
│       │   └── hooks/PreToolUse
│       └── (プロジェクトコード)
│
├── .wkdrc.yaml                    # プロジェクト設定（gitignore対象）
├── .wkdrc.yaml.example            # 設定テンプレート
├── .gitignore                     # Git除外設定
├── README.md                      # プロジェクト説明
├── DEVELOPMENT.md                 # 開発ログ
├── description.md                 # 仕様書
│
└── test_*.sh                      # テストスクリプト（gitignore対象）
```

## 主要ファイルの役割

### bin/wkd
メインエントリーポイント。コマンドルーティングを行い、適切な `lib/commands/*.sh` を呼び出す。

**主な機能:**
- ヘルプ表示
- バージョン表示
- 設定ファイル読み込み
- コマンドディスパッチ

### lib/core/config.sh
`.wkdrc.yaml` の読み込みと設定管理。

**主な機能:**
- yqまたはsed/grepでYAMLパース
- グローバル変数への設定適用
- 設定の検証

**グローバル変数:**
- `REPO`, `DEFAULT_BRANCH`, `PACKAGE_MANAGER`, `NODE_VERSION`
- `TASKS_DIR`, `TASKS_EPICS_DIR`
- `CLAUDE_COMMAND`, `CLAUDE_HEADLESS_ENABLED`
- `WORKSPACE_ROOT`, `WORKSPACE_STRATEGY`, `BRANCH_PREFIX`
- `MAX_CHANGED_LINES`, `MAX_WORKERS`
- `TMUX_SESSION_NAME`, `TMUX_LAYOUT`

### lib/core/logger.sh
ログ出力ユーティリティ。カラフルなログとプログレスバーを提供。

**主な関数:**
- `log_error()`: エラーメッセージ（赤）
- `log_warn()`: 警告メッセージ（黄）
- `log_info()`: 情報メッセージ（青）
- `log_success()`: 成功メッセージ（緑）
- `log_debug()`: デバッグメッセージ（グレー）
- `log_step()`: ステップメッセージ（シアン）
- `log_section()`: セクション区切り（マゼンタ）
- `spinner()`: スピナー表示
- `progress_bar()`: プログレスバー
- `confirm()`: ユーザー確認プロンプト

### lib/core/parser.sh
Markdown/YAMLパーサー。Epic/Taskファイルの解析を行う。

**主な関数:**
- `extract_frontmatter()`: FrontmatterをJSON形式で抽出
- `extract_title()`: Markdownタイトル抽出
- `parse_epic()`: Epicファイルの解析
- `parse_task()`: Taskファイルの解析

### lib/commands/create.sh
Epic → Task分割コマンド。Claude Code Plan agentを使用。

**主な関数:**
- `create_tasks()`: Epic名からTask生成（CLIエントリーポイント）
- `create_tasks_from_epic()`: Epicファイルから複数のTask生成
- `list_epics()`: Epic一覧表示

**実行フロー:**
1. Epicファイル読み込み
2. Claude Code Plan agent実行
3. 出力をjqでパース
4. Taskディレクトリ作成
5. task.mdファイル生成

### lib/commands/run.sh
Task → Worker → 実装コマンド。並列実行、PR作成を担当。

**主な関数:**
- `run_task()`: Taskディレクトリから全Worker実行
- `run_workers_parallel()`: Worker並列実行
- `create_worker_from_split()`: Claude分割結果からWorkerメタデータ作成
- `execute_worker()`: 個別Worker実行
- `wait_for_workers()`: Worker完了待機

**実行フロー:**
1. Taskファイル読み込み
2. Claude Code Plan agentでWorker分割
3. Workerメタデータ作成（.workspaces/.workers/）
4. tmuxセッション起動
5. 各ペインでWorker実行
6. 完了確認
7. PR作成（オプション）

### lib/git/worktree.sh
git worktree操作。Workerごとの独立した作業環境を管理。

**主な関数:**
- `create_worktree()`: worktree作成
- `remove_worktree()`: worktree削除
- `list_worktrees()`: worktree一覧
- `cleanup_worktrees()`: 不要なworktreeクリーンアップ

### lib/tmux/manager.sh
tmuxセッション管理。Worker並列実行を可視化。

**主な関数:**
- `create_tmux_session()`: セッション作成
- `split_tmux_pane()`: ペイン分割
- `send_keys_to_pane()`: ペインにコマンド送信
- `attach_to_session()`: セッションアタッチ
- `kill_session()`: セッション削除

### lib/claude/executor.sh
Claude Code連携。Plan agentによる分割とheadless実行を担当。

**主な関数:**
- `execute_claude_plan()`: Plan agent実行（Epic/Task分割）
- `execute_claude_headless()`: Headless実行（Worker実装）
- `setup_claude_settings()`: セキュリティ設定（.claude/settings.json）配置
- `generate_worker_prompt()`: Workerプロンプト生成

**セキュリティ機能:**
- デフォルトdenyパターン定義
- プロジェクト設定とのマージ
- PreToolUseフックの配置

## データフロー

### Epic → Task → Worker

```
Epic (tasks/epics/*.md)
  ↓ wkd create tasks
Task (tasks/<epic-dir>/<task-dir>/task.md)
  ↓ wkd run
Worker Metadata (.workspaces/.workers/WRK-XXX.json)
  ↓
Git Worktree (.workspaces/WRK-XXX/)
  ↓
tmux Pane (並列実行)
  ↓
Claude Code Headless (実装)
  ↓
Commit → Push → PR
```

### 設定フロー

```
.wkdrc.yaml
  ↓ load_config()
Global Variables (WORKSPACE_ROOT, CLAUDE_COMMAND, etc.)
  ↓
Commands (create, run, etc.)
  ↓ setup_claude_settings()
.claude/settings.json (各Worker)
  ↓
Claude Code Execution (制限付き)
```

## 依存関係

### 外部コマンド
- **必須**: bash, jq, git, tmux, gh, claude-code
- **推奨**: yq

### ライブラリ間の依存
- `bin/wkd` → すべての `lib/` をロード
- `lib/commands/*` → `lib/core/*` を使用
- `lib/commands/create.sh` → `lib/claude/executor.sh` を使用
- `lib/commands/run.sh` → `lib/git/worktree.sh`, `lib/tmux/manager.sh`, `lib/claude/executor.sh` を使用

## ファイルサイズと行数（参考）

```
bin/wkd: 164行
lib/core/config.sh: 179行
lib/core/logger.sh: 126行
lib/core/parser.sh: ~150行（推定）
lib/commands/create.sh: ~200行（推定）
lib/commands/run.sh: ~300行（推定）
lib/git/worktree.sh: ~150行（推定）
lib/tmux/manager.sh: ~200行（推定）
lib/claude/executor.sh: ~250行（推定）

合計: ~2000行（推定）
```

## 今後の拡張ポイント

### 未実装機能
1. **lib/commands/dash.sh**: リアルタイム進捗ダッシュボード
2. **lib/commands/retry.sh**: Worker再実行ロジック
3. **templates/prompts/**: プロンプトテンプレート管理

### 改善点
1. **lib/core/parser.sh**: Markdownタイトル抽出の改善
2. **lib/commands/run.sh**: Worker完了判定の精緻化
3. **エラーハンドリング**: より詳細なエラーメッセージ
