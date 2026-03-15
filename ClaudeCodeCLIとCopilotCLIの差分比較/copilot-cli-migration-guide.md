# Salesforce マルチエージェント開発フレームワーク — GitHub Copilot CLI 移行設計書

> 本ドキュメントは、Claude Code CLI のサブエージェントパターンで構築された Salesforce 開発フレームワーク（全7フェーズ・6サブエージェント構成）を、GitHub Copilot CLI で実現するための移行設計を記述する。

---

## 1. エグゼクティブサマリー

### 1.1 移行の前提

現行フレームワークは Claude Code CLI 固有の以下の機構に依存している。

| 機構 | Claude Code CLI | GitHub Copilot CLI |
|------|----------------|-------------------|
| サブエージェント定義 | `.claude/agents/*.md`（YAML frontmatter + 本文） | `.github/agents/*.agent.md` または `.copilot/agents/*.agent.md` |
| 条件付きルール自動適用 | `.claude/rules/*.md`（globs パターンマッチ） | `.github/instructions/*.instructions.md`（globs パターンマッチ） |
| ドメイン知識の遅延ロード | `.claude/skills/*/SKILL.md` | `.github/skills/*/SKILL.md`（同一仕様・互換） |
| フック（ツール実行前後処理） | `.claude/settings.json` 内 `hooks` | `.github/hooks/*.json`（ファイル分離型） |
| プロジェクト全体指示 | `CLAUDE.md`（自動読み込み） | `AGENTS.md` または `.github/copilot-instructions.md` |
| パーミッション管理 | `.claude/settings.json` の `allow` / `deny` | `copilot.json` または `--allow-tool` / Hook の `preToolUse` |
| コンテキスト圧縮 | `/compact` コマンド | 自動コンパクション（95%到達時に自動実行） |
| モデル選択 | リード=Opus 4.6、サブ=Sonnet | `/model` で切替。Claude Opus 4.6 / Sonnet 4.6 利用可能 |
| 並列サブエージェント | 非対応（逐次のみ） | `/fleet` で並列実行可能 |

### 1.2 移行の全体方針

Copilot CLI は Claude Code CLI とほぼ同等のカスタマイズ機構（カスタムエージェント、Skills、Hooks、Instructions）を備えており、**フレームワークの全フェーズを移行可能**である。ただし、設定ファイルの配置先・フォーマット・コマンド体系が異なるため、ディレクトリ構成とファイル形式の変換が必要になる。

主な差異と対応方針は以下の通り。

1. **サブエージェント定義**: `.agent.md` 形式に変換。`tools` フィールドで利用ツールを制御
2. **ルール→Instructions**: `*.instructions.md` に変換。`applyTo` パターンで適用対象を指定
3. **Skills**: ほぼそのまま移行可能（互換仕様）。配置先を `.github/skills/` に変更
4. **Hooks**: JSON ファイルに分離し `.github/hooks/` に配置
5. **CLAUDE.md → AGENTS.md**: プロジェクト全体の指示を `AGENTS.md` に統合
6. **ヒューマンゲート**: Copilot CLI のインタラクティブモードのターン制対話で同等に実現可能
7. **コンテキスト管理**: 自動コンパクションに依存しつつ、必要時に `/compact` 手動実行

---

## 2. ディレクトリ構成のマッピング

### 2.1 変換マップ

```
Claude Code CLI                          GitHub Copilot CLI
─────────────────────────────────        ─────────────────────────────────
.claude/                                 .github/                          (※1)
├── agents/                              ├── agents/
│   ├── sf-metadata-analyst.md           │   ├── sf-metadata-analyst.agent.md
│   ├── sf-requirements-analyst.md       │   ├── sf-requirements-analyst.agent.md
│   ├── sf-designer.md                   │   ├── sf-designer.agent.md
│   ├── sf-implementer.md                │   ├── sf-implementer.agent.md
│   ├── sf-tester.md                     │   ├── sf-tester.agent.md
│   └── sf-code-reviewer.md              │   └── sf-code-reviewer.agent.md
│                                        │
├── rules/                               ├── instructions/
│   ├── apex-coding.md                   │   ├── apex-coding.instructions.md
│   ├── lwc-coding.md                    │   ├── lwc-coding.instructions.md
│   ├── test-coding.md                   │   ├── test-coding.instructions.md
│   ├── commit-rules.md                  │   ├── commit-rules.instructions.md
│   └── review-rules.md                  │   └── review-rules.instructions.md
│                                        │
├── skills/                              ├── skills/
│   ├── salesforce-governor-limits/      │   ├── salesforce-governor-limits/
│   │   ├── SKILL.md                     │   │   ├── SKILL.md               (互換)
│   │   ├── reference/                   │   │   ├── reference/
│   │   └── scripts/                     │   │   └── scripts/
│   └── ...                              │   └── ...
│                                        │
├── settings.json                        ├── hooks/
│   (permissions + hooks 統合)            │   ├── post-deploy-check.json
│                                        │   └── pre-commit-lint.json
└── projects/                            │
    └── {PID}/config.yaml                ├── copilot-instructions.md        (※2)
                                         └── copilot.json                   (※3)

CLAUDE.md                                AGENTS.md                          (※4)
force-app/CLAUDE.md                      force-app/.github/copilot-instructions.md
```

