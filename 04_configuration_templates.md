# 04. AGENTS.md & 設定ファイルテンプレート（Copilot CLI版）

本ドキュメントは、Salesforceマルチエージェント開発フレームワークで使用する各種設定ファイルのテンプレートを提供する。各テンプレートはコードブロック内に記述しており、そのままコピー&ペーストで利用可能である。

---

## 目次

1. [AGENTS.md（プロジェクトルート用）](#1-agentsmdプロジェクトルート用)
2. [AGENTS.md（force-app配下用）](#2-copilot-instructionsmdforce-app配下用)
3. [settings.json](#3-settingsjson)
4. [Hooks定義](#4-hooks定義)
5. [案件テンプレート](#5-案件テンプレート)
6. [instructions/定義テンプレート](#6-rules定義テンプレート)
7. [Skills定義テンプレート](#7-skills定義テンプレート)

---

## 1. AGENTS.md（プロジェクトルート用）

プロジェクトルートに配置する `AGENTS.md` は、全エージェント（リードエージェント・サブエージェント共通）が参照するプロジェクト全体の規約・方針を定義する。

### 配置先

```
<project-root>/AGENTS.md
```

### テンプレート

> **設計意図**: AGENTS.mdは全エージェントが常時ロードするため、コンテキストコストが最も高い。Apex/LWC/テストのコーディングルールは `.github/instructions/` に配置し、ここにはプロジェクト概要とプロセス規約のみを記載する。

```markdown
# AGENTS.md — プロジェクトルート設定

## プロジェクト概要

- **案件名**: {{PROJECT_NAME}}
- **案件ID**: {{PROJECT_ID}}
- **対象Salesforce組織**: {{ORG_ALIAS}}（{{INSTANCE_URL}}）
- **開発範囲**: {{SCOPE_DESCRIPTION}}
- **開始日**: {{START_DATE}}
- **主担当**: {{OWNER_NAME}}

## コーディングルールの配置先

Salesforce開発のコーディングルール（ガバナ制限、FLS、命名規約、禁止パターン等）は `.github/instructions/` に配置されている。ファイル操作時に自動適用されるため、AGENTS.md には記載しない。

| ルールファイル | 適用条件 | 主な内容 |
|---|---|---|
| `.github/instructions/apex-coding.md` | `*.cls`, `*.trigger` 作業時 | ガバナ制限値、FLS必須、バルク化原則、命名規約、禁止パターン |
| `.github/instructions/lwc-coding.md` | `lwc/` 配下作業時 | Wire優先、SLDS準拠、イベント設計 |
| `.github/instructions/test-coding.md` | `*Test.cls` 作業時 | @TestSetup、SeeAllData禁止、カバレッジ基準 |
| `.github/instructions/commit-rules.md` | コミット操作時 | メッセージフォーマット、粒度ルール |
| `.github/instructions/review-rules.md` | レビュー作業時 | Severity定義、ゲート通過条件 |

## メタデータカタログ

- **スキーマ情報**: metadata-catalog/schema/ — オブジェクト構造、リレーションマップ
- **カタログ情報**: metadata-catalog/catalog/ — 辞書、自動化一覧、権限マトリクス
- ※ 実装・設計時は必ずカタログを参照し、既存のオブジェクト構造・自動化ロジックとの整合性を確認すること

## アーキテクチャドキュメント

- **システムコンテキスト図**: docs/architecture/system-context.md — レイヤー構成、外部連携マップ
- **設計判断記録（ADR）**: docs/architecture/decisions/ — 過去の重要な技術選定とその理由
- **横断的方針**: docs/architecture/policies/ — セキュリティ、パフォーマンス、外部連携、エラーハンドリング
- ※ 設計・レビュー時は必ずこれらを参照し、システム全体との整合性を確認すること
- ※ 重要な設計判断を行った場合はADRを新規作成すること（テンプレート: docs/architecture/decisions/_template.md）

## サブエージェント利用ガイドライン

### 利用可能なサブエージェント

| エージェント名 | 役割 | 呼び出しタイミング |
|---|---|---|
| `sf-metadata-analyst` | メタデータ取得・構造化 | Phase 0, Phase 2（Nice to Have追加取得） |
| `sf-requirements-analyst` | 要件定義書の作成 | Phase 1 |
| `sf-designer` | 技術設計書の作成 | Phase 2 |
| `sf-implementer` | コードの新規作成・修正 | Phase 3 |
| `sf-tester` | テストコード作成・実行 | Phase 4 |
| `sf-code-reviewer` | コードレビュー・品質チェック | Phase 5 |

### 呼び出し原則

1. **1フェーズ1エージェント**: 各フェーズで呼び出すサブエージェントは原則1つ。並行呼び出しは行わない
2. **コンテキスト引き継ぎ**: サブエージェントへの指示には、前フェーズの成果物パスを明示的に含める
3. **スコープ限定**: サブエージェントへの指示は具体的かつ限定的にする
4. **成果物確認**: サブエージェントの出力は必ずリードエージェントが確認してから次フェーズに進む
5. **リトライ制限**: 同一タスクのリトライは最大3回。3回失敗した場合はヒューマンエスカレーション

### コンテキスト管理

1. フェーズ完了ごとに `/compact` を実行してコンテキストを圧縮する
2. 大規模なメタデータはファイルに書き出し、サブエージェントには必要部分のみを渡す
3. 中間成果物は `docs/projects/` に保存し、後続フェーズで参照する

### ヒューマンゲート制御手順

フェーズ完了時、リードエージェントは以下の手順でヒューマンゲートを制御する。

#### ステップ1: ゲート設定の読み取り

```bash
# project-config.json からヒューマンゲート設定を取得
GATE_VALUE=$(jq -r '.humanGates.gate_requirements' docs/projects/${PROJECT_ID}/project-config.json)
```

#### ステップ2: ゲート有効時の応答テンプレート

ゲートが `true` の場合、以下の形式で人間に承認を要求し、ターンを終了する:

```
## [フェーズ名] 完了 — 承認待ち

### 成果物
- [成果物ファイルパスと概要の一覧]

### 確認ポイント
- [そのフェーズ固有の確認観点を列挙]

### 次のアクション
以下のいずれかで応答してください:
- **承認**: 「承認」「OK」「進めて」などと入力 → 次フェーズに進行します
- **差し戻し**: 「差し戻し」と入力し、修正指示を記載 → 当該フェーズを再実行します
- **中断**: 「中断」と入力 → 処理を停止します

⏳ **承認待ちのため、応答があるまで次フェーズには進みません。**
```

#### ステップ3: 応答の解釈

| 入力パターン | 解釈 | アクション |
|---|---|---|
| 「承認」「OK」「approve」「進めて」「LGTM」 | 承認 | 次フェーズに進行 |
| 「差し戻し」「reject」「やり直し」+ 修正指示 | 差し戻し | 修正指示に基づき当該フェーズを再実行 |
| 「中断」「stop」「待って」 | 中断 | 処理を停止し、再開指示を待つ |
| 上記に該当しない入力 | 不明 | 「承認・差し戻し・中断のいずれかで応答してください」と再度要求 |

#### ステップ4: ゲート無効時の動作

ゲートが `false` の場合、成果物を保存し自動的に次フェーズに進行する。

#### 禁止事項

- ゲートが `true` の場合、**人間の明示的な承認なしに次フェーズに進んではならない**
- ゲート待機中に「おそらく問題ないので進めます」等の自己判断による進行は禁止
- ゲート設定ファイルの読み取りに失敗した場合は、ゲート有効（true）として扱う（フェイルセーフ）

## 禁止事項

- 本番組織への直接デプロイ禁止
- `dangerously-skip-permissions` の使用禁止
- 旧 `sfdx` コマンドの使用禁止（`sf` v2 を使用すること）
```

---

## 2. AGENTS.md（force-app配下用）

`force-app/` ディレクトリ配下に配置する `AGENTS.md` は、アーキテクチャ原則とメタデータ操作規約に限定する。コーディング規約（命名、禁止パターン等）は `.github/instructions/` で自動適用されるため、ここには含めない。

### 配置先

```
<project-root>/force-app/AGENTS.md
```

### テンプレート

> **設計意図**: force-app/AGENTS.md はこのディレクトリ配下で作業する全エージェントが読む。具体的なコーディングルールは instructions/ に配置し、ここではレイヤー分離やトリガフレームワーク等の構造的な設計原則のみを記載する。

```markdown
# AGENTS.md — force-app 配下設定

このディレクトリ配下での開発作業に適用される追加ルール。
プロジェクトルートの AGENTS.md のルールも併せて適用される。

## アーキテクチャ原則

### トリガフレームワーク
1. **1オブジェクト1トリガ構成を厳守する**
   - トリガ: `{ObjectName}Trigger.trigger` — イベントの振り分けのみ
   - ハンドラ: `{ObjectName}TriggerHandler.cls` — ロジックを実装
   - トリガからハンドラを呼び出す際は `TriggerHandler` 基底クラスを使用する

### レイヤー分離
   - **Selector層**: SOQLクエリの集約。`{ObjectName}Selector.cls`
   - **Service層**: ビジネスロジックの集約。`{ObjectName}Service.cls`
   - **Domain層**: トリガハンドラとバリデーション。`{ObjectName}TriggerHandler.cls`
   - **Controller層**: LWC/Aura向けの `@AuraEnabled` メソッド。`{ObjectName}Controller.cls`
   - **ユーティリティ**: 共通処理は `Utilities/` 配下に配置する

## コーディングルールの配置先

具体的なコーディングルールは `.github/instructions/` で自動適用される:
- Apex命名規約・禁止パターン・ガバナ制限 → `.github/instructions/apex-coding.md`（`*.cls`, `*.trigger` 作業時）
- LWCコーディング規約 → `.github/instructions/lwc-coding.md`（`lwc/` 配下作業時）
- テスト規約 → `.github/instructions/test-coding.md`（`*Test.cls` 作業時）

## メタデータ操作ルール

### 取得（Retrieve）
1. `sf project retrieve start` を使用（`-m` フラグでメタデータタイプを指定）
2. 全量取得禁止（メタデータタイプ指定なしでの実行は不可）
3. 取得後は `git diff` で差分を確認してからコミット

### デプロイ（Deploy）
1. 本番デプロイ前に必ず `--dry-run` で検証する
2. 本番デプロイ時は `-l RunLocalTests` を必ず指定する
3. 変更のあったコンポーネントのみをデプロイする

### メタデータ変更時の注意事項
1. カスタム項目追加時: 対応するプロファイル/権限セットのFLS設定も含める
2. レコードタイプ追加時: ページレイアウト割当、ピックリスト値の設定も含める
3. バリデーションルール変更時: 既存テストデータへの影響を確認し、テストを更新する
4. フロー変更時: バージョン管理に注意する。古いバージョンの無効化を忘れない
5. 破壊的変更: 項目削除、オブジェクト削除等は `destructiveChanges.xml` を使用する
```

---

## 3. settings.json

Copilot CLIの設定ファイル。パーミッション、環境変数、ヒューマンゲートの構成を定義する。

### 配置先

```
<project-root>/.github/settings.json
```

### テンプレート

```json
{
  "permissions": {
    "allow": [
      "Bash(sf project:*)",
      "Bash(sf apex:*)",
      "Bash(sf org:display)",
      "Bash(sf org:list)",
      "Bash(sf data:query:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(git merge:*)",
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(git status)",
      "Bash(git stash:*)",
      "Bash(npx prettier:*)",
      "Bash(npm test:*)",
      "Bash(node:*)",
      "Bash(cat:*)",
      "Bash(mkdir:*)",
      "Bash(cp:*)",
      "Bash(mv:*)",
      "Read",
      "Write",
      "Edit",
      "Grep",
      "Glob"
    ],
    "deny": [
      "Bash(sf org:delete:*)",
      "Bash(sf org:create:*)",
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)",
      "Bash(git reset --hard:*)",
      "Bash(sf data:delete:*)",
      "Bash(curl:*)",
      "Bash(wget:*)"
    ]
  },
  "env": {
    "SF_TARGET_ORG": "{{ORG_ALIAS}}",
    "SF_API_VERSION": "62.0",
    "PROJECT_ID": "{{PROJECT_ID}}",
    "ARTIFACTS_DIR": "docs/projects",
    "METADATA_CATALOG_PATH": "metadata-catalog"
  }
}
```

### 補足: settings.json の設計方針

| セクション | 説明 |
|---|---|
| `permissions.allow` | サブエージェントが承認プロンプトなしで実行できるコマンド。`sf` の読み取り系・デプロイ系と `git` の基本操作を事前許可する |
| `permissions.deny` | 破壊的操作を明示的にブロックする。組織削除、強制プッシュ、データ全削除などが対象 |
| `env` | 案件固有の環境変数。サブエージェントのプロンプト内で `$SF_TARGET_ORG` 等として参照される |

---

## 4. Hooks定義

Copilot CLIのHooks機能を用いて、ツール実行の前後に自動処理を挿入する。

### 配置先

```
<project-root>/.github/settings.json（hooks セクション内）
```

### テンプレート

以下を `settings.json` の `hooks` キーとして追加する。上記の `permissions` / `env` と同一ファイルに統合すること。

```json
{
  "permissions": {
    "...": "（上記 settings.json の permissions セクションと同一）"
  },
  "env": {
    "...": "（上記 settings.json の env セクションと同一）"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$COPILOT_TOOL_INPUT\" | grep -q '\\.cls\\|\\.trigger'; then npx prettier --plugin=prettier-plugin-apex --write \"$(echo $COPILOT_TOOL_INPUT | jq -r '.file_path // .filePath // empty')\" 2>/dev/null; fi",
            "timeout": 10000
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$COPILOT_TOOL_INPUT\" | grep -qE 'sf project deploy|sf apex run test'; then echo \"[Phase Notification] Salesforce操作が完了しました: $(date +%H:%M:%S)\" >> docs/projects/execution.log; fi",
            "timeout": 5000
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$COPILOT_TOOL_INPUT\" | grep -q 'git commit'; then echo 'コミット前チェック: テスト実行を推奨します' >&2; fi",
            "timeout": 5000
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date +%Y-%m-%d\\ %H:%M:%S)] NOTIFICATION: $COPILOT_NOTIFICATION\" >> docs/projects/notifications.log",
            "timeout": 3000
          }
        ]
      }
    ]
  }
}
```

### 各Hookの詳細説明

#### PostToolUse: Apex自動フォーマット

```
トリガ条件: Write または Edit ツールの実行後
対象ファイル: .cls または .trigger 拡張子
処理内容: prettier-plugin-apex によるコードフォーマット
タイムアウト: 10秒
```

`prettier-plugin-apex` を使用するため、プロジェクトに以下の依存関係が必要:

```json
// package.json（必要な依存関係）
{
  "devDependencies": {
    "prettier": "^3.0.0",
    "prettier-plugin-apex": "^2.0.0"
  }
}
```

```json
// .prettierrc（Apex用設定）
{
  "plugins": ["prettier-plugin-apex"],
  "overrides": [
    {
      "files": ["*.cls", "*.trigger"],
      "options": {
        "parser": "apex",
        "tabWidth": 4,
        "printWidth": 120,
        "apexInsertFinalNewline": true
      }
    }
  ]
}
```

#### PreToolUse: コミット前チェック

```
トリガ条件: Bash ツール実行前
対象コマンド: git commit を含むコマンド
処理内容: コミット前にテスト実行を推奨する警告を stderr に出力
タイムアウト: 5秒
```

> **注意**: このHookはブロッキング処理ではなく警告のみ。テスト自動実行を強制する場合は、
> 以下のように `exit 2` でツール呼び出しを拒否する構成に変更できる:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if echo \"$COPILOT_TOOL_INPUT\" | grep -q 'git commit'; then LAST_TEST=$(find docs/projects -name 'test_report.md' -mmin -30 | head -1); if [ -z \"$LAST_TEST\" ]; then echo '直近30分以内のテスト結果が見つかりません。先にテストを実行してください。' >&2; exit 2; fi; fi",
      "timeout": 10000
    }
  ]
}
```

#### Notification: フェーズ完了通知

```
トリガ条件: Copilot CLIからの通知イベント発生時
処理内容: 通知内容をログファイルに追記
タイムアウト: 3秒
```

通知ログをSlackやメール等の外部通知と連携させる場合は、`command` を拡張する:

```json
{
  "type": "command",
  "command": "MSG=\"[$(date +%Y-%m-%d\\ %H:%M:%S)] $COPILOT_NOTIFICATION\"; echo \"$MSG\" >> docs/projects/notifications.log; if echo \"$MSG\" | grep -qE 'フェーズ.*完了|Phase.*Complete'; then curl -s -X POST \"$SLACK_WEBHOOK_URL\" -H 'Content-Type: application/json' -d \"{\\\"text\\\": \\\"$MSG\\\"}\" 2>/dev/null || true; fi",
  "timeout": 10000
}
```

---

## 5. 案件テンプレート

### フレームワーク導入の2段階

本フレームワークの初期セットアップは、フレームワーク共通の初期化（1回のみ）と案件固有のセットアップ（案件ごと）の2段階で構成される。

| 段階 | スクリプト | 実行タイミング | 目的 |
|---|---|---|---|
| 初回導入 | `scripts/init-framework.sh` | プロジェクトに1回 | agents/, instructions/, skills/, copilot.json 等の共通ファイルを一括生成 |
| 案件開始 | `scripts/setup-project.sh` | 案件ごとに実行 | 案件固有のディレクトリ・設定・ブランチを作成 |

**クイックスタート:**

```bash
# 1. フレームワーク初期化（初回のみ）
bash scripts/init-framework.sh

# 2. プレースホルダファイルを完成させる（手動）
# [TODO] マークのファイルを 02_subagent_definitions.md / 04_configuration_templates.md に基づいて記入

# 3. 案件セットアップ（案件ごと）
bash scripts/setup-project.sh PROJ-001 my-sandbox "取引先スコアリング機能開発"
```
### 5-0. フレームワーク共通の初期化スクリプト

`init-framework.sh` の詳細はinit-framework.shのファイルを参照すること。スクリプトは `.github/agents/`（6ファイル）、`.github/instructions/`（5ファイル）、`.github/skills/`（5ディレクトリ）、`.github/settings.json`、`AGENTS.md`、`force-app/AGENTS.md`、`docs/architecture/` テンプレートを一括生成する。一部のエージェント定義・Skills はプレースホルダとして生成されるため、02/04_*.md の定義に基づいて内容を転記する必要がある。

#### 配置先

```
scripts/init-framework.sh
```

#### テンプレート

```
#すでに作成しているのでファイルを直接参照すること
init-framework.sh
```

### 5-1. 新規案件セットアップスクリプト

新規案件を開始する際に実行するセットアップスクリプト。ディレクトリ構成の作成、設定ファイルの配置、ブランチの作成を自動化する。`scripts/init-framework.sh` によるフレームワーク初期化が完了していることが前提条件である。

#### 配置先

```
<project-root>/scripts/setup-project.sh
```

#### テンプレート

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Salesforce マルチエージェント開発 — 新規案件セットアップスクリプト
# ============================================================

# --- 入力パラメータ ---
PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> <ORG_ALIAS> <PROJECT_NAME>}"
ORG_ALIAS="${2:?Usage: $0 <PROJECT_ID> <ORG_ALIAS> <PROJECT_NAME>}"
PROJECT_NAME="${3:?Usage: $0 <PROJECT_ID> <ORG_ALIAS> <PROJECT_NAME>}"

# --- 前提条件: フレームワーク初期化済みチェック ---
if [ ! -f ".github/settings.json" ]; then
  echo "ERROR: フレームワークが初期化されていません。"
  echo "先に scripts/init-framework.sh を実行してください。"
  exit 1
fi

# --- 設定 ---
BRANCH_NAME="feature/${PROJECT_ID}"
ARTIFACTS_DIR="docs/projects/${PROJECT_ID}"
METADATA_CATALOG_DIR="metadata-catalog"
START_DATE=$(date +%Y-%m-%d)

echo "========================================"
echo "案件セットアップ開始"
echo "  案件ID:     ${PROJECT_ID}"
echo "  組織:       ${ORG_ALIAS}"
echo "  案件名:     ${PROJECT_NAME}"
echo "  ブランチ:   ${BRANCH_NAME}"
echo "  開始日:     ${START_DATE}"
echo "========================================"

# --- 1. ブランチ作成 ---
echo "[1/6] ブランチを作成..."
git checkout main
git pull origin main
git checkout -b "${BRANCH_NAME}"

# --- 2. ディレクトリ構成作成 ---
echo "[2/6] ディレクトリ構成を作成..."
mkdir -p "${ARTIFACTS_DIR}"
mkdir -p "${METADATA_CATALOG_DIR}"
mkdir -p "docs/architecture/decisions"
mkdir -p "docs/architecture/policies"
mkdir -p "docs/projects/${PROJECT_ID}/requirements"
mkdir -p "docs/projects/${PROJECT_ID}/design"
mkdir -p "docs/projects/${PROJECT_ID}/test-results"
mkdir -p "docs/projects/${PROJECT_ID}/review"

# --- 3. 案件設定ファイル生成 ---
echo "[3/6] 案件設定ファイルを生成..."
cat > "${ARTIFACTS_DIR}/project-config.json" << HEREDOC
{
  "projectId": "${PROJECT_ID}",
  "projectName": "${PROJECT_NAME}",
  "orgAlias": "${ORG_ALIAS}",
  "branch": "${BRANCH_NAME}",
  "startDate": "${START_DATE}",
  "status": "initialized",
  "phases": {
    "metadata-analysis": { "status": "pending", "startedAt": null, "completedAt": null },
    "requirements": { "status": "pending", "startedAt": null, "completedAt": null },
    "design": { "status": "pending", "startedAt": null, "completedAt": null },
    "implementation": { "status": "pending", "startedAt": null, "completedAt": null },
    "testing": { "status": "pending", "startedAt": null, "completedAt": null },
    "review": { "status": "pending", "startedAt": null, "completedAt": null }
  },
  "scope": {
    "objects": [],
    "features": [],
    "description": ""
  },
  "humanGates": {
    "gate_requirements": true,
    "gate_design": true,
    "gate_test": true,
    "gate_pr": true
  }
}
HEREDOC

# --- 4. AGENTS.md にプロジェクト情報を追記 ---
echo "[4/6] AGENTS.md のプロジェクト概要を更新..."
if [ -f "AGENTS.md" ]; then
  # 既存AGENTS.mdのテンプレート変数を置換したコピーを保持
  echo "" >> AGENTS.md
  echo "<!-- Active Project: ${PROJECT_ID} -->" >> AGENTS.md
  echo "<!-- Org: ${ORG_ALIAS} -->" >> AGENTS.md
  echo "<!-- Scope: ${PROJECT_NAME} -->" >> AGENTS.md
fi

# --- 5. 組織接続確認 ---
echo "[5/6] Salesforce組織への接続を確認..."
if sf org display -o "${ORG_ALIAS}" > /dev/null 2>&1; then
  echo "  組織 '${ORG_ALIAS}' への接続: OK"
  # API Version の確認
  API_VERSION=$(sf org display -o "${ORG_ALIAS}" --json 2>/dev/null | jq -r '.result.apiVersion // "62.0"')
  echo "  API Version: ${API_VERSION}"
else
  echo "  WARNING: 組織 '${ORG_ALIAS}' への接続に失敗しました"
  echo "  'sf org login web -a ${ORG_ALIAS}' で認証を行ってください"
fi

# --- 6. 初回コミット ---
echo "[6/6] 初回コミット..."
git add "${ARTIFACTS_DIR}/project-config.json"
git add "${ARTIFACTS_DIR}" "${METADATA_CATALOG_DIR}" 2>/dev/null || true
git commit -m "chore(${PROJECT_ID}): 案件セットアップ — ${PROJECT_NAME}"

echo ""
echo "========================================"
echo "セットアップ完了"
echo ""
echo "次のステップ:"
echo "  1. AGENTS.md のプロジェクト概要を案件に合わせて編集"
echo "  2. project-config.json の scope を定義"
echo "  3. 以下のコマンドでメタデータ分析を開始:"
echo ""
echo "     copilot -p 'sf-metadata-analyst を使用して ${ORG_ALIAS} のメタデータを取得・分析してください。'"
echo ""
echo "========================================"
```

### 5-2. 案件固有設定ファイル（project-config.json）

各案件のステータス、スコープ、ヒューマンゲート設定を管理する設定ファイル。セットアップスクリプトが自動生成するが、手動での編集も可能。

#### 配置先

```
docs/projects/{{PROJECT_ID}}/project-config.json
```

#### テンプレート（手動作成用）

```json
{
  "projectId": "PRJ-001",
  "projectName": "取引先管理機能の拡張",
  "orgAlias": "my-sandbox",
  "branch": "feature/PRJ-001",
  "startDate": "2026-03-09",
  "status": "initialized",
  "phases": {
    "metadata-analysis": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    },
    "requirements": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    },
    "design": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    },
    "implementation": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    },
    "testing": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    },
    "review": {
      "status": "pending",
      "startedAt": null,
      "completedAt": null,
      "artifacts": []
    }
  },
  "scope": {
    "objects": [
      "Account",
      "Contact",
      "Opportunity"
    ],
    "features": [
      "取引先の業種別バリデーション追加",
      "取引先責任者の一括更新画面（LWC）",
      "商談ステージ変更時の自動通知フロー"
    ],
    "description": "取引先管理機能を拡張し、データ品質の向上と営業プロセスの自動化を実現する"
  },
  "humanGates": {
    "gate_requirements": true,
    "gate_design": true,
    "gate_test": true,
    "gate_pr": true
  },
  "metadata": {
    "mustHaveRetrieved": false,
    "niceToHaveItems": [],
    "lastRetrievedAt": null
  }
}
```

### 5-3. フェーズ更新スクリプト

案件のフェーズステータスを更新するユーティリティスクリプト。

#### 配置先

```
<project-root>/scripts/update-phase.sh
```

#### テンプレート

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# フェーズステータス更新スクリプト
# Usage: ./scripts/update-phase.sh <PROJECT_ID> <PHASE> <STATUS>
#   PHASE: metadata-analysis | requirements | design | implementation | testing | review
#   STATUS: in-progress | completed | blocked
# ============================================================

PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> <PHASE> <STATUS>}"
PHASE="${2:?Usage: $0 <PROJECT_ID> <PHASE> <STATUS>}"
STATUS="${3:?Usage: $0 <PROJECT_ID> <PHASE> <STATUS>}"

CONFIG_FILE="docs/projects/${PROJECT_ID}/project-config.json"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: 設定ファイルが見つかりません: ${CONFIG_FILE}"
  exit 1
fi

VALID_PHASES="metadata-analysis requirements design implementation testing review"
if ! echo "${VALID_PHASES}" | grep -qw "${PHASE}"; then
  echo "ERROR: 無効なフェーズ: ${PHASE}"
  echo "有効なフェーズ: ${VALID_PHASES}"
  exit 1
fi

VALID_STATUSES="in-progress completed blocked"
if ! echo "${VALID_STATUSES}" | grep -qw "${STATUS}"; then
  echo "ERROR: 無効なステータス: ${STATUS}"
  echo "有効なステータス: ${VALID_STATUSES}"
  exit 1
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ステータス更新
if [ "${STATUS}" = "in-progress" ]; then
  jq ".phases.\"${PHASE}\".status = \"${STATUS}\" | .phases.\"${PHASE}\".startedAt = \"${TIMESTAMP}\"" \
    "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
elif [ "${STATUS}" = "completed" ]; then
  jq ".phases.\"${PHASE}\".status = \"${STATUS}\" | .phases.\"${PHASE}\".completedAt = \"${TIMESTAMP}\"" \
    "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
else
  jq ".phases.\"${PHASE}\".status = \"${STATUS}\"" \
    "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
fi

# 全体ステータスの自動更新
ALL_COMPLETED=$(jq '[.phases[].status] | all(. == "completed")' "${CONFIG_FILE}")
ANY_IN_PROGRESS=$(jq '[.phases[].status] | any(. == "in-progress")' "${CONFIG_FILE}")

if [ "${ALL_COMPLETED}" = "true" ]; then
  jq '.status = "completed"' "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
elif [ "${ANY_IN_PROGRESS}" = "true" ]; then
  jq '.status = "in-progress"' "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
fi

echo "更新完了: ${PROJECT_ID} / ${PHASE} -> ${STATUS} (${TIMESTAMP})"
```

### 5-4. 案件一覧表示スクリプト

進行中の全案件のステータスを一覧表示するスクリプト。

#### 配置先

```
<project-root>/scripts/list-projects.sh
```

#### テンプレート

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 案件一覧表示スクリプト
# ============================================================

ARTIFACTS_BASE="docs/projects"

if [ ! -d "${ARTIFACTS_BASE}" ]; then
  echo "案件がありません（${ARTIFACTS_BASE} が存在しません）"
  exit 0
fi

echo "========================================"
echo "案件一覧"
echo "========================================"
printf "%-12s %-30s %-15s %-15s %-12s\n" "案件ID" "案件名" "組織" "ブランチ" "ステータス"
echo "------------------------------------------------------------------------"

for config in "${ARTIFACTS_BASE}"/*/project-config.json; do
  if [ -f "${config}" ]; then
    PROJECT_ID=$(jq -r '.projectId' "${config}")
    PROJECT_NAME=$(jq -r '.projectName' "${config}" | cut -c1-28)
    ORG=$(jq -r '.orgAlias' "${config}")
    BRANCH=$(jq -r '.branch' "${config}" | cut -c1-13)
    STATUS=$(jq -r '.status' "${config}")

    printf "%-12s %-30s %-15s %-15s %-12s\n" \
      "${PROJECT_ID}" "${PROJECT_NAME}" "${ORG}" "${BRANCH}" "${STATUS}"

    # フェーズ詳細
    PHASES=$(jq -r '.phases | to_entries[] | "  \(.key): \(.value.status)"' "${config}")
    echo "${PHASES}"
    echo ""
  fi
done
```

---

## 6. instructions/定義テンプレート

`.github/instructions/` に配置する条件付き自動適用ルール。ファイルパターンや作業コンテキストにマッチしたときのみロードされるため、AGENTS.md に記載するよりコンテキスト効率が高い。

### 6-1. apex-coding.md

AGENTS.md や force-app/AGENTS.md に記載されていたApexコーディングルールをすべてここに集約する。

#### 配置先・適用条件

```
.github/instructions/apex-coding.md
globs: ["*.cls", "*.trigger"]
```

#### テンプレート

```markdown
---
description: "Apexクラス・トリガの作成・編集時に適用するルール"
globs: ["*.cls", "*.trigger"]
---

# Apex コーディングルール

## ガバナ制限遵守ルール

| 制限項目 | 同期 | 非同期 |
|---------|------|--------|
| SOQLクエリ数 | 100 | 200 |
| DML文数 | 150 | 150 |
| DMLレコード数 | 10,000 | 10,000 |
| ヒープサイズ | 6MB | 12MB |
| CPU時間 | 10,000ms | 60,000ms |
| Callout数 | 100 | 100 |

1. ループ内でのSOQL実行を禁止する。クエリは事前に一括取得し、Mapで参照する
2. ループ内でのDML実行を禁止する。リストに集約してからバルクDMLを実行する
3. 大量データ処理は Database.Batchable を使用する

## FLS（Field-Level Security）準拠ルール

1. SOQL: `WITH USER_MODE` を原則使用する（`WITH SECURITY_ENFORCED` も許容）
2. DML: `Database.insert(records, AccessLevel.USER_MODE)` または `Security.stripInaccessible()` を使用する
3. LWC: `@AuraEnabled` メソッドは全てFLS準拠にする

## セキュリティルール

1. 全クラスに `with sharing` をデフォルト付与。`without sharing` は明示的な理由とコメントが必要
2. 動的SOQLではバインド変数を必須使用。やむを得ない場合は `String.escapeSingleQuotes()`

## バルク化ルール

1. トリガは常に 200 レコード単位の処理を想定する
2. Map/Set でのルックアップを基本とし、ネストしたループでの検索を回避する
3. DML対象をリストに集約してからバルクDMLを実行する

## 命名規約

| 対象 | 規約 | 例 |
|---|---|---|
| クラス | PascalCase。サフィックスで役割を明示 | `AccountService`, `ContactSelector` |
| トリガ | `{オブジェクト名}Trigger` | `AccountTrigger` |
| テストクラス | `{対象クラス名}Test` | `AccountServiceTest` |
| メソッド | camelCase | `calculateScore`, `getAccountById` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |

## コーディング規約

1. クラス・メソッドにはアクセス修飾子を明示する（`public`, `private`, `global`）
2. 1メソッド50行以内を目安。超過する場合はプライベートメソッドに分割
3. 全 `public` / `global` メソッドに ApexDoc コメントを付与する
4. マジックナンバーは定数クラスまたはカスタムメタデータ型に外出しする
5. null チェックを明示的に行う。`?.`（Safe Navigation Operator）を活用する

## 禁止パターン（P1ブロッカー）

- ループ内SOQL / ループ内DML
- `without sharing` の無根拠な使用
- ハードコードされたレコードID
- ハードコードされたURL・エンドポイント
- `System.debug` のみのエラーハンドリング
- SOQL の `SELECT *` 相当
```

### 6-2. lwc-coding.md

#### 配置先・適用条件

```
.github/instructions/lwc-coding.md
globs: ["force-app/**/lwc/**"]
```

#### テンプレート

```markdown
---
description: "Lightning Web Components の作成・編集時に適用するルール"
globs: ["force-app/**/lwc/**"]
---

# LWC コーディングルール

## 命名規約

- コンポーネント名は camelCase。ファイル名も一致させる
- イベント名は kebab-case

## コーディング規約

1. `@track` は不要（デフォルトでリアクティブ）。オブジェクト/配列は再代入で更新をトリガ
2. データ取得は `@wire` を優先。命令的呼び出しはユーザーアクション起因の場合のみ
3. エラーハンドリング: `reduceErrors` + `ShowToastEvent` で表示
4. `aria-label`, `aria-describedby` を適切に付与。SLDS準拠のマークアップを使用
5. CSSはコンポーネント固有 `.css` ファイルに記述。グローバルスタイル上書き禁止
6. 親子間通信は `CustomEvent`。兄弟間は `Lightning Message Service (LMS)`
7. 定数は `constants.js` に外出しして `import` で使用

## 禁止パターン

- `document.querySelector` 等の直接DOM操作 → `this.template.querySelector` を使用
- `setTimeout` / `setInterval` によるポーリング → Platform Events を使用
- `eval()` の使用
- インラインスタイル（`style` 属性）
- `@api` プロパティへの内部からの代入
```

### 6-3. test-coding.md

#### 配置先・適用条件

```
.github/instructions/test-coding.md
globs: ["*Test.cls"]
```

#### テンプレート

```markdown
---
description: "Apexテストクラスの作成・編集時に適用するルール"
globs: ["*Test.cls"]
---

# テストコーディングルール

## カバレッジ基準

- 全体カバレッジ: 75%以上（Salesforceデプロイ要件）
- 個別クラスカバレッジ: 80%以上を目標
- トリガカバレッジ: 100%を目標
- 重要ビジネスロジック: 90%以上を必須

## テストデータ作成ルール

1. 全テストクラスに `@isTest` を付与する
2. 共通テストデータは `@TestSetup` メソッドで作成する
3. `@isTest(SeeAllData=true)` は禁止
4. テストデータは `TestDataFactory` クラスで生成する
5. バリデーションルールを通過する正しい値を設定する
6. 全必須項目に値を設定する
7. 200件以上のレコードでバルクテストを含める
8. 異常系テスト（権限不足、不正データ、上限超過）を含める

## テスト実行ルール

1. 全 `System.assert` / `assertEquals` / `assertNotEquals` に第3引数（失敗メッセージ）を含める
2. テストメソッド名: `test[対象メソッド]_[シナリオ]` 形式
3. テスト間の依存関係を作らない（各テストメソッドは独立実行可能）
4. テスト内にハードコードのIDを使用しない
```

### 6-4. commit-rules.md

#### テンプレート

```markdown
---
description: "コミット・git操作を行う場合に適用するルール"
---

# コミットルール

## メッセージフォーマット

<type>(<scope>): <subject>

type: feat / fix / refactor / test / docs / chore / metadata
scope: 変更対象のSalesforceコンポーネント名またはオブジェクト名

例: feat(Account): 取引先の業種別バリデーションルールを追加

## コミット粒度

- 1コミット = 1論理変更単位
- Apexクラスとテストクラスは同一コミットに含める
- メタデータ変更とそれを使用するコードは同一コミットに含める
```

### 6-5. review-rules.md

#### テンプレート

```markdown
---
description: "コードレビューを行う場合に適用するルール"
---

# レビュールール

## Severity定義

| Severity | 定義 | 対応要否 |
|----------|------|---------|
| P1 (Critical) | 本番障害・データ破損・セキュリティ脆弱性 | 必須修正（デプロイブロッカー） |
| P2 (Major) | ガバナ制限違反リスク・パフォーマンス劣化 | 原則修正 |
| P3 (Minor) | コーディング規約違反・可読性の問題 | 推奨修正 |
| P4 (Info) | 改善提案・リファクタリング候補 | 任意 |

## ゲート通過条件

- P1指摘: 0件であること
- P2指摘: すべて対応済みであること
- P3指摘: 対応済みまたは対応方針が明記されていること

## deploy_recommendation 判定

| 判定 | 条件 |
|------|------|
| APPROVE | P1 = 0 かつ P2 = 0 |
| CONDITIONAL | P1 = 0 かつ P2 > 0 |
| BLOCK | P1 > 0 |
```

---

## 7. Skills定義テンプレート

skills/ には instructions/ で自動適用される基本ルールを超える詳細知識（判断フロー、コード例、検査スクリプト）を配置する。SKILL.md は **300行以内** を目標とし、超過する場合は `reference/` に分割する。

instructions/ に記載済みの基本ルール（ガバナ制限値、命名規約等）は skills/ では重複記載しない。

### 7-1. SKILL.md 共通構成テンプレート

```markdown
---
description: >
  （積極的なdescription — 指示的な文体。トリガーキーワードを含める。
  instructions/ で自動適用される基本ルールではなく、詳細な判断が必要な場面をトリガーにする。）
---

# スキル名

## 判断フロー
<!-- デシジョンツリー形式で「この状況 → このパターンを適用」 -->

## 検査スクリプトの使用方法（scripts/ がある場合）
<!-- 実行コマンドと出力の読み方 -->

## 代表的なパターン
<!-- instructions/ の基本ルールを踏まえた具体的な適用例 -->

## 詳細リファレンスへの誘導（必要時のみ参照）
<!-- 条件付きで reference/ 配下のファイルへ誘導 -->
```

### 7-2. salesforce-governor-limits SKILL.md

```markdown
---
description: >
  ガバナ制限の回避パターンやBatch/Queueable/Futureの選定が必要な場合に使用せよ。
  基本的な制限値は instructions/apex-coding.instructions.md で自動適用されるため、本スキルは
  「どのパターンで回避するか」の判断が必要な場面で参照すること。
  「Batchサイズ」「Queueable連鎖」「Too many SOQL queries」「System.LimitException」
  「パフォーマンス最適化」等のキーワードが出たら即座にロード。
  単純なSOQL構文の確認だけの場合は不要。
---

# ガバナ制限 — 判断フロー・回避パターン

## 処理方式の選定フロー

レコード数の見積もり
├─ 1-200件 → Trigger/Service で直接処理
├─ 200-10,000件 → Queueable で非同期処理
├─ 10,000件超 → Database.Batchable で分割処理
│   ├─ 外部連携あり → scope を Callout 制限（100件）に合わせる
│   └─ 外部連携なし → scope 200 を基本
└─ 不定期の大量処理 → Schedulable + Batchable

## 検査スクリプトの使用方法

bash .github/skills/salesforce-governor-limits/scripts/scan-governor-violations.sh force-app/

実装・レビュー時は、まずこのスクリプトで違反候補を特定し、各候補の修正方針を判断すること。

## 詳細リファレンスへの誘導

- Batchサイズの計算・非同期処理の全制限値 → `reference/async-limits.md`
- 同期トランザクションの全制限値一覧 → `reference/sync-limits.md`
```

### 7-3. salesforce-fls-security SKILL.md

```markdown
---
description: >
  FLS/CRUDチェックの具体的な使い分け判断が必要な場合に使用せよ。
  基本ルール（WITH USER_MODE原則等）は instructions/apex-coding.instructions.md で自動適用されるため、
  本スキルは「どのパターンを使うか」の詳細判断が必要な場面で参照すること。
  「WITH USER_MODE vs SECURITY_ENFORCED」「stripInaccessible の使い方」
  「セキュリティレビュー対策」等が出たら即座にロード。
---

# FLS/セキュリティ — 使い分け判断フロー

## データアクセスパターン選定フロー

├─ SOQL（静的クエリ）→ WITH USER_MODE（推奨）
├─ SOQL（動的クエリ）→ バインド変数必須 + WITH USER_MODE
├─ DML → Database.xxx(records, AccessLevel.USER_MODE)
└─ LWC → Lightning Data Service を優先。カスタムクエリは @AuraEnabled + FLSチェック

## 検査スクリプトの使用方法

bash .github/skills/salesforce-fls-security/scripts/scan-fls-compliance.sh force-app/

## 詳細リファレンスへの誘導

- WITH USER_MODE / SECURITY_ENFORCED / stripInaccessible の詳細コード例 → `reference/fls-patterns.md`
```

### 7-4. salesforce-bulk-patterns SKILL.md

```markdown
---
description: >
  バルク化パターンの具体的な適用方法やリファクタリング判断が必要な場合に使用せよ。
  基本原則（ループ内SOQL/DML禁止等）は instructions/apex-coding.instructions.md で自動適用されるため、
  本スキルは「どのバルク化パターンを適用するか」の選定・設計判断が必要な場面で参照すること。
  「N+1クエリの修正方法」「Map化パターンの適用」「Selectorパターン設計」「UnitOfWorkパターン」
  「トリガのバルク化リファクタリング」「コレクション操作の最適化」等のキーワードが出たら即座にロード。
  単純な「ループ内SOQLは禁止」の知識だけで済む場合は不要。
---

# バルク化パターン — 選定フロー・適用ガイド

## バルク化パターン選定フロー

### データ取得（SOQL）のバルク化

```
関連データの取得方法を選定:
├─ 単一オブジェクト → 呼び出し前に一括取得 + Map化
│   ├─ IDで引く → Map<Id, SObject>
│   └─ 外部キーで引く → Map<String, SObject>（外部ID/一意項目）
├─ 親→子の関連 → サブクエリ（Nested SOQL）
│   └─ SELECT Id, (SELECT Id FROM Contacts) FROM Account
├─ 子→親の関連 → リレーション参照（ドット表記）
│   └─ SELECT Id, Account.Name FROM Contact
└─ 複数オブジェクト横断 → Selector クラスに集約
    └─ AccountSelector.getByIdsWithContacts(accountIds)
```

### データ更新（DML）のバルク化

```
DML対象の蓄積方法を選定:
├─ 単一オブジェクトの更新 → List に蓄積 → ループ後に一括DML
├─ 複数オブジェクトの関連更新 → UnitOfWork パターン
│   ├─ 登録順序の依存関係あり → registerNew() で順序制御
│   └─ 依存関係なし → 各Listに蓄積 → 順次DML
└─ 部分成功を許容する場合 → Database.insert(records, false) + エラーハンドリング
```

## 代表的なパターン

### パターン1: Map化パターン（最頻出）

**Before（NG — ループ内SOQL）:**
```apex
for (Opportunity opp : Trigger.new) {
    // ❌ ループ内SOQL
    Account acc = [SELECT Id, Industry FROM Account WHERE Id = :opp.AccountId];
    if (acc.Industry == 'Technology') { /* ... */ }
}
```

**After（OK — Map化）:**
```apex
// ループ前に一括取得
Set<Id> accountIds = new Set<Id>();
for (Opportunity opp : Trigger.new) {
    accountIds.add(opp.AccountId);
}
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Industry FROM Account WHERE Id IN :accountIds]
);

// ループ内はMapから参照（SOQLなし）
for (Opportunity opp : Trigger.new) {
    Account acc = accountMap.get(opp.AccountId);
    if (acc != null && acc.Industry == 'Technology') { /* ... */ }
}
```

### パターン2: DML蓄積パターン

**Before（NG — ループ内DML）:**
```apex
for (Account acc : targetAccounts) {
    acc.Score__c = calculateScore(acc);
    // ❌ ループ内DML
    update acc;
}
```

**After（OK — List蓄積 + 一括DML）:**
```apex
List<Account> accountsToUpdate = new List<Account>();
for (Account acc : targetAccounts) {
    acc.Score__c = calculateScore(acc);
    accountsToUpdate.add(acc);
}
// ループ外で一括DML
if (!accountsToUpdate.isEmpty()) {
    update accountsToUpdate;
}
```

### パターン3: Selector パターン（SOQL集約）

```apex
public class AccountSelector {
    public static List<Account> getByIds(Set<Id> accountIds) {
        return [
            SELECT Id, Name, Industry, AnnualRevenue, Score__c
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ];
    }

    public static List<Account> getByIdsWithContacts(Set<Id> accountIds) {
        return [
            SELECT Id, Name, Industry,
                   (SELECT Id, Name, Email FROM Contacts)
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ];
    }

    public static Map<Id, Account> getMapByIds(Set<Id> accountIds) {
        return new Map<Id, Account>(getByIds(accountIds));
    }
}
```

### パターン4: UnitOfWork パターン（複数オブジェクトDML集約）

```apex
public class UnitOfWork {
    private List<SObject> newRecords = new List<SObject>();
    private List<SObject> updatedRecords = new List<SObject>();
    private List<SObject> deletedRecords = new List<SObject>();

    public void registerNew(SObject record) {
        newRecords.add(record);
    }

    public void registerDirty(SObject record) {
        updatedRecords.add(record);
    }

    public void registerDeleted(SObject record) {
        deletedRecords.add(record);
    }

    public void commitWork() {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!newRecords.isEmpty())     insert newRecords;
            if (!updatedRecords.isEmpty()) update updatedRecords;
            if (!deletedRecords.isEmpty()) delete deletedRecords;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
}
```

### パターン5: Trigger Handler のバルク化テンプレート

```apex
public class AccountTriggerHandler {

    public void handleAfterUpdate(
        List<Account> newList,
        Map<Id, Account> oldMap
    ) {
        List<Account> scoreChangedAccounts = new List<Account>();
        Set<Id> ownerIds = new Set<Id>();

        // 1. 対象レコードの絞り込み + 関連ID収集
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            if (acc.Score__c != oldAcc.Score__c) {
                scoreChangedAccounts.add(acc);
                ownerIds.add(acc.OwnerId);
            }
        }

        if (scoreChangedAccounts.isEmpty()) return;

        // 2. 関連データの一括取得
        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, Email, Name FROM User WHERE Id IN :ownerIds]
        );

        // 3. 処理実行（ループ内にSOQL/DMLなし）
        List<Task> tasksToInsert = new List<Task>();
        for (Account acc : scoreChangedAccounts) {
            User owner = ownerMap.get(acc.OwnerId);
            tasksToInsert.add(new Task(
                WhatId = acc.Id,
                OwnerId = acc.OwnerId,
                Subject = 'スコア変更確認: ' + acc.Name,
                Status = 'Not Started'
            ));
        }

        // 4. 一括DML
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}
```

## リファクタリング判断フロー

```
既存コードにガバナ制限違反の疑いがある場合:
│
├─ scan-governor-violations.sh を実行して違反候補を特定
│
├─ 違反箇所がトリガ内 →
│   ├─ ループ内SOQL → Map化パターン（パターン1）を適用
│   ├─ ループ内DML → DML蓄積パターン（パターン2）を適用
│   └─ 複数オブジェクトDML → UnitOfWorkパターン（パターン4）を適用
│
├─ 違反箇所がService層 →
│   ├─ 複数箇所で同じSOQL → Selectorパターン（パターン3）に集約
│   └─ 計算ロジック内のSOQL → 呼び出し元で事前取得してパラメータ渡し
│
└─ データ量増加による将来的なリスク →
    ├─ 現在は少量だが増加見込み → Batchable化を設計に組み込む
    └─ 件数が不定 → Queueable で動的にチェーン数を調整
