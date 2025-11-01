# Worker-driven Dev CLI 仕様書

**CLI主体でタスクを極小単位（Worker）に自動分割し、tmux + git worktree で並列実行する開発ツール**

## 1. 概要

### 目的
仕様書（Epic）から実装完了（PR作成）まで、以下を自動化：
- Epic → Task → Worker への自動分割（Claude Code Plan agent使用）
- 各Workerごとに独立した作業環境（git worktree + tmux）を自動生成
- 並列実装・テスト・PR作成

### 特徴
- **完全にBashシェルスクリプトで実装**
- CLI操作のみ（キーボードのみで完結）
- tmuxで並列作業を可視化
- git worktreeで各Workerを完全に分離

---

## 2. 用語

| 用語 | 説明 |
|------|------|
| **Epic** | 大きなテーマ（手動で作成） |
| **Task** | Epicを機能粒度に分割した単位（AIが自動生成） |
| **Worker** | 実行最小単位（1目的 = 1ブランチ = 1 worktree = 1 PR） |
| **Workspace** | git worktreeで作るWorker用の作業ディレクトリ |

---

## 3. インストール要件

```bash
# 必須ツール
- Bash ≥ 5.0
- tmux ≥ 3.x
- git ≥ 2.35 (git worktree対応)
- jq (JSON処理)
- gh CLI (GitHub操作)
- yq (YAML処理、オプション)
- Claude Code CLI (claude コマンド)

# インストール例（macOS）
brew install tmux git jq gh yq
```

---

## 4. プロジェクト構造

```
worker-driven/
├── bin/
│   └── wkd                    # メインエントリーポイント
├── lib/
│   ├── core/
│   │   ├── config.sh          # 設定読み込み (.wkdrc.yaml)
│   │   ├── logger.sh          # ログ出力
│   │   ├── parser.sh          # Markdown/YAMLパーサー
│   │   ├── prompts.sh         # プロンプト生成
│   │   └── validate.sh        # バリデーション
│   ├── commands/
│   │   ├── create.sh          # wkd create tasks
│   │   ├── run.sh             # wkd run
│   │   ├── dash.sh            # wkd dash (ダッシュボード)
│   │   ├── list.sh            # wkd list
│   │   ├── attach.sh          # wkd attach
│   │   ├── logs.sh            # wkd logs
│   │   └── retry.sh           # wkd retry
│   ├── tmux/
│   │   └── manager.sh         # tmux操作
│   ├── git/
│   │   └── worktree.sh        # git worktree操作
│   └── claude/
│       └── executor.sh        # Claude Code CLI実行
├── templates/
│   ├── .wkdrc.yaml.template   # 設定ファイルテンプレート
│   ├── claude/
│   │   ├── settings.json      # Claude設定テンプレート
│   │   └── hooks/
│   │       └── PreToolUse     # deny-checkフック
│   └── prompts/
│       ├── epic-split.md      # Epic→Task分割用
│       └── task-split.md      # Task→Worker分割用
├── .wkdrc.yaml                # プロジェクト設定
└── README.md
```

---

## 5. 設定ファイル (.wkdrc.yaml)