**注記:**
- ※1: Copilot CLI は `.github/` と `.copilot/` の両方を探索する。`.github/` がリポジトリ標準に適合
- ※2: プロジェクト全体の Instructions（CLAUDE.md に相当する基本指示の一部）
- ※3: ツール許可/拒否の設定（settings.json の permissions に相当）
- ※4: リポジトリルートの `AGENTS.md` は Copilot が自動読み込みする（CLAUDE.md の役割を代替）

### 2.2 変更のないディレクトリ

以下はツール非依存のため変更不要。

```
metadata-catalog/          → そのまま
docs/architecture/         → そのまま
docs/projects/             → そのまま
scripts/                   → setup-project.sh 等のツール参照パスを修正
force-app/                 → そのまま
```

---

## 3. 設定ファイルの変換

### 3.1 CLAUDE.md → AGENTS.md

プロジェクトルートの `CLAUDE.md` は `AGENTS.md` に変換する。Copilot CLI はリポジトリルートの `AGENTS.md` を自動的にコンテキストへ読み込む。

**変換ポイント:**
- YAML frontmatter は不要（Copilot CLI は `AGENTS.md` を純粋な Markdown として処理する）
- コーディングルール参照先を `.github/instructions/` に変更
- サブエージェント参照先を `.github/agents/` に変更
- Skills 参照先を `.github/skills/` に変更
- Copilot CLI 固有のコマンド（`/agent`、`/model`、`/compact`）を案内

```markdown
# AGENTS.md — プロジェクトルート設定

## プロジェクト概要

- **案件名**: {{PROJECT_NAME}}
- **案件ID**: {{PROJECT_ID}}
- **対象Salesforce組織**: {{ORG_ALIAS}}（{{INSTANCE_URL}}）
- **開発範囲**: {{SCOPE_DESCRIPTION}}

## コーディングルールの配置先

Salesforce開発のコーディングルールは `.github/instructions/` に配置。
ファイル操作時に `applyTo` パターンで自動適用されるため、ここには記載しない。

| ルールファイル | 適用条件 | 主な内容 |
|---|---|---|
| `.github/instructions/apex-coding.instructions.md` | `**/*.cls`, `**/*.trigger` | ガバナ制限値、FLS、バルク化 |
| `.github/instructions/lwc-coding.instructions.md` | `**/lwc/**` | Wire優先、SLDS準拠 |
| `.github/instructions/test-coding.instructions.md` | `**/*Test.cls` | @TestSetup、カバレッジ基準 |
| `.github/instructions/commit-rules.instructions.md` | (コミット操作時) | メッセージフォーマット |
| `.github/instructions/review-rules.instructions.md` | (レビュー作業時) | Severity定義、ゲート通過条件 |

## メタデータカタログ

- **スキーマ情報**: metadata-catalog/schema/
- **カタログ情報**: metadata-catalog/catalog/
- ※ 実装・設計時は必ずカタログを参照すること

## サブエージェント利用ガイドライン

### 利用可能なサブエージェント

| エージェント名 | 呼び出し方 | 呼び出しタイミング |
|---|---|---|
| `sf-metadata-analyst` | `/agent sf-metadata-analyst` | Phase 0, Phase 2 |
| `sf-requirements-analyst` | `/agent sf-requirements-analyst` | Phase 1 |
| `sf-designer` | `/agent sf-designer` | Phase 2 |
| `sf-implementer` | `/agent sf-implementer` | Phase 3 |
| `sf-tester` | `/agent sf-tester` | Phase 4 |
| `sf-code-reviewer` | `/agent sf-code-reviewer` | Phase 5 |

Copilot はプロンプトの内容に応じて自動的に適切なエージェントに委任する。
明示的に呼び出す場合は `/agent` コマンドを使用するか、
プロンプト内で「sf-metadata-analyst を使って…」のように指示する。

### コンテキスト管理

1. Copilot CLI は 95% 到達時に自動コンパクションを実行する
2. 手動で圧縮が必要な場合は `/compact` を実行
3. 中間成果物は `docs/projects/` に保存し、後続フェーズで参照する

## 禁止事項

- 本番組織への直接デプロイ禁止
- 旧 `sfdx` コマンドの使用禁止（`sf` v2 を使用すること）
```