```

## 詳細リファレンスへの誘導

- Trigger / Batch / Queueable の完全なバルク化コード例 → `reference/bulk-code-examples.md`
- ガバナ制限の具体値と回避パターン → `../salesforce-governor-limits/SKILL.md`
```

#### ディレクトリ構成

```
.github/skills/salesforce-bulk-patterns/
├── SKILL.md                        # 上記の内容（約250行）
└── reference/
    └── bulk-code-examples.md       # 以下の構成で詳細コード例を収録
```

#### reference/bulk-code-examples.md の構成

```markdown
# バルク化パターン — 詳細コード例リファレンス

## 1. Trigger バルク化の完全例

### 1.1 Before Insert — デフォルト値の一括設定
### 1.2 After Insert — 関連レコードの一括作成
### 1.3 Before Update — 変更検知 + 関連データ参照
### 1.4 After Update — 条件付き非同期処理の起動
### 1.5 Before Delete — 削除可否の一括チェック

## 2. Batch Apex のバルク化パターン

### 2.1 基本構成（Batchable + Schedulable）
### 2.2 外部連携を含む Batch（scope調整 + コールアウト）
### 2.3 チェーンBatch（Batch完了後に次のBatchを起動）
### 2.4 部分成功 + エラーログ記録パターン

## 3. Queueable のバルク化パターン

### 3.1 基本構成（単発Queueable）
### 3.2 チェーンQueueable（再帰的enqueue）
### 3.3 Queueable + Finalizer（エラー時リトライ）

## 4. コレクション操作の最適化

### 4.1 Set を使った重複排除
### 4.2 Map のマージ・フィルタリング
### 4.3 ネストMap（Map<Id, Map<String, Object>>）の活用
```

