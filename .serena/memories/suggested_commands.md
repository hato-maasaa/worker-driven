# Worker-driven Dev CLI - 推奨コマンド

## システム (macOS Darwin 24.6.0)

### 基本コマンド
```bash
# ファイル操作
ls -la                  # ファイル一覧
cat <file>              # ファイル内容表示
grep <pattern> <file>   # パターン検索
find . -name <pattern>  # ファイル検索
head -n <N> <file>      # 先頭N行表示
tail -n <N> <file>      # 末尾N行表示

# ディレクトリ操作
pwd                     # 現在のディレクトリ
cd <dir>                # ディレクトリ移動
mkdir -p <dir>          # ディレクトリ作成
rm -rf <dir>            # ディレクトリ削除
```

### JSON/YAML処理
```bash
# jq (JSON処理 - 必須)
jq '.' file.json                          # フォーマット
jq '.key' file.json                       # キー取得
jq -r '.permissions.deny[]' settings.json # 配列展開

# yq (YAML処理 - 推奨)
yq eval '.repo' .wkdrc.yaml               # YAML値取得
yq eval '.tasks.directory' .wkdrc.yaml    # ネスト値取得
```

## Git操作

### 基本操作
```bash
git status              # 状態確認
git log --oneline       # コミット履歴
git diff                # 変更差分
git add <file>          # ステージング
git commit -m "message" # コミット
git push                # プッシュ
```

### Worktree操作
```bash
# Worktree作成
git worktree add <path> -b <branch>

# Worktree一覧
git worktree list

# Worktree削除
git worktree remove <path>

# Worktree修復
git worktree prune
```

## tmux操作

### セッション管理
```bash
# セッション作成
tmux new-session -d -s <name>

# セッションアタッチ
tmux attach-session -t <name>

# セッション一覧
tmux list-sessions

# セッション削除
tmux kill-session -t <name>
```

### ペイン操作
```bash
# ペイン分割
tmux split-window -h    # 水平分割
tmux split-window -v    # 垂直分割

# レイアウト変更
tmux select-layout tiled              # タイル
tmux select-layout even-horizontal    # 水平均等
tmux select-layout even-vertical      # 垂直均等
```

### コマンド送信
```bash
# ペインにコマンド送信
tmux send-keys -t <target> "command" C-m
```

## Claude Code CLI

### Plan Agent（タスク分割）
```bash
# Epic → Task分割
claude-code --agent plan \
  --prompt "$(cat epic.md)" \
  --output-format json

# Task → Worker分割
claude-code --agent plan \
  --prompt "$(cat task.md)" \
  --output-format json
```

### Headless実行（Worker実装）
```bash
# Worker実行
cd .workspaces/WRK-001
claude-code \
  --prompt "$(cat ../.workers/WRK-001.prompt.md)" \
  --dangerously-skip-permissions \
  --output-format stream-json
```

## Worker-driven Dev CLI

### 初期化
```bash
# プロジェクト初期化
wkd init
```

### Epic → Task分割
```bash
# Task生成
wkd create tasks <epic-name>
wkd create tasks workspace-onboarding

# 自動承認
wkd create tasks workspace-onboarding --auto-approve
```

### Task → Worker実行
```bash
# Task実行
wkd run <task-dir>
wkd run workspace-management

# 特定Task実行
wkd run workspace-management/workspace-list-api

# 並列実行 + PR自動作成
wkd run workspace-management --parallel --auto-pr
```

### 一覧表示
```bash
wkd list epics                                    # Epic一覧
wkd list tasks                                    # Task一覧
wkd list tasks --epic workspace-onboarding        # Epic別Task一覧
wkd list workers                                  # Worker一覧
```

### 進捗監視
```bash
wkd dash            # ダッシュボード表示
wkd stats           # 統計情報
wkd attach          # tmuxセッションアタッチ
wkd logs <worker-id> # Worker ログ表示
```

### 再実行
```bash
wkd retry --failed                         # 失敗Workerのみ再実行
wkd retry WRK-001 --from-step=typecheck   # 特定Workerを途中から
```

## GitHub CLI

### PR作成
```bash
gh pr create --fill --label worker        # PR作成
gh pr list                                # PR一覧
gh pr view <number>                       # PR詳細
```

### Issue操作
```bash
gh issue list                             # Issue一覧
gh issue view <number>                    # Issue詳細
```

## 開発コマンド

### テスト実行
```bash
# 個別テスト
./test_config.sh
./test_logger.sh
./test_parser.sh

# 全テスト実行（将来的に追加予定）
./test_all.sh
```

### デバッグ
```bash
# デバッグモード有効化
export LOG_LEVEL=DEBUG
wkd <command>

# 設定表示
source lib/core/config.sh
load_config
show_config
```

### 設定確認
```bash
# 依存ツール確認
command -v bash     # Bash
command -v jq       # jq
command -v yq       # yq
command -v tmux     # tmux
command -v git      # Git
command -v gh       # GitHub CLI
command -v claude-code # Claude Code

# バージョン確認
bash --version
jq --version
yq --version
tmux -V
git --version
gh --version
```

## インストール（macOS）

```bash
# Homebrew経由
brew install tmux git jq gh yq

# Claude Code CLI
# （公式ドキュメント参照）

# Worker-driven Dev CLI
git clone git@github.com:hato-maasaa/worker-driven.git
cd worker-driven
export PATH="$(pwd)/bin:$PATH"
```

## トラブルシューティング

### tmuxセッションが残っている
```bash
tmux list-sessions
tmux kill-session -t wkd
```

### git worktreeが残っている
```bash
git worktree list
git worktree remove .workspaces/WRK-001
git worktree prune
```

### 設定ファイルエラー
```bash
# yqがない場合
brew install yq

# 設定ファイル再生成
rm .wkdrc.yaml
wkd init
```

### Claude Code実行エラー
```bash
# セキュリティ設定確認
cat .workspaces/WRK-001/.claude/settings.json

# フック確認
ls -la .workspaces/WRK-001/.claude/hooks/
```