### 3.2 rules/ → instructions/

Claude Code の `rules/*.md` は、Copilot CLI の `instructions/*.instructions.md` に変換する。YAML frontmatter のフィールド名が異なる。

**Claude Code（変換前）:**
```markdown
---
description: "Apexクラス・トリガの作成・編集時に適用するルール"
globs: ["*.cls", "*.trigger"]
---
# Apexコーディングルール
...
```

**Copilot CLI（変換後）:**
```markdown
---
description: "Apexクラス・トリガの作成・編集時に適用するルール"
applyTo: "**/*.cls,**/*.trigger"
---
# Apexコーディングルール
...
```

**変換ルール:**
- `globs` → `applyTo`（カンマ区切り文字列）
- glob パターンに `**/` プレフィクスを付与（リポジトリ全体で再帰マッチ）
- 本文（ルール内容）は変更不要

### 3.3 agents/ のファイル形式変換

Claude Code の `agents/*.md` は、Copilot CLI の `agents/*.agent.md` に変換する。

**Claude Code（変換前）:**
```markdown
---
name: sf-metadata-analyst
description: >
  Salesforce組織のメタデータを取得・構造化する際に呼び出す。...
model: sonnet
tools:
  - Read
  - Bash
  - Grep
  - Glob
---
あなたはSalesforceメタデータ分析の専門家です。...
```

**Copilot CLI（変換後）:**
```markdown
---
name: sf-metadata-analyst
description: >
  Salesforce組織のメタデータを取得・構造化する際に呼び出す。
  sf project retrieve startによるメタデータ取得、ER図相当の構造化サマリ生成、
  オブジェクト間リレーション分析を実行する。
  入力: 対象組織のエイリアスまたはsfdx-project.json。
  出力: メタデータサマリ（Markdown構造化ドキュメント）。
tools:
  - read_file
  - edit_file
  - run_terminal_command
  - search_files
  - list_directory
---

あなたはSalesforceメタデータ分析の専門家です。対象組織からメタデータを取得し、
AIエージェントが後続フェーズで効率的に参照できる構造化ドキュメントを生成します。

## コーディングルールの適用について

- Apex/LWCの基本ルール（ガバナ制限値、FLS、バルク化等）は
  `.github/instructions/` で自動適用されるため、本定義には含めない
- 詳細なパターンが必要な場合は `.github/skills/salesforce-governor-limits/` を参照
- `sf` コマンド（v2）を使用すること。旧 `sfdx` コマンドは使用禁止

（以降、本文は同一内容。パス参照のみ `.claude/` → `.github/` に置換）
```

**主な変換ポイント:**

| フィールド | Claude Code | Copilot CLI |
|-----------|------------|-------------|
| ファイル拡張子 | `.md` | `.agent.md` |
| `model` | `sonnet` | 削除（Copilot CLI 側で `/model` で選択） |
| `tools` の値 | `Read`, `Bash`, `Edit`, `Write`, `Grep`, `Glob` | `read_file`, `run_terminal_command`, `edit_file`, `write_new_file`, `search_files`, `list_directory` |

**ツール名の変換マトリクス:**

| Claude Code | Copilot CLI | 備考 |
|------------|-------------|------|
| `Read` | `read_file` | ファイル読み取り |
| `Edit` | `edit_file` | 既存ファイル編集 |
| `Write` | `write_new_file` | 新規ファイル作成 |
| `Bash` | `run_terminal_command` | シェルコマンド実行 |
| `Grep` | `search_files` | テキスト検索 |
| `Glob` | `list_directory` | ファイル一覧 |

### 3.4 settings.json → copilot.json + hooks/

Claude Code の `settings.json` は、Copilot CLI では **2つのファイル** に分離する。

#### 3.4.1 パーミッション → copilot.json