---

### 7-5. salesforce-lwc-patterns SKILL.md

```markdown
---
description: >
  LWCのデータアクセスパターン選定、コンポーネント間通信設計、またはパフォーマンス最適化の
  詳細判断が必要な場合に使用せよ。
  基本ルール（Wire優先、SLDS準拠等）は instructions/lwc-coding.instructions.md で自動適用されるため、
  本スキルは「どのパターンを使い分けるか」の具体的な判断が必要な場面で参照すること。
  「@wire vs imperative」「LDS vs カスタムApex」「子→親イベント通信」
  「Lightning Message Service」「データテーブルのページネーション」
  「コンポーネント分割設計」「SLDS レイアウト設計」等のキーワードが出たら即座にロード。
  単純なLWCの構文確認だけの場合は不要。
---

# LWC パターン — データアクセス・通信設計ガイド

## データアクセスパターン選定フロー

```
画面に表示するデータの取得方法を選定:
│
├─ 単一レコードの標準項目のみ →
│   └─ Lightning Data Service（LDS）
│       ├─ 参照のみ → lightning-record-view-form
│       ├─ 編集あり → lightning-record-edit-form
│       └─ プログラム制御 → getRecord / updateRecord（@wire）
│
├─ 単一レコード + カスタムロジック →
│   └─ @wire + Apex メソッド
│       └─ @AuraEnabled(cacheable=true) で取得
│
├─ 複数レコードの一覧表示 →
│   ├─ 標準リスト → lightning-datatable + @wire Apex
│   ├─ 検索付き一覧 → imperative Apex（ユーザー操作起点）
│   └─ 無限スクロール/ページネーション → カーソルベース + imperative
│
├─ ユーザー操作による更新 →
│   ├─ 標準DML → LDS updateRecord / createRecord
│   └─ カスタムロジック付きDML → imperative Apex
│       └─ @AuraEnabled(cacheable=false) で更新
│
└─ リアルタイム更新通知 →
    ├─ 同一レコードの変更検知 → getRecord の自動リフレッシュ
    ├─ 他ユーザーの変更通知 → emp API（Platform Event / CDC）
    └─ 他コンポーネントからの通知 → Lightning Message Service