```yaml
# リポジトリ情報
repo: github.com/yourorg/your-repo
defaultBranch: main
packageManager: yarn
node: 22

# タスク管理
tasks:
  source: filesystem
  directory: ./tasks
  epicsDirectory: ./tasks/epics
  format: markdown

# Claude Code設定
claude:
  command: claude
  headless:
    enabled: true
    flags:
      - "--dangerously-skip-permissions"
      - "--output-format stream-json"

  # セキュリティ設定（各Workerの.claude/settings.jsonに適用）
  settings:
    deny:
      # プロジェクト固有の追加禁止パターン
      - "Bash(firebase deploy *)"
      - "Bash(vercel deploy *)"
      - "Write(**/config/database.yml)"
      - "Edit(**/config/secrets.yaml)"

# Workspace設定
workspace:
  root: ./.workspaces
  strategy: worktree
  branchPrefix: feat

# ポリシー
policies:
  maxChangedLines: 400
  allowedPaths:
    - frontend/**
    - be-api/**
  deniedPaths:
    - "**/.env*"
    - "**/*.lock"
    - "**/node_modules/**"
  secretsScan: true

# 並列実行設定
parallel:
  maxWorkers: 8
  tmux:
    sessionName: wkd
    layout: tiled

# 実行ステップ
steps:
  - kind: setup
    cmd: corepack enable && yarn --immutable
  - kind: generate
    tool: claude
  - kind: typecheck
    cmd: yarn typecheck
  - kind: test
    cmd: yarn test --run
  - kind: lint
    cmd: yarn lint --fix
  - kind: commit
    cmd: git add -A && git commit -m "feat: {{title}} [{{id}}]"
  - kind: push
    cmd: git push --set-upstream origin HEAD
  - kind: open_pr
    cmd: gh pr create --fill --label worker
```

---

## 6. タスク管理（3階層構造）

### ディレクトリ構造

```
tasks/
├── epics/                          # Epic格納（手動作成）
│   ├── workspace-onboarding.md
│   └── user-authentication.md
│
├── workspace-management/           # ← AIが生成（Epic親ディレクトリ）
│   ├── workspace-list-api/         # ← AIが生成（Task）
│   │   └── task.md
│   ├── workspace-create-api/
│   │   └── task.md
│   └── workspace-delete-api/
│       └── task.md
│
└── .workspaces/                    # Worker実行環境
    ├── .workers/                   # Workerメタデータ
    │   ├── WRK-001.json
    │   └── WRK-001.prompt.md
    └── WRK-001/                    # git worktree
        └── (プロジェクトコード)
```

### Epic ファイル形式

```markdown
---
epic: workspace-onboarding
priority: high
estimated: 2-3 weeks
---

# Workspace Onboarding Epic

## 概要
ワークスペース管理機能の実装

## 受け入れ条件
- ワークスペース一覧取得API
- ワークスペース作成API
- ワークスペース削除API

## 参考実装
- Organization API (/be-api/src/domain/organization/)
```

### Task ファイル形式

```markdown
---
task: workspace-list-api
epic: workspace-onboarding
priority: high
scope:
  - be-api/src/domain/workspace
  - be-api/src/usecase/workspace
  - be-api/src/controller/workspace
---

# 所属ワークスペース一覧API

## 概要
ユーザーが所属するワークスペースの一覧を取得するAPI

## 要件
- ユーザーIDから所属ワークスペースを取得
- ワークスペース情報（ID, 名前, 作成日）を返す
- ページネーション対応

## 制約
- レイヤードアーキテクチャに従う
- ユニットテストカバレッジ 80%以上
```

---

## 7. 主要コマンド

### 7.1 Epic → Task 分割

```bash
# Epicを複数のTaskに分割（AIが自動生成）
wkd create tasks workspace-onboarding

# オプション
wkd create tasks workspace-onboarding \
  --auto-approve \        # 自動承認
  --max-tasks 7           # 最大Task数
```

**実行内容：**
1. `tasks/epics/workspace-onboarding.md` を読み込み
2. Claude Code Plan agentでTask分割
3. `tasks/workspace-management/` 配下にTask作成

### 7.2 Task → Worker → 実装

```bash
# Task配下の全Worker実行
wkd run workspace-management

# 特定のTaskのみ実行
wkd run workspace-management/workspace-list-api

# オプション
wkd run workspace-management \
  --parallel \            # Task並列実行
  --auto-pr \             # PR自動作成
  --watch                 # 進捗リアルタイム監視
```

**実行内容：**
1. task.mdを読み込み
2. Claude Code Plan agentでWorkerに分割
3. 各Workerにgit worktree作成
4. tmuxで並列起動
5. Claude Code headlessで実装
6. テスト → commit → push → PR作成