```json
{
  "tools": {
    "allowed": [
      "run_terminal_command:sf project:*",
      "run_terminal_command:sf apex:*",
      "run_terminal_command:sf org:display",
      "run_terminal_command:sf org:list",
      "run_terminal_command:git add:*",
      "run_terminal_command:git commit:*",
      "run_terminal_command:git checkout:*",
      "run_terminal_command:git branch:*",
      "run_terminal_command:git log:*",
      "run_terminal_command:git diff:*",
      "run_terminal_command:git status",
      "run_terminal_command:npx prettier:*",
      "read_file",
      "write_new_file",
      "edit_file",
      "search_files",
      "list_directory"
    ],
    "denied": [
      "run_terminal_command:sf org:delete:*",
      "run_terminal_command:sf org:create:*",
      "run_terminal_command:rm -rf:*",
      "run_terminal_command:git push --force:*",
      "run_terminal_command:git reset --hard:*",
      "run_terminal_command:curl:*",
      "run_terminal_command:wget:*"
    ]
  }
}
```

> **補足**: Copilot CLI では `--allow-all-tools` フラグで一括許可も可能だが、
> Salesforce 開発では破壊的操作を防ぐため、明示的な allow/deny リストの使用を推奨する。
> 代替として `preToolUse` Hook でコマンド検証を行う方法もある。

#### 3.4.2 Hooks → .github/hooks/

Claude Code の `settings.json` 内 `hooks` セクションは、`.github/hooks/` 配下の JSON ファイルに分離する。

**例: post-deploy-check.json**
```json
{
  "hooks": [
    {
      "event": "postToolUse",
      "filter": {
        "toolName": "run_terminal_command",
        "commandPattern": "sf project deploy*"
      },
      "steps": [
        {
          "command": "bash scripts/post-deploy-verify.sh"
        }
      ]
    }
  ]
}
```

**例: pre-commit-lint.json**
```json
{
  "hooks": [
    {
      "event": "preToolUse",
      "filter": {
        "toolName": "run_terminal_command",
        "commandPattern": "git commit*"
      },
      "steps": [
        {
          "command": "npx prettier --check 'force-app/**/*.{cls,trigger}'"
        }
      ]
    }
  ]
}
```

**例: deny-dangerous-commands.json（パーミッションの強化版）**
```json
{
  "hooks": [
    {
      "event": "preToolUse",
      "filter": {
        "toolName": "run_terminal_command"
      },
      "steps": [
        {
          "command": "bash -c 'echo \"$COPILOT_TOOL_INPUT\" | jq -r .command | grep -qE \"(rm -rf|git push --force|sf org:delete)\" && echo DENY || echo ALLOW'",
          "onFailure": "deny"
        }
      ]
    }
  ]
}
```

### 3.5 Skills — ほぼ互換で移行

Agent Skills は Anthropic 主導のオープン仕様（agentskills.io）であり、Claude Code と Copilot CLI で互換性がある。配置先を変更するだけでよい。

```
.claude/skills/salesforce-governor-limits/SKILL.md
  → .github/skills/salesforce-governor-limits/SKILL.md
```

SKILL.md の frontmatter に以下を追加すると、互換性を明示できる。

```yaml
---
name: salesforce-governor-limits
description: >
  ガバナ制限の回避パターンやBatch/Queueable/Futureの選定が必要な場合に使用せよ。
  ...
compatibility:
  - github-copilot
  - claude-code
---
```

---

## 4. フェーズ別実行手順の変換

### 4.1 基本的な操作体系の差異

| 操作 | Claude Code CLI | Copilot CLI |
|------|----------------|-------------|
| 起動 | `claude` | `copilot` |
| サブエージェント呼び出し | `@sf-metadata-analyst ...` | `/agent sf-metadata-analyst` → プロンプト入力、または「sf-metadata-analyst を使って…」 |
| コンテキストリセット | `/clear` | `/clear` |
| コンテキスト圧縮 | `/compact` | `/compact`（+ 95%時に自動実行） |
| モデル切替 | 不可（エージェント定義で固定） | `/model` でセッション中に切替可能 |
| 計画モード | なし | `Shift+Tab` で Plan モードに切替 |
| バックグラウンド委任 | なし | `&` プレフィクスで Copilot coding agent に委任 |
| セッション再開 | なし | `/resume` で過去セッションを再開 |
| 並列サブエージェント | 非対応 | `/fleet` で並列実行 |
| 差分確認 | `git diff` | `/diff`（セッション内変更のインライン表示） |
| コードレビュー | `@sf-code-reviewer` | `/review`（組み込み）+ カスタム `/agent sf-code-reviewer` |

### 4.2 Phase 0: 初期セットアップ & メタデータ取得

**Claude Code CLI での実行:**
```
claude
@sf-metadata-analyst ./raw-metadata ディレクトリに取得済みの...
```