```

## コンポーネント間通信パターン選定フロー

```
コンポーネント間のデータ受け渡し方法を選定:
│
├─ 親 → 子 →
│   └─ @api プロパティ（単方向データフロー）
│       └─ 子は受け取ったデータを直接変更しない（immutable原則）
│
├─ 子 → 親 →
│   └─ CustomEvent をディスパッチ
│       ├─ バブリングなし（直接の親のみ）→ bubbles: false（デフォルト）
│       └─ 祖先まで伝播 → bubbles: true, composed: true
│
├─ 兄弟コンポーネント →
│   ├─ 共通の親を経由 → 子A --CustomEvent--> 親 --@api--> 子B
│   └─ 親子関係なし → Lightning Message Service（LMS）
│
└─ 完全に独立したコンポーネント →
    └─ Lightning Message Service（LMS）
        ├─ メッセージチャネル定義（.messageChannel-meta.xml）
        ├─ publish() で送信
        └─ subscribe() で受信
```

## 代表的なパターン

### パターン1: @wire + Apex（キャッシュ有効な読み取り）

```javascript
import { LightningElement, api, wire } from 'lwc';
import getAccountScore from '@salesforce/apex/ScoreDashboardController.getAccountScore';

export default class AccountScoreCard extends LightningElement {
    @api recordId;
    score;
    error;

