# Worker-driven Dev CLI

**CLI主体でタスクを極小単位（Worker）に自動分割し、tmux + git worktree で並列実行する開発ツール**

Epic（大タスク）から実装完了（PR作成）まで、以下を自動化：
- Epic → Task → Worker への自動分割（Claude Code Plan agent使用）
- 各Workerごとに独立した作業環境（git worktree + tmux）を自動生成
- 並列実装・テスト・PR作成

## ✨ 特徴

- **完全にBashシェルスクリプトで実装**
- CLI操作のみ（キーボードのみで完結）
- tmuxで並列作業を可視化
- git worktreeで各Workerを完全に分離
- Claude Code統合でAI支援開発

## 📦 インストール

### 必須ツール

```bash
# 必須
- Bash ≥ 5.0
- tmux ≥ 3.x
- git ≥ 2.35 (git worktree対応)
- jq (JSON処理)
- gh CLI (GitHub操作)
- Claude Code CLI (claude-code コマンド)

# オプション（推奨）
- yq (YAML処理)
```

### macOSでのインストール

```bash
brew install tmux git jq gh yq
```

### セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/yourorg/worker-driven.git
cd worker-driven

# PATHに追加（~/.bashrc または ~/.zshrc）
export PATH="/path/to/worker-driven/bin:$PATH"

# プロジェクトディレクトリで初期化
cd /path/to/your-project
wkd init
```

## 🚀 クイックスタート

### 1. Epic作成（手動）

```bash
mkdir -p tasks/epics
cat > tasks/epics/workspace-onboarding.md <<'EOF'
---
epic: workspace-onboarding
priority: high
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
EOF
```

### 2. Epic → Task分割（AI自動）

```bash
wkd create tasks workspace-onboarding
```

実行内容：
- `tasks/epics/workspace-onboarding.md` を読み込み
- Claude Code Plan agentでTask分割
- `tasks/workspace-management/` 配下にTask作成

### 3. Task → Worker → 実装（AI自動）

```bash
wkd run workspace-management --parallel --auto-pr
```

実行内容：
- 各TaskをClaude Code Plan agentでWorkerに分割
- 各Workerに git worktree作成
- tmux並列セッション起動
- Claude Code headlessで実装
- テスト → commit → push → PR作成

### 4. 進捗監視

```bash
# 別ターミナルで
wkd dash
```

## 📚 主要コマンド

```bash
# Epic → Task 分割
wkd create tasks <epic-name>
wkd create tasks workspace-onboarding --auto-approve

# Task → Worker → 実装
wkd run <task-dir>
wkd run workspace-management --parallel --auto-pr

# ダッシュボード表示
wkd dash

# 一覧表示
wkd list epics
wkd list tasks
wkd list workers

# tmuxセッションにアタッチ
wkd attach

# ログ表示
wkd logs WRK-001

# リトライ
wkd retry --failed
wkd retry WRK-001 --from-step=typecheck

# 統計情報
wkd stats

# 設定初期化
wkd init

# ヘルプ
wkd help
```

## 📁 プロジェクト構造

```
your-project/
├── .wkdrc.yaml           # Worker-driven設定
├── tasks/
│   ├── epics/            # Epic格納（手動作成）
│   │   ├── workspace-onboarding.md
│   │   └── user-authentication.md
│   └── workspace-management/  # Task格納（AI生成）
│       ├── workspace-list-api/
│       │   └── task.md
│       └── workspace-create-api/
│           └── task.md
└── .workspaces/          # Worker実行環境
    ├── .workers/         # Workerメタデータ
    │   ├── WRK-001.json
    │   └── WRK-001.prompt.md
    └── WRK-001/          # git worktree
        └── .claude/
            └── settings.json  # セキュリティ設定
```

## 🔒 セキュリティ

各Workerの `.claude/settings.json` で危険なコマンドを制限：

```json
{
  "permissions": {
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf /* *)",
      "Bash(git config *)",
      "Write(**/.env*)",
      "Edit(**/yarn.lock)"
    ]
  }
}
```

詳細は [description.md](description.md) のセクション9.3を参照。

## 📖 ドキュメント

- [完全な仕様書](description.md) - 詳細な仕様と実装ガイド
- [設定ファイル例](.wkdrc.yaml) - プロジェクト設定のサンプル

## 🛠️ 開発状況

現在のバージョン: **0.1.0**

実装済み：
- ✅ プロジェクト構造
- ✅ メインCLI (`bin/wkd`)
- ✅ コアライブラリ (config, logger, parser)
- ✅ Claude executor (セキュリティ設定)
- ✅ テンプレート (settings.json, PreToolUse)

実装予定：
- ⏳ `wkd create tasks` コマンド
- ⏳ `wkd run` コマンド
- ⏳ tmux管理機能
- ⏳ git worktree管理機能
- ⏳ ダッシュボード機能

## 🤝 コントリビューション

貢献歓迎です！Issue や Pull Request をお待ちしています。

## 📄 ライセンス

MIT License

## 🙏 参考資料

- [Claude Code のセキュアな Bash 実行設定](https://wasabeef.jp/blog/claude-code-secure-bash)
- [Claude Code 公式ドキュメント](https://docs.claude.com/en/docs/claude-code)