**Copilot CLI での実行:**
```
copilot

# 方法1: 明示的にエージェントを選択
/agent sf-metadata-analyst
> ./raw-metadata ディレクトリに取得済みのSalesforceメタデータがあります。...

# 方法2: 自動委任（Copilotがdescriptionを見て判断）
> Salesforce組織 my-sandbox のメタデータを取得・構造化してください。
> 対象: ./raw-metadata ディレクトリ
```

### 4.3 Phase 1〜5: サブエージェント呼び出しの変換パターン

全フェーズ共通で、`@エージェント名` を `/agent エージェント名` に置換する。

**Claude Code CLI:**
```
@sf-requirements-analyst docs/projects/PROJ-001/requirements/user_requirements.md を読み込み、
メタデータカタログ（metadata-catalog/）と照合して要件定義書を作成してください。
```

**Copilot CLI:**
```
/agent sf-requirements-analyst
> docs/projects/PROJ-001/requirements/user_requirements.md を読み込み、
  メタデータカタログ（metadata-catalog/）と照合して要件定義書を作成してください。
```

または、Copilot に自動委任させる場合:
```
> 要件定義を開始します。docs/projects/PROJ-001/requirements/user_requirements.md を
  メタデータカタログと照合し、要件定義書を作成してください。
```

### 4.4 Phase 6: PR作成

Copilot CLI は GitHub MCP サーバーを内蔵しているため、PR 作成が GitHub ネイティブに行える。

**Claude Code CLI:**
```bash
gh pr create \
  --title "[SFDC-XXX] 案件名" \
  --body-file docs/projects/{PID}/review/pr_description.md \
  --base main
```

**Copilot CLI（2つの方法）:**

```
# 方法1: 自然言語で指示
> レビュー結果がAPPROVEDなので、PRを作成してください。
  PR本文は docs/projects/PROJ-001/review/pr_description.md を使用。
  ベースブランチは main、タイトルは "[SFDC-001] 取引先スコアリング機能開発"

# 方法2: バックグラウンド委任（Copilot coding agent）
& docs/projects/PROJ-001/review/pr_description.md を使ってPRを作成
```

### 4.5 ヒューマンゲートの実現方法

Copilot CLI もターン制対話であるため、Claude Code CLI と同じ方式でヒューマンゲートを実現できる。

**AGENTS.md に記載するゲート制御手順:**

```markdown
## ヒューマンゲート制御手順

フェーズ完了時は以下の手順でゲートを制御する。

1. `docs/projects/{PID}/project-config.json` の `humanGates` を読み取る
2. 該当ゲートが `true` の場合:
   - 成果物の概要サマリを出力
   - 確認ポイントを提示
   - 「承認」「差し戻し」「中断」のいずれかの応答を要求
   - **人間の応答を待つ（次のターンまで処理を進めない）**
3. 該当ゲートが `false` の場合: 自動的に次フェーズへ進行
```

`project-config.json` の構造は変更不要（ツール非依存のため）。

### 4.6 フィードバックループの実現

テスト失敗→修正→再テストのループは、Copilot CLI の Plan モードと組み合わせると効率的に管理できる。

```
# Plan モードでループを計画
Shift+Tab  (Plan モードに切替)
> テスト失敗の修正ループを実行:
  1. sf-tester でテスト実行
  2. 失敗があれば sf-implementer で修正
  3. sf-tester で再テスト
  4. 最大3回まで繰り返す
```

---

## 5. Copilot CLI 固有の活用ポイント

### 5.1 /fleet による並列実行（新機能）

Claude Code CLI では不可能だった並列サブエージェント実行を `/fleet` で実現できる。

**活用シナリオ: Phase 2（設計）での並列メタデータ取得**
```
/fleet
> 1. sf-metadata-analyst: CustomMetadataType と SharingRule の追加メタデータを取得
  2. sf-designer: 要件定義書に基づいて Apex 設計のドラフトを作成
```

**活用シナリオ: Phase 5（レビュー）での並列チェック**
```
/fleet
> 1. sf-code-reviewer: Apex コードのレビュー
  2. sf-code-reviewer: LWC コードのレビュー
```

> **注意**: `/fleet` は結果を収束させるため、最終判断はメインエージェントが行う。
> Phase 3（実装）での並列コード生成は、ファイル競合のリスクがあるため推奨しない。

### 5.2 /delegate によるバックグラウンド委任

長時間のメタデータ取得やテスト実行を、Copilot coding agent にバックグラウンドで委任できる。

