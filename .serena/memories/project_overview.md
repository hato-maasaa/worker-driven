# Worker-driven Dev CLI - プロジェクト概要

## プロジェクトの目的

Worker-driven Dev CLI は、CLI主体でタスクを極小単位（Worker）に自動分割し、tmux + git worktree で並列実行する開発ツールです。

Epic（大タスク）から実装完了（PR作成）まで、以下を自動化：
- Epic → Task → Worker への自動分割（Claude Code Plan agent使用）
- 各Workerごとに独立した作業環境（git worktree + tmux）を自動生成
- 並列実装・テスト・PR作成

## 技術スタック

### 実装言語
- **Pure Bash Script** - Bash ≥ 3.2 (macOS互換)
- TypeScript/Node.jsは使用しない

### 必須ツール
- Bash ≥ 5.0 (推奨) / ≥ 3.2 (macOS互換)
- tmux ≥ 3.x (並列実行)
- git ≥ 2.35 (git worktree対応)
- jq (JSON処理 - 必須)
- gh CLI (GitHub操作)
- Claude Code CLI (claude-code コマンド)

### オプションツール
- yq (YAML処理 - 推奨。なければsed/grepでフォールバック)

### アーキテクチャ
- CLI tool (API/NestJSではない)
- Filesystem-based データ管理
- Git worktree + tmux による並列実行
- Claude Code との統合

## プロジェクトの特徴

1. **完全にBashシェルスクリプトで実装**
2. CLI操作のみ（キーボードのみで完結）
3. tmuxで並列作業を可視化
4. git worktreeで各Workerを完全に分離
5. Claude Code統合でAI支援開発
6. セキュリティ設定による危険なコマンドの制限

## 現在のバージョン

v0.1.0

## 実装状況

### ✅ 実装済み
- プロジェクト構造
- メインCLI (`bin/wkd`)
- コアライブラリ (config, logger, parser)
- Claude executor (セキュリティ設定)
- Git worktree管理
- tmux管理機能
- 主要コマンド (create, run, list, stats, attach, logs)
- テンプレート (settings.json, PreToolUse)

### ⏳ 実装予定
- ダッシュボード機能の完全実装
- Worker再実行機能の完全実装

## リポジトリ情報

- GitHub: git@github.com:hato-maasaa/worker-driven.git
- メインブランチ: main

## 用語

- **Epic**: 大きなテーマ（手動で作成）
- **Task**: Epicを機能粒度に分割した単位（AIが自動生成）
- **Worker**: 実行最小単位（1目的 = 1ブランチ = 1 worktree = 1 PR）
- **Workspace**: git worktreeで作るWorker用の作業ディレクトリ