    @wire(getAccountScore, { accountId: '$recordId' })
    wiredScore({ data, error }) {
        if (data) {
            this.score = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.score = undefined;
        }
    }
}
```

### パターン2: Imperative Apex（ユーザー操作起点）

```javascript
import { LightningElement, api } from 'lwc';
import recalculateScore from '@salesforce/apex/ScoreDashboardController.recalculateScore';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ScoreRecalculator extends LightningElement {
    @api recordId;
    isLoading = false;

    async handleRecalculate() {
        this.isLoading = true;
        try {
            const result = await recalculateScore({ accountId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: '成功',
                message: `スコアが ${result.score} に更新されました`,
                variant: 'success'
            }));
            // 親コンポーネントに変更を通知
            this.dispatchEvent(new CustomEvent('scoreupdate', {
                detail: { score: result.score }
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'エラー',
                message: error.body?.message || '予期しないエラーが発生しました',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}
```

### パターン3: 親子通信（@api + CustomEvent）

```javascript
// 親コンポーネント（scoreContainer.js）
import { LightningElement, api } from 'lwc';

export default class ScoreContainer extends LightningElement {
    @api recordId;
    selectedGrade = 'ALL';

    handleFilterChange(event) {
        this.selectedGrade = event.detail.grade;
    }
}
```

```html
<!-- 親コンポーネント（scoreContainer.html） -->
<template>
    <c-score-filter onfilterchange={handleFilterChange}></c-score-filter>
    <c-score-list record-id={recordId} grade-filter={selectedGrade}></c-score-list>
</template>
```

```javascript
// 子コンポーネント（scoreFilter.js）
import { LightningElement } from 'lwc';

export default class ScoreFilter extends LightningElement {
    handleGradeSelect(event) {
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: { grade: event.target.value }
        }));
    }
}
```

### パターン4: エラーハンドリング統一パターン

```javascript
import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors } from 'c/ldsUtils';