```
# Phase 0: 大量メタデータ取得をバックグラウンドで実行
/delegate 組織 my-sandbox から全 Must Have メタデータを取得し、
  metadata-catalog/schema/ に構造化 JSON を生成してください。
  完了したらPRを作成してください。

# ターミナルは解放される。進捗は /resume で確認
```

### 5.3 Plan モードの活用

複数フェーズを横断する作業計画を、実行前に構造化できる。

```
Shift+Tab  (Plan モードに切替)
> PROJ-001 取引先スコアリング機能の Phase 1〜3 を計画してください。
  - ユーザー要件: docs/projects/PROJ-001/requirements/user_requirements.md
  - メタデータカタログ: metadata-catalog/
  - ヒューマンゲート: Phase 1, Phase 2 後に承認を要求
```

Copilot は質問を投げかけてスコープを明確化し、実装計画を策定してから実行に移る。

### 5.4 組み込みエージェントとの併用

Copilot CLI には組み込みエージェント（Explore、Task、Code Review、Plan）があり、カスタムエージェントと併用できる。

| 組み込みエージェント | 活用シナリオ |
|---|---|
| **Explore** | 既存コードベースの高速分析。Phase 0 でメタデータ構造の事前調査に利用 |
| **Task** | `sf apex run test` の実行・ビルド確認。Phase 4 のテスト実行補助に利用 |
| **Code Review** | `/review` コマンドで変更差分のクイックレビュー。sf-code-reviewer の事前チェックに利用 |
| **Plan** | 複数フェーズの実行計画。リードエージェントの計画策定を補助 |

### 5.5 クロスセッションメモリの活用

Copilot CLI はセッション間でリポジトリの規約やパターンを記憶する。

- 過去のセッションでの作業内容を「前回のテスト結果を教えて」で参照可能
- `/resume` で中断したセッションを再開可能
- メタデータカタログの構造を学習し、次回以降の参照が効率化される

---

## 6. リードエージェントの設計変更

### 6.1 Claude Code CLI vs Copilot CLI のリードエージェント

Claude Code CLI では Opus 4.6 がリードエージェントとして固定されていたが、Copilot CLI では **モデル選択が柔軟** になる。

**推奨構成:**

| 役割 | 推奨モデル | 理由 |
|------|----------|------|
| リードエージェント（計画・調整） | Claude Opus 4.6 または GPT-5.3-Codex | 複雑な判断・計画に優れる |
| サブエージェント（実行） | Claude Sonnet 4.6 または GPT-4.1 | コスト効率が良い |
| クイック質問 | Claude Haiku 4.5 または GPT-5 mini | 高速・低コスト |

**セッション中のモデル切替:**
```
/model claude-opus-4.6    # 計画フェーズ
... 計画策定 ...
/model claude-sonnet-4.6   # 実行フェーズ
/agent sf-implementer
... 実装 ...
```

### 6.2 リードエージェントのオーケストレーション方針

Copilot CLI ではリードエージェントを「カスタムエージェント」として明示的に定義するか、AGENTS.md にオーケストレーション手順を記載する。

**方式A: AGENTS.md にオーケストレーション手順を記載（推奨）**

AGENTS.md に開発プロセスの全体フローとサブエージェントの呼び出し順序を記載する。Copilot のメインエージェントがこの手順に従ってサブエージェントを呼び出す。

**方式B: sf-lead-orchestrator.agent.md を定義**

明示的なリードエージェントが必要な場合は、オーケストレーター用のカスタムエージェントを追加定義する。

```markdown
---
name: sf-lead-orchestrator
description: >
  Salesforce開発プロセス全体をオーケストレーションする際に使用する。
  Phase 0〜6 のフェーズ管理、サブエージェントの呼び出し順序制御、
  ヒューマンゲートの管理、フィードバックループの制御を行う。
tools:
  - read_file
  - edit_file
  - write_new_file
  - run_terminal_command
  - search_files
  - list_directory
---

あなたはSalesforce開発プロセスのリードエージェントです。
（CLAUDE.md の「サブエージェント利用ガイドライン」セクションの内容をここに転記）
```

---

## 7. init-framework.sh の改修

初期化スクリプトを Copilot CLI 対応に改修する。主な変更点は以下の通り。

| 変更箇所 | 変更内容 |
|---------|---------|
| 前提条件チェック | `claude` → `copilot` のインストール確認 |
| ディレクトリ作成 | `.claude/agents/` → `.github/agents/`、`.claude/rules/` → `.github/instructions/`、`.claude/skills/` → `.github/skills/` |
| エージェントファイル生成 | 拡張子を `.agent.md` に変更、tools フィールドを変換 |
| ルールファイル生成 | 拡張子を `.instructions.md` に変更、`globs` → `applyTo` に変換 |
| CLAUDE.md 生成 | `AGENTS.md` として生成 |
| settings.json 生成 | `copilot.json` + `.github/hooks/*.json` に分離して生成 |