### 7.3 その他のコマンド

```bash
# ダッシュボード表示（リアルタイム監視）
wkd dash

# 一覧表示
wkd list epics
wkd list tasks
wkd list tasks --epic workspace-onboarding
wkd list workers

# tmuxセッションにアタッチ
wkd attach

# ログ表示
wkd logs WRK-001

# リトライ
wkd retry --failed                         # 失敗したWorkerのみ
wkd retry WRK-001 --from-step=typecheck   # 特定Workerを途中から

# 統計情報
wkd stats
```

---

## 8. 実行フロー

### Phase 1: Epic作成（手動）

```bash
# Epic ファイルを作成
mkdir -p tasks/epics
cat > tasks/epics/workspace-onboarding.md <<'EOF'
---
epic: workspace-onboarding
priority: high
---
# Workspace Onboarding Epic
...
EOF
```

### Phase 2: Epic → Task分割（AI自動、2-5分）

```bash
wkd create tasks workspace-onboarding
```

**内部処理：**
1. Epic読み込み
2. コードベース探索（参考実装検出）
3. Claude Code Plan agentで分割
4. `tasks/workspace-management/` 配下にTask作成

### Phase 3: Task → Worker → 実装（AI自動、30-60分）

```bash
wkd run workspace-management --parallel --auto-pr
```

**内部処理：**
1. 全Task読み込み
2. 各TaskをClaude Code Plan agentでWorkerに分割
3. 各Workerに git worktree作成
4. tmux並列セッション起動
5. Claude Code headlessで実装
6. テスト → commit → push → PR作成

### Phase 4: 進捗監視

```bash
# 別ターミナルで
wkd dash
```

---

## 9. Claude Code統合

### 9.1 Headlessモード実行

各Workerで以下のように実行：

```bash
# .workspaces/WRK-001/ 配下で実行
claude \
  --prompt "$(cat .workspaces/.workers/WRK-001.prompt.md)" \
  --dangerously-skip-permissions \
  --output-format stream-json
```

### 9.2 Worker用プロンプト例

```markdown
# Worker WRK-001: WorkspaceId型定義

あなたはDomain層のブランド型を実装します。

## タスク情報
- Worker ID: WRK-001
- Title: WorkspaceId型定義
- Layer: domain
- Files: be-api/src/domain/workspace/WorkspaceId.ts

## 制約条件
- 変更可能なファイル: be-api/src/domain/workspace/**
- 最大変更行数: 100行
- 既存の OrganizationId 実装を参考にする

## 実装要件
1. WorkspaceIdブランド型の作成
2. バリデーション関数の実装
3. ユニットテストの作成

## 参考実装
be-api/src/domain/organization/OrganizationId.ts

## 出力
実装完了後、以下を確認してください：
- [ ] TypeScriptコンパイルが通る
- [ ] ユニットテストが全て成功
- [ ] Lintエラーがない
```

### 9.3 セキュリティ設定 (.claude/settings.json)

各Workerのworktree内に`.claude/settings.json`を自動配置し、危険なコマンドを制限します。

**設定ファイルの配置場所：**
```
.workspaces/WRK-001/.claude/settings.json
```

**settings.jsonの構造：**
```json
{
  "permissions": {
    "deny": [
      "Bash(git config *)",
      "Bash(brew install *)",
      "Bash(apt install *)",
      "Bash(npm install -g *)",
      "Bash(yarn global add *)",
      "Bash(chmod 777 *)",
      "Bash(chmod +x /usr/* *)",
      "Bash(rm -rf /* *)",
      "Bash(rm -rf ~/* *)",
      "Bash(gh repo delete *)",
      "Bash(gh auth *)",
      "Bash(git push --force *)",
      "Bash(docker run --privileged *)",
      "Bash(sudo *)",
      "Bash(su *)",
      "Bash(curl * | bash)",
      "Bash(wget * | bash)",
      "Write(**/.env)",
      "Write(**/.env.*)",
      "Write(**/id_rsa)",
      "Write(**/id_ed25519)",
      "Write(**/.ssh/*)",
      "Edit(**/.env)",
      "Edit(**/.env.*)",
      "Edit(**/package-lock.json)",
      "Edit(**/yarn.lock)",
      "Edit(**/pnpm-lock.yaml)"
    ]
  }
}
```