export default class BaseComponent extends LightningElement {

    showError(error) {
        const messages = reduceErrors(error);
        this.dispatchEvent(new ShowToastEvent({
            title: 'エラー',
            message: messages.join(', '),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: '成功',
            message: message,
            variant: 'success'
        }));
    }
}
```

### パターン5: デバウンス付き検索入力

```javascript
import { LightningElement } from 'lwc';
import searchAccounts from '@salesforce/apex/AccountSearchController.search';

const DEBOUNCE_DELAY = 300;

export default class AccountSearch extends LightningElement {
    searchTerm = '';
    results = [];
    isLoading = false;
    _debounceTimer;

    handleSearchInput(event) {
        clearTimeout(this._debounceTimer);
        this.searchTerm = event.target.value;

        if (this.searchTerm.length < 2) {
            this.results = [];
            return;
        }

        this._debounceTimer = setTimeout(() => {
            this.performSearch();
        }, DEBOUNCE_DELAY);
    }

    async performSearch() {
        this.isLoading = true;
        try {
            this.results = await searchAccounts({ searchTerm: this.searchTerm });
        } catch (error) {
            this.results = [];
        } finally {
            this.isLoading = false;
        }
    }
}
```

## コンポーネント分割の判断基準

```
コンポーネントを分割すべきか判断:
│
├─ HTML が 200行を超える → 分割を検討
├─ 独立して再利用できるUI部品がある → 子コンポーネントに分離
├─ 異なる更新頻度のセクションがある → 分割して再レンダリング範囲を限定
├─ テスト容易性を高めたい → ロジックを持つ部分を分離
└─ 上記いずれにも該当しない → 分割不要（過度な分割は複雑性を増す）
```

## 詳細リファレンスへの誘導

- LDS / @wire / imperative / LMS の詳細コード例 → `reference/lwc-code-examples.md`
- LWCパフォーマンス方針 → `docs/architecture/policies/performance-policy.md` セクション5
```

#### ディレクトリ構成

```
.github/skills/salesforce-lwc-patterns/
├── SKILL.md                        # 上記の内容（約250行）
└── reference/
    └── lwc-code-examples.md        # 以下の構成で詳細コード例を収録
```

#### reference/lwc-code-examples.md の構成