**変更例（前提条件チェック部分）:**

```bash
# 変更前
command -v claude >/dev/null 2>&1 || MISSING_TOOLS+=("claude (Claude Code CLI)")

# 変更後
command -v copilot >/dev/null 2>&1 || MISSING_TOOLS+=("copilot (GitHub Copilot CLI)")
```

---

## 8. 機能比較と制約事項

### 8.1 移行で得られるメリット

| メリット | 説明 |
|---------|------|
| **GitHub ネイティブ統合** | Issue・PR・ブランチ操作が MCP サーバー経由でシームレスに実行可能 |
| **並列サブエージェント** | `/fleet` による並列実行で Phase 2 の設計・メタデータ取得を高速化 |
| **バックグラウンド委任** | `/delegate` で長時間タスクをバックグラウンド実行 |
| **Plan モード** | 実装前に計画を策定・レビューし、手戻りを削減 |
| **マルチモデル** | タスクの性質に応じてモデルを動的に切替可能 |
| **セッション永続性** | `/resume` でセッションを跨いで作業を継続 |
| **自動コンパクション** | 95% 到達時に自動圧縮（手動 `/compact` の負担軽減） |
| **プラグインエコシステム** | `/plugin install` でコミュニティプラグインを導入可能 |
| **Skills 互換性** | Agent Skills はオープン仕様で Claude Code と互換 |

### 8.2 移行時の制約・注意点

| 制約事項 | 影響 | 対策 |
|---------|------|------|
| **モデル固定ができない** | サブエージェント定義で `model: sonnet` のような指定ができない | `/model` コマンドで手動切替、または AGENTS.md にモデル推奨を記載 |
| **ツール権限の粒度** | エージェント別のツール制限は `tools` フィールドで定義するが、Bash コマンド単位の細かい allow/deny は preToolUse Hook で補完する必要がある | Hook によるコマンドフィルタリングを実装 |
| **Copilot サブスクリプション必要** | Pro / Pro+ / Business / Enterprise プランが必要 | 組織の Copilot ポリシーで CLI を有効化 |
| **プレミアムリクエスト消費** | 各プロンプトがプレミアムリクエストを消費（モデルの倍率による） | 低コストモデル（GPT-5 mini, GPT-4.1 = 0x）の活用 |
| **ネットワーク制約** | Copilot CLI は GitHub 認証経由で動作するため、エアギャップ環境では利用不可 | VPN / プロキシ設定での対応 |
| **CLAUDE.md の自動読み込み** | Copilot CLI は `AGENTS.md` を読む。`CLAUDE.md` も読み込む場合があるが保証されない | `AGENTS.md` を正式な指示ファイルとする。必要に応じて両方配置 |

### 8.3 両環境の並行運用（移行期間中）

移行期間中は Claude Code CLI と Copilot CLI の両方で動作する構成を維持できる。

```
project-root/
├── CLAUDE.md                              # Claude Code 用（既存維持）
├── AGENTS.md                              # Copilot CLI 用（新規作成）
├── .claude/                               # Claude Code 用（既存維持）
│   ├── agents/*.md
│   ├── rules/*.md
│   └── skills/*/SKILL.md
├── .github/                               # Copilot CLI 用（新規作成）
│   ├── agents/*.agent.md
│   ├── instructions/*.instructions.md
│   ├── skills/*/SKILL.md                  # .claude/skills/ からシンボリックリンク
│   └── hooks/*.json
```

Skills は互換仕様のため、シンボリックリンクで共有可能。

```bash
# Skills をシンボリックリンクで共有
ln -s ../../.claude/skills/salesforce-governor-limits .github/skills/salesforce-governor-limits
```

---

## 9. 移行チェックリスト

### Phase 1: 準備（1日）

- [ ] Copilot CLI のインストール（`npm install -g @github/copilot`）
- [ ] 組織の Copilot ポリシーで CLI を有効化
- [ ] `copilot` コマンドで認証確認
- [ ] `/model` で利用可能なモデルを確認

### Phase 2: 設定ファイルの変換（1〜2日）