**deny設定のカテゴリ：**

1. **システム設定変更の禁止**
   - `git config` - Git設定変更
   - `brew/apt install` - パッケージマネージャーでのインストール
   - `chmod 777` - 危険な権限変更

2. **破壊的操作の禁止**
   - `rm -rf /*` - ルートディレクトリ削除
   - `gh repo delete` - リポジトリ削除
   - `git push --force` - 強制プッシュ

3. **権限昇格の禁止**
   - `sudo`, `su` - 管理者権限実行
   - `docker --privileged` - 特権コンテナ実行

4. **危険なダウンロード実行の禁止**
   - `curl | bash` - リモートスクリプト直接実行
   - `wget | bash` - リモートスクリプト直接実行

5. **機密ファイルの保護**
   - `.env*` - 環境変数ファイル
   - `.ssh/*` - SSH鍵ファイル
   - `*.lock` - 依存関係ロックファイル

**自動生成の実装：**

```bash
# lib/claude/executor.sh

setup_claude_settings() {
  local worker_dir="$1"
  local worker_id="$2"

  local claude_dir="${worker_dir}/.claude"
  mkdir -p "$claude_dir"

  # settings.jsonを生成
  cat > "${claude_dir}/settings.json" <<'EOF'
{
  "permissions": {
    "deny": [
      "Bash(git config *)",
      "Bash(brew install *)",
      "Bash(apt install *)",
      "Bash(npm install -g *)",
      "Bash(yarn global add *)",
      "Bash(chmod 777 *)",
      "Bash(chmod +x /usr/* *)",
      "Bash(rm -rf /* *)",
      "Bash(rm -rf ~/* *)",
      "Bash(gh repo delete *)",
      "Bash(gh auth *)",
      "Bash(git push --force *)",
      "Bash(docker run --privileged *)",
      "Bash(sudo *)",
      "Bash(su *)",
      "Bash(curl * | bash)",
      "Bash(wget * | bash)",
      "Write(**/.env)",
      "Write(**/.env.*)",
      "Write(**/id_rsa)",
      "Write(**/id_ed25519)",
      "Write(**/.ssh/*)",
      "Edit(**/.env)",
      "Edit(**/.env.*)",
      "Edit(**/package-lock.json)",
      "Edit(**/yarn.lock)",
      "Edit(**/pnpm-lock.yaml)"
    ]
  }
}
EOF

  echo "✓ Claude settings.json を配置: ${claude_dir}/settings.json"
}
```

**プロジェクト設定でのカスタマイズ：**

`.wkdrc.yaml`で追加のdenyパターンを定義可能：

```yaml
claude:
  command: claude
  settings:
    deny:
      # プロジェクト固有の禁止パターン
      - "Bash(firebase deploy *)"
      - "Bash(vercel deploy *)"
      - "Write(**/database.yml)"
      - "Edit(**/secrets.yaml)"
```

**deny-check.shフック（オプション）：**

より高度な制限が必要な場合、PreToolUseフックを使用：

```bash
# .workspaces/WRK-001/.claude/hooks/PreToolUse

#!/bin/bash
# deny-check.sh

TOOL_NAME="$1"
TOOL_ARGS="$2"

# settings.jsonからdenyパターンを読み込み
DENY_PATTERNS=$(jq -r '.permissions.deny[]' .claude/settings.json)

# パターンマッチング
while IFS= read -r pattern; do
  if [[ "${TOOL_NAME}(${TOOL_ARGS})" == $pattern ]]; then
    echo "❌ 拒否: このコマンドは実行できません: ${TOOL_NAME}(${TOOL_ARGS})"
    echo "理由: セキュリティポリシーにより禁止されています"
    exit 1
  fi
done <<< "$DENY_PATTERNS"

exit 0
```