```markdown
# LWC パターン — 詳細コード例リファレンス

## 1. データアクセスパターンの完全例

### 1.1 Lightning Data Service（レコードビュー/編集フォーム）
### 1.2 getRecord / updateRecord によるプログラム制御
### 1.3 @wire Apex — リアクティブパラメータ付き
### 1.4 Imperative Apex — CRUD操作一式
### 1.5 ページネーション（カーソルベース）

## 2. コンポーネント間通信の完全例

### 2.1 親子間の双方向通信（@api + CustomEvent）
### 2.2 Lightning Message Service（LMS）のpublish/subscribe
### 2.3 emp API による Platform Event 受信

## 3. UI パターンの完全例

### 3.1 lightning-datatable（ソート・インライン編集付き）
### 3.2 モーダルダイアログ（lightning-modal）
### 3.3 動的コンポーネント生成
### 3.4 ドラッグ&ドロップ

## 4. エラーハンドリング・ユーティリティ

### 4.1 reduceErrors ユーティリティ
### 4.2 ローディング・空状態の表示パターン
### 4.3 権限チェック（@wire getObjectInfo / @salesforce/userPermission）
```

---

### 7-6. salesforce-test-patterns SKILL.md

```markdown
---
description: >
  テストクラスの設計パターン選定、テストデータ戦略、または複雑なテストシナリオの実装が
  必要な場合に使用せよ。
  基本ルール（@TestSetup必須、SeeAllData禁止等）は instructions/test-coding.instructions.md で
  自動適用されるため、本スキルは「どのテストパターンを使い分けるか」「テストデータをどう構築するか」
  の詳細判断が必要な場面で参照すること。
  「テストデータファクトリの設計」「モックの実装方法」「HttpCalloutMock」
  「バルクテストの件数設計」「非同期テスト（Test.startTest/stopTest）」
  「権限テスト（System.runAs）」「複合シナリオテスト」等のキーワードが出たら即座にロード。
  単純なテストクラスの構文確認だけの場合は不要。
---

# テストパターン — 設計・実装ガイド

## テスト種別の選定フロー

```
テスト対象に応じてテスト種別を選定:
│
├─ Apex クラス / トリガ →
│   ├─ 正常系テスト（必須）
│   │   ├─ 単一レコード → 基本的な入出力検証
│   │   └─ バルク（200件以上）→ ガバナ制限内での動作検証
│   ├─ 異常系テスト（必須）
│   │   ├─ バリデーションルール違反 → DmlException の検証
│   │   ├─ 必須項目未入力 → エラーメッセージの検証
│   │   └─ 権限不足 → System.runAs でプロファイル切替
│   ├─ 境界値テスト（推奨）
│   │   ├─ 数値項目の最大/最小値
│   │   └─ 文字列項目の最大長
│   └─ セキュリティテスト（推奨）
│       ├─ FLS違反 → 権限なしユーザーでのアクセス試行
│       └─ 共有ルール → レコードアクセス不可ユーザーでの操作試行
│
├─ 外部連携（Callout）→
│   ├─ HttpCalloutMock 実装（必須）
│   │   ├─ 正常レスポンス → 200 / 201
│   │   ├─ エラーレスポンス → 400 / 401 / 500
│   │   └─ タイムアウト → CalloutException
│   └─ Test.startTest() / Test.stopTest() で非同期実行
│
├─ Batch / Queueable / Schedulable →
│   ├─ Test.startTest() / Test.stopTest() で囲む（必須）
│   ├─ Batch → Database.executeBatch + 完了後のデータ検証
│   ├─ Queueable → System.enqueueJob + 完了後のデータ検証
│   └─ Schedulable → cron式でスケジュール登録の検証
│
└─ LWC コントローラ →
    ├─ @AuraEnabled メソッドの直接テスト
    └─ 例外発生時の AuraHandledException の検証
```

## テストデータ戦略

### TestDataFactory の設計方針

```
テストデータの作成方法を選定:
│
├─ 共通のマスタデータ → @TestSetup で一括作成
│   └─ TestDataFactory.createStandardData() を呼び出し
│
├─ テスト固有のデータ → 各テストメソッド内で作成
│   └─ TestDataFactory.createAccount(overrides) でパラメータ上書き
│
├─ 大量データ → TestDataFactory.createAccounts(count) で一括生成
│   └─ バルクテストには200件以上を使用
│
└─ 外部連携データ → HttpCalloutMock / StaticResource で模擬
```

### TestDataFactory の実装パターン

```apex
@IsTest
public class TestDataFactory {

    // === Account ===
    public static Account createAccount() {
        return createAccount(new Map<String, Object>());
    }

    public static Account createAccount(Map<String, Object> overrides) {
        Account acc = new Account(
            Name = 'Test Account',
            Industry = 'Technology',
            AnnualRevenue = 1000000
        );
        applyOverrides(acc, overrides);
        insert acc;
        return acc;
    }

    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology'
            ));
        }
        insert accounts;
        return accounts;
    }

    // === Opportunity ===
    public static Opportunity createOpportunity(Id accountId) {
        return createOpportunity(accountId, new Map<String, Object>());
    }

    public static Opportunity createOpportunity(
        Id accountId,
        Map<String, Object> overrides
    ) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 50000
        );
        applyOverrides(opp, overrides);
        insert opp;
        return opp;
    }

    // === ユーティリティ ===
    public static User createUserWithProfile(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueKey = String.valueOf(Datetime.now().getTime());
        User u = new User(
            FirstName = 'Test',
            LastName = 'User ' + uniqueKey,
            Email = 'test' + uniqueKey + '@example.com',
            Username = 'test' + uniqueKey + '@example.com.test',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Tokyo',
            LocaleSidKey = 'ja_JP',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'ja',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    private static void applyOverrides(SObject record, Map<String, Object> overrides) {
        for (String field : overrides.keySet()) {
            record.put(field, overrides.get(field));
        }
    }
}
```

## 代表的なテストパターン

### パターン1: @TestSetup + 正常系/異常系テスト

```apex
@IsTest
private class AccountScoringServiceTest {

    @TestSetup
    static void setup() {
        // 共通テストデータ
        Account acc = TestDataFactory.createAccount(new Map<String, Object>{
            'Industry' => 'Technology',
            'AnnualRevenue' => 5000000
        });
        TestDataFactory.createOpportunity(acc.Id);
    }

    @IsTest
    static void calculateScore_validAccount_returnsExpectedScore() {
        // Arrange
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Act
        Test.startTest();
        Decimal score = AccountScoringService.calculateScore(acc.Id);
        Test.stopTest();

        // Assert
        Assert.isNotNull(score, 'スコアがnullであってはならない');
        Assert.isTrue(score >= 0 && score <= 100, 'スコアは0-100の範囲であること');
    }

    @IsTest
    static void calculateScore_noActivities_returnsZero() {
        // Arrange — 活動なしのAccount
        Account acc = TestDataFactory.createAccount(new Map<String, Object>{
            'Name' => 'No Activity Account'
        });

        // Act
        Test.startTest();
        Decimal score = AccountScoringService.calculateScore(acc.Id);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, score, '活動がないAccountのスコアは0であること');
    }

    @IsTest
    static void calculateScore_invalidId_throwsException() {
        // Arrange
        Id fakeId = TestUtility.getFakeId(Account.SObjectType);

        // Act & Assert
        try {
            Test.startTest();
            AccountScoringService.calculateScore(fakeId);
            Test.stopTest();
            Assert.fail('例外がスローされるべき');
        } catch (BusinessException e) {
            Assert.isTrue(
                e.getMessage().contains('取引先が見つかりません'),
                'エラーメッセージに原因が含まれること'
            );
        }
    }
}
```

### パターン2: バルクテスト

```apex
@IsTest
static void calculateScore_bulk200_completesWithinLimits() {
    // Arrange — 200件のAccount
    List<Account> accounts = TestDataFactory.createAccounts(200);
    Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

    // Act
    Test.startTest();
    AccountScoringService.calculateScores(accountIds);
    Test.stopTest();

    // Assert — ガバナ制限内で完了していることを暗黙的に検証
    List<Account> updatedAccounts = [
        SELECT Id, Score__c FROM Account WHERE Id IN :accountIds
    ];
    Assert.areEqual(200, updatedAccounts.size(), '全200件が処理されていること');
    for (Account acc : updatedAccounts) {
        Assert.isNotNull(acc.Score__c, 'すべてのAccountにスコアが設定されていること');
    }
}
```

### パターン3: HttpCalloutMock（外部連携テスト）

```apex
@IsTest
private class CreditCheckServiceTest {

    // Mockクラス
    private class CreditCheckMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        CreditCheckMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @IsTest
    static void checkCredit_successResponse_returnsScore() {
        // Arrange
        String mockBody = '{"score": 85, "grade": "A"}';
        Test.setMock(HttpCalloutMock.class, new CreditCheckMock(200, mockBody));

        // Act
        Test.startTest();
        CreditCheckResult result = CreditCheckService.checkCredit('ACC-001');
        Test.stopTest();

        // Assert
        Assert.areEqual(85, result.score);
        Assert.areEqual('A', result.grade);
    }

    @IsTest
    static void checkCredit_serverError_throwsIntegrationException() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new CreditCheckMock(500, ''));

        // Act & Assert
        try {
            Test.startTest();
            CreditCheckService.checkCredit('ACC-001');
            Test.stopTest();
            Assert.fail('IntegrationExceptionがスローされるべき');
        } catch (IntegrationException e) {
            Assert.isTrue(e.getMessage().contains('500'));
        }
    }
}
```

### パターン4: 権限テスト（System.runAs）

```apex
@IsTest
static void viewScore_readOnlyUser_canViewScore() {
    // Arrange
    Account acc = [SELECT Id FROM Account LIMIT 1];
    User readOnlyUser = TestDataFactory.createUserWithProfile('Standard User');

    // 権限セットを付与
    PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'PS_ScoreViewer'];
    insert new PermissionSetAssignment(
        AssigneeId = readOnlyUser.Id,
        PermissionSetId = ps.Id
    );

    // Act & Assert
    System.runAs(readOnlyUser) {
        Test.startTest();
        Account result = [
            SELECT Id, Score__c FROM Account
            WHERE Id = :acc.Id
            WITH USER_MODE
        ];
        Test.stopTest();
        Assert.isNotNull(result.Score__c, '閲覧権限を持つユーザーはスコアを参照できること');
    }
}