- [ ] `AGENTS.md` をプロジェクトルートに作成
- [ ] `.github/agents/` に 6つの `.agent.md` ファイルを作成
- [ ] `.github/instructions/` に 5つの `.instructions.md` ファイルを作成
- [ ] `.github/skills/` に Skills をコピーまたはシンボリックリンク
- [ ] `.github/hooks/` に Hook ファイルを作成
- [ ] `copilot.json` をプロジェクトルートに作成

### Phase 3: 動作検証（2〜3日）

- [ ] `/agent` コマンドで全サブエージェントが表示されることを確認
- [ ] `/skills list` で全 Skills が表示されることを確認
- [ ] Phase 0（メタデータ取得）を Copilot CLI で実行し、成果物を確認
- [ ] Phase 1〜2（要件定義・設計）をヒューマンゲート付きで実行
- [ ] Phase 3〜4（実装・テスト）のフィードバックループを確認
- [ ] Phase 5〜6（レビュー・PR作成）を実行し、PR が正しく作成されることを確認

### Phase 4: 運用開始

- [ ] チームメンバーに Copilot CLI のコマンド体系を共有
- [ ] `init-framework.sh` を Copilot CLI 対応版に更新
- [ ] 既存の Claude Code 設定ファイルとの並行運用を開始
- [ ] 問題がなければ `.claude/` ディレクトリを段階的に廃止

---

## 付録A: プロンプト変換クイックリファレンス

| 操作 | Claude Code CLI | Copilot CLI |
|------|----------------|-------------|
| セッション開始 | `claude` | `copilot` |
| エージェント呼び出し | `@sf-metadata-analyst [指示]` | `/agent sf-metadata-analyst` → [指示] |
| コンテキスト圧縮 | `/compact` | `/compact`（+ 自動実行） |
| コンテキストリセット | `/clear` | `/clear` |
| ファイル差分確認 | `git diff` | `/diff` |
| コードレビュー | `@sf-code-reviewer` | `/review` または `/agent sf-code-reviewer` |
| 計画策定 | (手動でプロンプト) | `Shift+Tab` → Plan モード |
| バックグラウンド実行 | (不可) | `& [指示]` または `/delegate [指示]` |
| 並列エージェント | (不可) | `/fleet` |
| セッション再開 | (不可) | `/resume` |
| モデル切替 | (不可) | `/model [モデル名]` |

## 付録B: ファイル形式変換スクリプト

以下のスクリプトで `.claude/` 配下のファイルを `.github/` 形式に一括変換できる。

```bash
#!/usr/bin/env bash
set -euo pipefail

# Claude Code → Copilot CLI 設定ファイル変換スクリプト
PROJECT_ROOT="$(pwd)"

echo "=== Claude Code → Copilot CLI 変換開始 ==="

# 1. ディレクトリ作成
mkdir -p .github/{agents,instructions,skills,hooks}

# 2. agents/ の変換
for f in .claude/agents/*.md; do
  basename=$(basename "$f" .md)
  target=".github/agents/${basename}.agent.md"
  echo "  変換: $f → $target"
  # model: 行を削除、tools の値を変換
  sed -e '/^model:/d' \
      -e 's/- Read$/- read_file/' \
      -e 's/- Edit$/- edit_file/' \
      -e 's/- Write$/- write_new_file/' \
      -e 's/- Bash$/- run_terminal_command/' \
      -e 's/- Grep$/- search_files/' \
      -e 's/- Glob$/- list_directory/' \
      -e 's|\.claude/rules/|.github/instructions/|g' \
      -e 's|\.claude/skills/|.github/skills/|g' \
      "$f" > "$target"
done

# 3. rules/ → instructions/ の変換
for f in .claude/rules/*.md; do
  basename=$(basename "$f" .md)
  target=".github/instructions/${basename}.instructions.md"
  echo "  変換: $f → $target"
  # globs → applyTo、パスに **/ プレフィクス追加
  sed -e 's/^globs: \[/applyTo: "/' \
      -e 's/\]$/"/g' \
      -e 's|\.claude/|.github/|g' \
      "$f" > "$target"
done

# 4. skills/ のシンボリックリンク
for d in .claude/skills/*/; do
  basename=$(basename "$d")
  if [ ! -e ".github/skills/$basename" ]; then
    ln -s "../../.claude/skills/$basename" ".github/skills/$basename"
    echo "  リンク: .github/skills/$basename → .claude/skills/$basename"
  fi
done

echo "=== 変換完了 ==="
echo "手動確認が必要な項目:"
echo "  - .github/instructions/*.instructions.md の applyTo フィールド"
echo "  - .github/agents/*.agent.md の tools フィールド"
echo "  - AGENTS.md の作成（CLAUDE.md を参照して作成）"
```