**参考資料：**
- [Claude Code のセキュアな Bash 実行設定](https://wasabeef.jp/blog/claude-secure-bash)

---

## 10. 実装のポイント

### 10.1 Bash関数の構成

**config.sh** - 設定読み込み
```bash
load_config() {
  # .wkdrc.yamlを読み込んで環境変数に設定
  # yqまたはsed/grepで解析
}
```

**create.sh** - Epic → Task分割
```bash
create_tasks() {
  local epic_name="$1"
  # 1. Epic読み込み
  # 2. Claude Code Plan agent実行
  # 3. 結果をjqでパース
  # 4. Taskディレクトリ作成
}
```

**run.sh** - Task → Worker実装
```bash
run_task() {
  local task_dir="$1"
  # 1. Task読み込み
  # 2. Claude Code Plan agentで分割
  # 3. Worker メタデータ作成
  # 4. tmuxセッション構築
  # 5. 並列実行
}
```

**tmux/manager.sh** - tmux操作
```bash
create_tmux_session() {
  # tmux new-session, split-window等
}

launch_worker() {
  local worker_id="$1"
  # git worktree作成 → Claude Code実行
}
```

**claude/executor.sh** - Claude Code実行とセキュリティ設定
```bash
setup_claude_settings() {
  local worker_dir="$1"

  # .claude/ディレクトリ作成
  mkdir -p "${worker_dir}/.claude/hooks"

  # デフォルトのdenyパターン
  local default_deny='[
    "Bash(git config *)",
    "Bash(brew install *)",
    "Bash(sudo *)",
    "Write(**/.env*)",
    "Edit(**/yarn.lock)"
  ]'

  # .wkdrc.yamlのカスタム設定を読み込み
  local custom_deny=$(yq eval '.claude.settings.deny' .wkdrc.yaml -o json)

  # デフォルトとカスタムをマージ
  local merged_deny=$(jq -s '.[0] + .[1]' <(echo "$default_deny") <(echo "$custom_deny"))

  # settings.jsonを生成
  jq -n --argjson deny "$merged_deny" '{permissions: {deny: $deny}}' \
    > "${worker_dir}/.claude/settings.json"

  # PreToolUseフックをコピー
  cp templates/claude/hooks/PreToolUse "${worker_dir}/.claude/hooks/"
  chmod +x "${worker_dir}/.claude/hooks/PreToolUse"
}

execute_claude_headless() {
  local worker_dir="$1"
  local prompt_file="$2"

  cd "$worker_dir"

  # settings.json配置
  setup_claude_settings "$worker_dir"

  # Claude Code実行
  claude \
    --prompt "$(cat "$prompt_file")" \
    --dangerously-skip-permissions \
    --output-format stream-json
}
```

### 10.2 データ管理（ファイルベース）

**Worker メタデータ**: `.workspaces/.workers/WRK-001.json`
```json
{
  "id": "WRK-001",
  "title": "WorkspaceId型定義",
  "state": "running",
  "taskDir": "tasks/workspace-management/workspace-list-api",
  "dependencies": [],
  "createdAt": "2025-01-15T10:00:00Z"
}
```

**状態管理**: ファイルの存在で判定
- `.workspaces/WRK-001/.success` - 成功マーカー
- `.workspaces/WRK-001/.failed` - 失敗マーカー

---

## 11. 次のステップ

1. `bin/wkd` メインスクリプト作成
2. `lib/core/config.sh` 設定読み込み実装
3. `lib/commands/create.sh` Epic→Task分割実装
4. `lib/commands/run.sh` Task→Worker実装
5. `lib/tmux/manager.sh` tmux操作実装
6. テストとドキュメント整備