@IsTest
static void editScore_readOnlyUser_throwsException() {
    // Arrange
    Account acc = [SELECT Id, Score__c FROM Account LIMIT 1];
    User readOnlyUser = TestDataFactory.createUserWithProfile('Read Only');

    // Act & Assert
    System.runAs(readOnlyUser) {
        try {
            acc.Score__c = 99;
            update acc;
            Assert.fail('編集権限なしユーザーはスコアを更新できないはず');
        } catch (DmlException e) {
            Assert.isTrue(
                e.getMessage().contains('INSUFFICIENT_ACCESS')
                || e.getMessage().contains('FIELD_INTEGRITY_EXCEPTION'),
                '権限不足のエラーが返されること'
            );
        }
    }
}
```

## テストメソッド命名規約

```
{テスト対象メソッド}_{条件}_{期待結果}

例:
calculateScore_validAccount_returnsExpectedScore
calculateScore_noActivities_returnsZero
calculateScore_invalidId_throwsException
calculateScore_bulk200_completesWithinLimits
checkCredit_serverError_throwsIntegrationException
viewScore_readOnlyUser_canViewScore
```

## テスト設計チェックリスト

```
テスト作成時に以下を確認:
│
├─ テストデータ
│   ├─ @TestSetup を使用しているか
│   ├─ SeeAllData=true を使用していないか（禁止）
│   ├─ ハードコードIDを使用していないか（禁止）
│   └─ TestDataFactory を使用しているか
│
├─ テストカバレッジ
│   ├─ 正常系テスト → 全メインパスをカバー
│   ├─ 異常系テスト → 例外・バリデーション違反をカバー
│   ├─ バルクテスト → 200件以上でのバルク動作を検証
│   └─ セキュリティテスト → FLS/共有ルールの遵守を検証
│
├─ Assertの品質
│   ├─ 各テストメソッドに最低1つの Assert があるか
│   ├─ Assert にメッセージ（第3引数）を付与しているか
│   └─ 戻り値だけでなく副作用（DB変更等）も検証しているか
│
└─ 非同期テスト
    ├─ Test.startTest() / Test.stopTest() を使用しているか
    ├─ Batch → executeBatch 後の stopTest でデータ検証
    └─ Callout → Test.setMock を設定しているか
```

## 詳細リファレンスへの誘導

- 正常系/異常系/バルク/セキュリティテストの完全コード例 → `reference/test-code-examples.md`
- テストコーディング基本ルール → `instructions/test-coding.instructions.md`（自動適用）
- エラーハンドリングのテスト方針 → `docs/architecture/policies/error-handling-policy.md`
```

#### ディレクトリ構成

```
.github/skills/salesforce-test-patterns/
├── SKILL.md                        # 上記の内容（約280行）
└── reference/
    └── test-code-examples.md       # 以下の構成で詳細コード例を収録
```

#### reference/test-code-examples.md の構成

```markdown
# テストパターン — 詳細コード例リファレンス

## 1. テストデータ構築パターン

### 1.1 TestDataFactory の完全実装例
### 1.2 @TestSetup の設計パターン（単純/複合シナリオ）
### 1.3 カスタムメタデータ型のテストデータ構築
### 1.4 StaticResource を使ったテストデータ

## 2. 正常系テストの完全例

### 2.1 トリガテスト（Before/After の各イベント）
### 2.2 Serviceクラステスト
### 2.3 Selectorクラステスト
### 2.4 LWCコントローラテスト

## 3. 異常系テストの完全例

### 3.1 バリデーションルール違反テスト
### 3.2 カスタム例外テスト
### 3.3 AuraHandledException テスト
### 3.4 ガバナ制限超過テスト

## 4. バルクテストの完全例

### 4.1 Trigger バルクテスト（200件 insert/update/delete）
### 4.2 Batch Apex テスト
### 4.3 Queueable テスト

## 5. セキュリティテストの完全例

### 5.1 FLS テスト（WITH USER_MODE 検証）
### 5.2 共有ルールテスト（with sharing 検証）
### 5.3 プロファイル別アクセステスト

## 6. 外部連携テストの完全例

### 6.1 単一エンドポイント Mock
### 6.2 マルチエンドポイント Mock（MultiStaticResourceCalloutMock）
### 6.3 コールアウトリトライのテスト
### 6.4 Queueable + Callout の組合せテスト
```

### 7-7. Skills管理ポリシー

| 項目 | ルール |
|------|------|
| コードレビュー対象 | `.github/skills/` に追加するスキルはすべてコードレビュー対象とする |
| 外部スキルの監査 | 外部ソースからのスキル導入時は、SKILL.md・スクリプト・reference の内容を監査すること |
| 行数制限 | SKILL.md は 300行以内。超過する場合は `reference/` に分割する |
| instructions/ との重複禁止 | instructions/ で自動適用される基本ルールは skills/ に再掲しない |
| description の品質 | 積極的な記述を維持し、定期的にテストプロンプトで発火精度を確認する |
| スクリプトの冪等性 | `scripts/` 配下は何度実行しても同じ結果を返すこと |

---

## 補足: 設定ファイルの全体配置マップ

全ての設定ファイルの配置先を一覧で示す。

```
<project-root>/
├── AGENTS.md                                    # プロジェクトルート設定（セクション1・軽量版）
├── .github/
│   ├── settings.json                            # パーミッション・Hook設定（セクション3, 4）
│   ├── agents/                                  # サブエージェント定義（02_subagent_definitions.md 参照）
│   │   ├── sf-metadata-analyst.md
│   │   ├── sf-requirements-analyst.md
│   │   ├── sf-designer.md
│   │   ├── sf-implementer.md
│   │   ├── sf-tester.md
│   │   └── sf-code-reviewer.md
│   ├── instructions/                                   # 条件付き自動適用ルール（セクション6）
│   │   ├── apex-coding.md
│   │   ├── lwc-coding.md
│   │   ├── test-coding.md
│   │   ├── commit-rules.md
│   │   └── review-rules.md
│   └── skills/                                  # 詳細ドメイン知識（セクション7）
│       ├── salesforce-governor-limits/
│       │   ├── SKILL.md
│       │   ├── reference/
│       │   └── scripts/
│       ├── salesforce-fls-security/
│       │   ├── SKILL.md
│       │   ├── reference/
│       │   └── scripts/
│       ├── salesforce-bulk-patterns/
│       │   ├── SKILL.md
│       │   └── reference/
│       ├── salesforce-lwc-patterns/
│       │   ├── SKILL.md
│       │   └── reference/
│       └── salesforce-test-patterns/
│           ├── SKILL.md
│           └── reference/
├── force-app/
│   ├── AGENTS.md                                # force-app配下設定（セクション2）
│   └── main/default/
│       ├── classes/
│       ├── triggers/
│       ├── lwc/
│       └── ...
├── scripts/
│   ├── setup-project.sh                         # 案件セットアップ（セクション5-1）
│   ├── update-phase.sh                          # フェーズ更新（セクション5-3）
│   └── list-projects.sh                         # 案件一覧（セクション5-4）
├── docs/
│   ├── architecture/                                # システムレベル（全案件共通）
│   │   ├── system-context.md
│   │   ├── decisions/
│   │   │   ├── _template.md
│   │   │   └── ADR-001_xxx.md
│   │   └── policies/
│   │       ├── integration-policy.md
│   │       ├── security-policy.md
│   │       ├── performance-policy.md
│   │       ├── error-handling-policy.md
│   │       └── naming-convention-policy.md
│   └── projects/                                    # 案件別ドキュメント（案件数分増加）
│       ├── index.json                               # 全案件一覧（セクション5-4参照）
│       └── {{PROJECT_ID}}/
│           ├── project-config.json                  # 案件設定（セクション5-2）
│           ├── requirements/
│           │   ├── user_requirements.md              # ユーザー要件書（インプット）
│           │   └── requirements_specification.md     # 要件定義書（エージェント出力）
│           ├── design/
│           │   ├── data_model_design.md
│           │   ├── apex_design.md
│           │   ├── lwc_design.md
│           │   ├── flow_design.md
│           │   └── implementation_plan.md
│           ├── test-results/
│           │   └── test_report.md
│           └── review/
│               ├── review_report.json
│               ├── review_report.md
│               └── pr_description.md
├── package.json                                 # prettier-plugin-apex 依存関係
└── .prettierrc                                  # Apex フォーマット設定
```

---

## テンプレート変数一覧

各テンプレートで使用されるプレースホルダの一覧。案件セットアップ時に実際の値に置換する。

| 変数名 | 説明 | 例 |
|---|---|---|
| `{{PROJECT_ID}}` | 案件の一意識別子 | `PRJ-001` |
| `{{PROJECT_NAME}}` | 案件の表示名 | `取引先管理機能の拡張` |
| `{{ORG_ALIAS}}` | Salesforce組織のエイリアス | `my-sandbox` |
| `{{INSTANCE_URL}}` | Salesforce組織のURL | `https://my-sandbox.sandbox.my.salesforce.com` |
| `{{SCOPE_DESCRIPTION}}` | 開発範囲の概要説明 | `取引先・商談の業務プロセス改善` |
| `{{START_DATE}}` | 案件開始日 | `2026-03-09` |
| `{{OWNER_NAME}}` | 主担当者名 | `山田太郎` |
