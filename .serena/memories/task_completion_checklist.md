# Worker-driven Dev CLI - タスク完了チェックリスト

## タスク完了時の手順

### 1. コード品質チェック

#### スクリプト構文チェック
```bash
# Bash構文チェック
bash -n lib/commands/*.sh
bash -n lib/core/*.sh
bash -n lib/git/*.sh
bash -n lib/tmux/*.sh
bash -n lib/claude/*.sh
bash -n bin/wkd
```

#### 実行権限確認
```bash
# 実行可能ファイルの権限確認
ls -la bin/wkd                    # 755 または 実行可能
ls -la templates/claude/hooks/*   # 755 または 実行可能
ls -la test_*.sh                  # 755 または 実行可能
```

### 2. テスト実行

#### ユニットテスト
```bash
# 個別テスト実行
./test_config.sh
./test_logger.sh
./test_parser.sh
./test_claude_setup.sh

# （他のテストファイルがあれば実行）
```

#### 統合テスト
```bash
# 初期化テスト
wkd init

# Epic → Task分割テスト（サンプルEpicがあれば）
wkd create tasks <sample-epic>

# Task → Worker実行テスト（サンプルTaskがあれば）
wkd run <sample-task>
```

### 3. ドキュメント更新

#### コード変更がある場合
- [ ] README.md を更新（新機能、使用方法）
- [ ] DEVELOPMENT.md を更新（実装状況、既知の問題）
- [ ] description.md を更新（仕様変更がある場合）

#### コメント追加
- [ ] 複雑な関数には説明コメントを追加
- [ ] 将来の開発者のために意図を明確に記述

### 4. Git操作

#### コミット前確認
```bash
# 変更ファイル確認
git status

# 差分確認
git diff

# ステージング前に.gitignore確認
cat .gitignore
```

#### コミット
```bash
# ステージング
git add <files>

# コミット（日本語メッセージ）
git commit -m "feat: 新機能の説明

- 変更内容1
- 変更内容2
- 変更内容3
"
```

#### コミットメッセージ規約
- **Type**: feat, fix, docs, refactor, test, chore
- **言語**: 日本語
- **形式**: 
  ```
  <type>: <簡潔な説明>
  
  <詳細な説明（箇条書き）>
  ```

### 5. プッシュ前確認

#### ローカルテスト
```bash
# 最新のmainブランチとマージ可能か確認
git fetch origin
git merge origin/main --no-commit --no-ff
git merge --abort  # テストのみの場合

# コンフリクトがないか確認
```

#### セキュリティチェック
- [ ] `.env` や機密情報が含まれていないか確認
- [ ] ハードコードされた認証情報がないか確認
- [ ] 個人情報が含まれていないか確認

### 6. プッシュとPR

#### プッシュ
```bash
# リモートにプッシュ
git push origin <branch>

# 新規ブランチの場合
git push -u origin <branch>
```

#### PR作成（必要な場合）
```bash
# GitHub CLIでPR作成
gh pr create --fill --label enhancement

# Webで作成する場合はURLを開く
```

### 7. クリーンアップ

#### 一時ファイル削除
```bash
# ログファイル
rm -f *.log

# 一時ファイル
rm -f *.tmp

# テストで生成されたファイル
rm -rf test_output/
```

#### 使用していないworktree削除
```bash
# worktree一覧確認
git worktree list

# 不要なworktree削除
git worktree remove .workspaces/WRK-XXX
git worktree prune
```

#### tmuxセッション削除
```bash
# セッション一覧確認
tmux list-sessions

# 不要なセッション削除
tmux kill-session -t wkd
```

## 追加のベストプラクティス

### コードレビュー（セルフレビュー）
- [ ] 不要なコメントアウトを削除
- [ ] デバッグ用の `echo` や `printf` を削除
- [ ] 変数名が明確か確認
- [ ] 関数が単一責任の原則に従っているか確認
- [ ] エラーハンドリングが適切か確認

### パフォーマンス
- [ ] 不要なサブプロセス起動を削減
- [ ] ループ内での外部コマンド呼び出しを最小化
- [ ] 大きなファイルの処理を効率化

### セキュリティ
- [ ] `.claude/settings.json` のdenyパターンが適切か確認
- [ ] `PreToolUse` フックが正しく動作するか確認
- [ ] 危険なコマンド（`rm -rf`, `sudo` 等）が制限されているか確認

### ドキュメント
- [ ] 新しいコマンドがREADMEに記載されているか
- [ ] 使用例が明確か
- [ ] トラブルシューティング情報が充実しているか

## リリース前チェックリスト

### v1.0.0 リリース時
- [ ] 全機能が実装完了
- [ ] 全テストが通過
- [ ] ドキュメントが完全
- [ ] サンプルEpic/Taskを用意
- [ ] チュートリアルを作成
- [ ] CHANGELOG.md を作成
- [ ] GitHubでリリースタグを作成

## 問題発生時の対応

### デバッグ手順
1. ログレベルをDEBUGに設定: `export LOG_LEVEL=DEBUG`
2. 問題のコマンドを再実行
3. エラーメッセージを確認
4. 関連するログファイルを確認
5. 必要に応じてissueを作成

### ロールバック
```bash
# 最後のコミットを取り消し（ローカルのみ）
git reset --soft HEAD~1

# プッシュ済みの場合（慎重に！）
git revert HEAD
git push
```
