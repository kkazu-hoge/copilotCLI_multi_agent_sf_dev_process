# Copilot CLI 版フレームワーク — 段階別導入手順書

> 本ドキュメントは、Salesforce マルチエージェント開発フレームワーク（Copilot CLI版）を、ゼロの状態から本番運用まで段階的に導入するための実践手順書です。  
> 各ステージには**所要時間の目安**、**具体的なコマンド**、**動作確認手順**、**完了チェックリスト**を記載しています。

---

## 導入ロードマップ全体像

```
Stage 0              Stage 1              Stage 2              Stage 3
環境準備             フレームワーク初期化   初回案件の            Phase 0-1 実行
(0.5日)              (0.5-1日)            セットアップ(0.5日)    メタデータ+要件(1-2日)
───────────────────────────────────────────────────────────────────────────
                                                                    │
Stage 4              Stage 5              Stage 6              Stage 7
Phase 2-4 実行       Phase 5-6 実行       チーム展開・           継続的改善
設計+実装+テスト     レビュー+PR          運用定着              (継続)
(3-5日)              (1-2日)              (1-2週間)
```

**最短ルート（1人・小規模案件）**: Stage 0 → 1 → 2 → 3 → 4 → 5 で **約1週間**  
**チーム導入ルート**: 上記に Stage 6 → 7 を加えて **約3〜4週間**

---

## Stage 0: 環境準備（所要時間: 半日）

### 目的

Copilot CLI とSalesforce CLI が正常に動作し、対象Salesforce組織に接続できる状態にする。

### 0-1. 必要ツールのインストール

```bash
# ── GitHub Copilot CLI ──
# 方法A: npm
npm install -g @github/copilot

# 方法B: Homebrew (macOS/Linux)
brew install github/gh/copilot-cli

# 方法C: install script (macOS/Linux)
curl -fsSL https://cli.github.com/packages/copilot-install.sh | bash

# バージョン確認
copilot --version
```

```bash
# ── Salesforce CLI ──
npm install -g @salesforce/cli
sf --version
# v2.x.x であることを確認（v1 / 旧 sfdx は非対応）

# ── その他の必須ツール ──
git --version       # 2.x 以上
jq --version        # 1.6 以上
node --version      # 18.x 以上

# ── オプション ──
gh --version        # GitHub CLI（PR作成を gh コマンドで行う場合）
```

### 0-2. GitHub 認証

```bash
# Copilot CLI の認証（GitHub アカウントで OAuth 認証）
copilot
# 初回起動時に認証フローが開始される。ブラウザでGitHubにログインして承認

# 認証状態の確認
# Copilot CLI 内で以下を実行
/model
# → 利用可能なモデル一覧が表示されれば認証OK
```

> **前提**: Copilot Pro / Pro+ / Business / Enterprise のいずれかのサブスクリプションが必要です。  
> Business / Enterprise の場合、組織の管理者が Copilot CLI ポリシーを有効化している必要があります。

### 0-3. Salesforce 組織への接続

```bash
# Sandbox への認証
sf org login web --alias my-sandbox --instance-url https://test.salesforce.com

# 本番環境への認証（読み取り専用の参照目的）
sf org login web --alias my-prod --instance-url https://login.salesforce.com

# 接続確認
sf org display --target-org my-sandbox

# メタデータ取得テスト（小さなメタデータで疎通確認）
sf project retrieve start --metadata CustomObject:Account --target-org my-sandbox
```

### 0-4. Salesforce プロジェクトの準備

既存の Salesforce DX プロジェクトがない場合は作成する。

```bash
# 新規プロジェクトの場合
sf project generate --name my-salesforce-project
cd my-salesforce-project

# 既存プロジェクトの場合
cd /path/to/existing-salesforce-project

# Git 初期化（未初期化の場合）
git init
git add .
git commit -m "chore: initial project setup"
```

### 0-5. 推奨モデルの確認

```bash
copilot
# Copilot CLI 内で以下を実行
/model
# Claude Opus 4.6, Claude Sonnet 4.6, GPT-5.3-Codex 等が利用可能か確認
```

| 用途 | 推奨モデル | 理由 |
|------|----------|------|
| 計画・オーケストレーション | Claude Opus 4.6 / GPT-5.3-Codex | 複雑な判断に優れる |
| 実装・テスト | Claude Sonnet 4.6 / GPT-4.1 | コスト効率が良い |
| 簡単な質問 | Claude Haiku 4.5 / GPT-5 mini | 高速・低コスト（0x） |

### Stage 0 完了チェックリスト

- [ ] `copilot --version` が正常に出力される
- [ ] `sf --version` が v2.x を表示する
- [ ] `git`, `jq`, `node` が利用可能
- [ ] Copilot CLI で `/model` を実行しモデル一覧が表示される
- [ ] `sf org display --target-org my-sandbox` で組織情報が表示される
- [ ] `sfdx-project.json` が存在するプロジェクトディレクトリがある
- [ ] Git リポジトリが初期化済み

---

## Stage 1: フレームワーク初期化（所要時間: 半日〜1日）

### 目的

`init-framework.sh` を実行してフレームワークの骨格を生成し、プレースホルダファイルを完成させる。

### 1-1. フレームワークファイルの配置

```bash
# フレームワークのドキュメント群をプロジェクト内に配置
# （ダウンロード済みの前提）
mkdir -p salesforce-agent-framework
# 以下のファイルを salesforce-agent-framework/ にコピー
# - README.md
# - 01_architecture.md 〜 05_quality_and_operations.md
# - init-framework.sh

# init-framework.sh をプロジェクトの scripts/ にコピー
mkdir -p scripts
cp salesforce-agent-framework/init-framework.sh scripts/
chmod +x scripts/init-framework.sh
```

### 1-2. 初期化スクリプトの実行

```bash
# プロジェクトルートで実行
bash scripts/init-framework.sh
```

**実行結果として以下が生成される:**

```
.github/
├── agents/           ← カスタムエージェント定義（6ファイル）
├── instructions/     ← 条件付き自動適用ルール（5ファイル）
├── skills/           ← 詳細ドメイン知識（5ディレクトリ）
└── hooks/            ← （この段階では空。Stage 6 で追加）

copilot.json          ← ツール許可/拒否設定
AGENTS.md             ← プロジェクト全体の規約
force-app/.github/copilot-instructions.md  ← Salesforce固有ルール
docs/architecture/    ← アーキテクチャテンプレート
```

### 1-3. プレースホルダファイルの完成

`init-framework.sh` は一部のファイルを `[TODO]` マーク付きプレースホルダとして生成します。これらを手動で完成させます。

```bash
# [TODO] マーク付きファイルの一覧確認
find .github/agents -name "*.agent.md" -exec grep -l "TODO" {} \;
find .github/skills -name "SKILL.md" -exec grep -l "TODO" {} \;
```

**完成が必要なファイル:**

| ファイル | 転記元 | 作業内容 |
|---------|--------|---------|
| `.github/agents/sf-designer.agent.md` | `02_agent_definitions.md` の「sf-designer」セクション | コードブロック全体をコピー |
| `.github/agents/sf-implementer.agent.md` | `02_agent_definitions.md` の「sf-implementer」セクション | 同上 |
| `.github/agents/sf-tester.agent.md` | `02_agent_definitions.md` の「sf-tester」セクション | 同上 |
| `.github/agents/sf-code-reviewer.agent.md` | `02_agent_definitions.md` の「sf-code-reviewer」セクション | 同上 |
| `.github/skills/salesforce-bulk-patterns/SKILL.md` | `04_configuration_templates.md` セクション7 | テンプレートに基づき記述 |
| `.github/skills/salesforce-lwc-patterns/SKILL.md` | 同上 | 同上 |
| `.github/skills/salesforce-test-patterns/SKILL.md` | 同上 | 同上 |

> **ヒント**: `sf-metadata-analyst` と `sf-requirements-analyst` は `init-framework.sh` が完全な内容で生成するため、手動転記は不要です。

### 1-4. AGENTS.md のカスタマイズ

```bash
# AGENTS.md を開いて [TODO] マークを検索し、案件情報を記入
# 以下の4項目を埋める:
# - 案件名
# - 案件ID
# - 対象Salesforce組織（エイリアス）
# - 開発範囲の概要
```

### 1-5. アーキテクチャドキュメントの初期作成

```bash
# システムコンテキスト図（必須）
# docs/architecture/system-context.md を開き、以下を記述:
# - レイヤー構成（UI → コントローラー → サービス → データアクセス）
# - 外部連携マップ（連携先システムの一覧）

# 横断的方針（推奨）
# docs/architecture/policies/ 配下に以下を作成:
# - security-policy.md（FLS/CRUD方針、共有ルール方針）
# - performance-policy.md（バッチサイズ基準、キャッシュ方針）
# - naming-convention-policy.md（命名規約の詳細版）
```

> これらは任意ですが、設計・レビューフェーズでエージェントが参照するため、作成しておくと出力品質が向上します。

### 1-6. 動作確認（Copilot CLI からの認識チェック）

```bash
# Copilot CLI を起動
copilot

# エージェントの認識確認
/agent
# → sf-metadata-analyst, sf-requirements-analyst 等が一覧に表示されることを確認

# Skills の認識確認
/skills list
# → salesforce-governor-limits, salesforce-fls-security 等が表示されることを確認
```

**エージェントが表示されない場合のトラブルシューティング:**

| 症状 | 原因 | 対処 |
|------|------|------|
| `/agent` でエージェントが表示されない | ファイル拡張子が `.agent.md` でない | ファイル名を確認。`.md` → `.agent.md` に修正 |
| 特定のエージェントだけ表示されない | YAML frontmatter の構文エラー | `name:` と `description:` が正しく記述されているか確認 |
| `/skills list` で Skills が表示されない | `SKILL.md` が存在しない、または frontmatter 不正 | `.github/skills/*/SKILL.md` の存在と `name:` / `description:` を確認 |

### 1-7. 初期状態のコミット

```bash
git add .
git commit -m "chore: Copilot CLI フレームワーク初期化

- .github/agents/ にカスタムエージェント定義を配置
- .github/instructions/ に条件付き自動適用ルールを配置
- .github/skills/ にドメイン知識Skillsを配置
- AGENTS.md にプロジェクト規約を記載
- copilot.json にツール許可/拒否設定を配置"
```

### Stage 1 完了チェックリスト

- [ ] `init-framework.sh` が正常に完了した
- [ ] `.github/agents/` に 6つの `.agent.md` ファイルが存在する
- [ ] `.github/instructions/` に 5つの `.instructions.md` ファイルが存在する
- [ ] `.github/skills/` に 5つのディレクトリと `SKILL.md` が存在する
- [ ] `copilot.json` が存在する
- [ ] `AGENTS.md` の `[TODO]` が全て解消されている
- [ ] 全プレースホルダファイルの `[TODO]` が解消されている
- [ ] `/agent` コマンドでエージェントが一覧表示される
- [ ] `/skills list` で Skills が一覧表示される
- [ ] 初期状態が Git にコミット済み

---

## Stage 2: 初回案件のセットアップ（所要時間: 半日）

### 目的

案件固有のディレクトリ・設定ファイル・ブランチを作成し、開発を開始できる状態にする。

### 2-1. 案件セットアップスクリプトの実行

```bash
# 案件セットアップ
bash scripts/setup-project.sh PROJ-001 my-sandbox "取引先スコアリング機能開発"
```

**実行結果:**

```
docs/projects/PROJ-001/
├── project-config.json      ← 案件設定・ステータス追跡
├── requirements/             ← 要件定義書の格納先
├── design/                   ← 設計書の格納先
├── test-results/             ← テスト結果の格納先
└── review/                   ← レビュー結果の格納先
```

### 2-2. 案件設定の確認

```bash
# project-config.json の内容確認
cat docs/projects/PROJ-001/project-config.json | jq .

# ヒューマンゲート設定の確認（初回はすべて true が推奨）
jq '.humanGates' docs/projects/PROJ-001/project-config.json
```

```json
{
  "gate_requirements": true,
  "gate_design": true,
  "gate_test": true,
  "gate_pr": true
}
```

### 2-3. ユーザー要件書の作成

```bash
# テンプレートを使って要件書を作成
# docs/projects/PROJ-001/requirements/user_requirements.md を編集
```

最低限記入すべき項目:

```markdown
# ユーザー要件書

## 基本情報
- 案件ID: PROJ-001
- 要件名: 取引先スコアリング機能開発
- 優先度: 高

## 背景・目的
取引先の活動履歴に基づくスコアリングを自動化し、
営業チームの優先順位付けを支援したい。

## 機能要件
### やりたいこと
1. 取引先の活動履歴（過去6ヶ月）からスコアを自動計算
2. スコアに基づいてグレード（A/B/C/D）を自動付与
3. グレード変更時に担当者に通知

## 対象オブジェクト
- Account
- Activity / Task
```

### 2-4. 案件ブランチの確認

```bash
# セットアップスクリプトが作成したブランチを確認
git branch
# * feature/PROJ-001 と表示されることを確認

# 案件ファイルをコミット
git add docs/projects/PROJ-001/
git commit -m "docs: PROJ-001 案件セットアップ"
```

### Stage 2 完了チェックリスト

- [ ] `docs/projects/PROJ-001/` ディレクトリ構成が作成されている
- [ ] `project-config.json` に案件情報・ヒューマンゲート設定が記載されている
- [ ] `user_requirements.md` にユーザー要件が記入されている
- [ ] `feature/PROJ-001` ブランチが作成されている
- [ ] 案件ファイルが Git にコミット済み

---

## Stage 3: Phase 0-1 実行 — メタデータ取得＋要件定義（所要時間: 1〜2日）

### 目的

メタデータカタログを構築し、要件定義書を自動生成して承認する。

### 3-1. Copilot CLI の起動とモデル選択

```bash
copilot

# 計画・オーケストレーション用のモデルを選択
/model claude-opus-4.6
```

### 3-2. Phase 0: メタデータの取得・構造化

```
# ── 方法A: エージェントを明示的に呼び出し ──
/agent sf-metadata-analyst

> 対象組織 my-sandbox のメタデータを取得・構造化してください。
>
> ## 作業内容
> 1. Must Have メタデータを sf project retrieve start で取得
> 2. metadata-catalog/schema/objects/ にオブジェクトごとの構造化JSONを生成
> 3. metadata-catalog/schema/relationships.json にリレーションマップを生成
> 4. metadata-catalog/catalog/ に辞書・自動化一覧・権限マトリクスを生成
>
> 対象組織エイリアス: my-sandbox
```

**動作確認ポイント:**

```bash
# メタデータが取得されたか確認
ls metadata-catalog/schema/objects/
# → Account.json, Opportunity.json 等が生成されていること

# カタログが生成されたか確認
ls metadata-catalog/catalog/
# → object_dictionary.json, automation_inventory.json 等が生成されていること

# コミット
git add metadata-catalog/
git commit -m "chore(metadata): PROJ-001 メタデータカタログを構築"
```

**トラブルシューティング:**

| 症状 | 対処 |
|------|------|
| `sf project retrieve start` がタイムアウト | メタデータ種別を分割して個別に取得するよう指示 |
| `INVALID_SESSION_ID` | `sf org login web` で再認証 |
| エージェントがメタデータを構造化しない | プロンプトに出力先パスを明示的に記載 |

### 3-3. Phase 1: 要件定義

```
/agent sf-requirements-analyst

> 以下のインプットに基づき、要件定義書を作成してください。
>
> ## インプット
> 1. ユーザー要件: docs/projects/PROJ-001/requirements/user_requirements.md
> 2. メタデータカタログ: metadata-catalog/catalog/
> 3. スキーマ情報: metadata-catalog/schema/
> 4. システムコンテキスト図: docs/architecture/system-context.md
> 5. 横断的方針: docs/architecture/policies/
>
> ## 出力先
> docs/projects/PROJ-001/requirements/requirements_specification.md
```

### 3-4. ヒューマンゲート: 要件定義書の承認

エージェントが要件定義書を出力したら、以下の観点でレビューします。

**確認観点チェックリスト:**

- [ ] ユーザー要件の全項目が反映されているか
- [ ] 各機能要件に ID と優先度が付与されているか
- [ ] 既存メタデータとの影響範囲分析が記載されているか
- [ ] Nice to Have メタデータの追加取得要否が明記されているか
- [ ] 未決事項（Open Items）が明示されているか

**承認の入力:**

```
# 承認する場合
承認

# 修正を求める場合
差し戻し
- FR-001 の受入基準が不明確。具体的な数値基準を追記してください
- 影響範囲分析に Task オブジェクトへの影響が漏れています
```

**承認後のコミット:**

```bash
git add docs/projects/PROJ-001/requirements/
git commit -m "docs(requirements): PROJ-001 要件定義書を作成"
```

### Stage 3 完了チェックリスト

- [ ] `metadata-catalog/schema/objects/` に構造化JSONが生成されている
- [ ] `metadata-catalog/catalog/` にカタログファイル群が生成されている
- [ ] `requirements_specification.md` が出力されている
- [ ] 要件定義書のヒューマンゲートで承認が得られている
- [ ] Phase 0, Phase 1 の成果物が Git にコミット済み

---

## Stage 4: Phase 2-4 実行 — 設計＋実装＋テスト（所要時間: 3〜5日）

### 目的

設計書の作成・承認、コード実装、テスト作成・実行・自動修正までを完了する。

### 4-1. Phase 2: 設計

```
# Nice to Have メタデータの追加取得（要件定義書に記載がある場合）
/agent sf-metadata-analyst

> 要件定義書に基づき、以下の Nice to Have メタデータを追加取得してください。
> - CustomMetadataType
> - SharingRule
> 取得結果を metadata-catalog/ にマージしてください。
> 対象組織: my-sandbox
```

```
# 設計書の作成
/agent sf-designer

> 以下のインプットに基づき、技術設計書を作成してください。
>
> ## インプット
> 1. 要件定義書: docs/projects/PROJ-001/requirements/requirements_specification.md
> 2. メタデータカタログ: metadata-catalog/catalog/
> 3. ADR: docs/architecture/decisions/
> 4. 横断的方針: docs/architecture/policies/
>
> ## 出力先
> docs/projects/PROJ-001/design/
```

**設計書レビュー（ヒューマンゲート）:**

- [ ] 要件定義書の全項目が設計に反映されているか
- [ ] ガバナ制限の事前評価が記載されているか
- [ ] FLS/CRUD チェック方針が明記されているか
- [ ] 実装順序と依存関係が明確か

```
# 承認
承認
```

### 4-2. Phase 3: 実装

> **ヒント**: 実装フェーズではモデルを切り替えるとコスト効率が良くなります。

```
/model claude-sonnet-4.6
```

設計書の実装計画に基づき、タスク単位でエージェントを呼び出します。

```
/agent sf-implementer

> 設計書 docs/projects/PROJ-001/design/apex_design.md に基づき、
> 以下のファイルを実装してください。
>
> ## 作成ファイル
> 1. force-app/main/default/triggers/AccountTrigger.trigger
> 2. force-app/main/default/classes/AccountTriggerHandler.cls
> 3. force-app/main/default/classes/AccountScoringService.cls
>
> ## 参照
> - metadata-catalog/schema/objects/Account.json
> - docs/projects/PROJ-001/design/data_model_design.md
```

**実装のコミット粒度:**

```bash
# トリガ + ハンドラで1コミット
git add force-app/main/default/triggers/AccountTrigger.trigger
git add force-app/main/default/classes/AccountTriggerHandler.*
git commit -m "feat(apex): AccountTrigger と AccountTriggerHandler を実装"

# サービスクラスで1コミット
git add force-app/main/default/classes/AccountScoringService.*
git commit -m "feat(apex): AccountScoringService を実装"
```

> **1回の呼び出しの目安**: Apex 2〜3クラス（300行以内）、LWC 1コンポーネント、フロー1つ。  
> これを超える場合は複数回に分割してください。

### 4-3. Phase 4: テスト

```
/agent sf-tester

> 以下の実装コードに対するテストクラスを作成・実行してください。
>
> ## テスト対象
> - force-app/main/default/classes/AccountTriggerHandler.cls
> - force-app/main/default/classes/AccountScoringService.cls
>
> ## テスト出力先
> - force-app/main/default/classes/AccountTriggerHandlerTest.cls
> - force-app/main/default/classes/AccountScoringServiceTest.cls
>
> ## レポート出力先
> - docs/projects/PROJ-001/test-results/test_report.md
>
> ## 指示
> 1. テスト作成 → 実行 → 失敗分析 → 修正のループを最大3回まで自動で回してください
> 2. カバレッジ目標: 各クラス80%以上、全体75%以上
> 3. テスト完了後、静的解析スクリプトを実行してください:
>    bash .github/skills/salesforce-governor-limits/scripts/scan-governor-violations.sh force-app/
>    bash .github/skills/salesforce-fls-security/scripts/scan-fls-compliance.sh force-app/
> 4. 結果を docs/projects/PROJ-001/test-results/ に出力
```

**テスト結果の確認（ヒューマンゲート）:**

```bash
# テスト結果レポートを確認
cat docs/projects/PROJ-001/test-results/test_report.md
```

- [ ] 全テストが成功しているか
- [ ] カバレッジが 75% 以上か
- [ ] 静的解析で重大な違反候補がないか

```
承認
```

### Stage 4 完了チェックリスト

- [ ] 設計書が `docs/projects/PROJ-001/design/` に出力・承認済み
- [ ] 全実装ファイルが `force-app/` に作成されている
- [ ] テストクラスが作成され、全テストが成功している
- [ ] カバレッジが 75% 以上
- [ ] 静的解析が実行され、結果が `test-results/` に保存されている
- [ ] 各フェーズの成果物が Git にコミット済み

---

## Stage 5: Phase 5-6 実行 — レビュー＋PR作成（所要時間: 1〜2日）

### 目的

コードレビューで品質を確認し、PR を作成・提出する。

### 5-1. Phase 5: コードレビュー

```
/agent sf-code-reviewer

> 以下の実装コードをレビューしてください。
>
> ## レビュー対象
> - force-app/main/default/classes/ 配下の新規・変更ファイル
> - force-app/main/default/triggers/ 配下の新規・変更ファイル
>
> ## 参照ドキュメント
> - 設計書: docs/projects/PROJ-001/design/
> - 静的解析結果: docs/projects/PROJ-001/test-results/static-analysis-*.txt
> - 横断的方針: docs/architecture/policies/
>
> ## 出力先
> - docs/projects/PROJ-001/review/review_report.json
> - docs/projects/PROJ-001/review/review_report.md
```

**レビュー結果の判定:**

| 判定 | 条件 | 次のアクション |
|------|------|--------------|
| `APPROVE` | P1=0 かつ P2=0 | Phase 6（PR作成）へ進行 |
| `CONDITIONAL` | P1=0 かつ P2>0 | P2 を修正後に再レビュー |
| `BLOCK` | P1>0 | P1 を全て修正後に再レビュー |

**指摘がある場合の修正:**

```
/agent sf-implementer

> docs/projects/PROJ-001/review/review_report.json のレビュー指摘に基づき修正してください。
> P1/P2 の指摘をすべて修正し、修正後にテストが成功することを確認してください。
```

修正後、再レビューを実施:

```
/agent sf-code-reviewer

> 修正が完了しました。再レビューを実施してください。
> 前回レポート: docs/projects/PROJ-001/review/review_report.json
```

### 5-2. Phase 6: PR 作成

レビューが `APPROVE` になったら PR を作成します。

```
# PR本文の生成
/agent sf-code-reviewer

> 以下の情報に基づき、PR本文を生成してください。
>
> ## インプット
> 1. 要件定義書: docs/projects/PROJ-001/requirements/requirements_specification.md
> 2. テスト結果: docs/projects/PROJ-001/test-results/test_report.md
> 3. レビュー結果: docs/projects/PROJ-001/review/review_report.json
> 4. 変更ファイル一覧: git diff --name-only main...HEAD
>
> ## 出力先
> docs/projects/PROJ-001/review/pr_description.md
```

**PR の作成（3つの方法）:**

```bash
# 方法A: Copilot CLI 内から自然言語で指示
> docs/projects/PROJ-001/review/pr_description.md を使って
> main ブランチへのPRを作成してください。
> タイトル: "[PROJ-001] 取引先スコアリング機能開発"

# 方法B: GitHub CLI を使用
gh pr create \
  --title "[PROJ-001] 取引先スコアリング機能開発" \
  --body-file docs/projects/PROJ-001/review/pr_description.md \
  --base main

# 方法C: バックグラウンド委任
/delegate PR を作成してください。PR本文は docs/projects/PROJ-001/review/pr_description.md を使用。ベースは main。
```

**ヒューマンゲート（PR 承認）:**

- [ ] レビュー結果が `APPROVE` であること
- [ ] PR 本文に変更概要・テスト結果・影響範囲が記載されていること
- [ ] デプロイ手順・ロールバック手順が明記されていること

```
承認
```

### Stage 5 完了チェックリスト

- [ ] コードレビューが `APPROVE`（P1=0, P2=0）
- [ ] PR 本文が生成されている
- [ ] PR が GitHub に作成されている
- [ ] ヒューマンゲート（PR 承認）が完了している
- [ ] レビュー関連ファイルが Git にコミット済み

---

## Stage 6: チーム展開・運用定着（所要時間: 1〜2週間）

### 目的

初回案件の成功をもとに、チーム全体にフレームワークを展開し、運用を定着させる。

### 6-1. 初回案件の振り返り

初回案件（Stage 3-5）の実行結果を振り返り、改善点を洗い出します。

```markdown
## 振り返りチェック項目

### エージェント出力の品質
- [ ] メタデータカタログの網羅性は十分だったか
- [ ] 要件定義書に人間が大幅に手を入れる必要があったか
- [ ] 設計書の粒度は実装に十分だったか
- [ ] 生成コードの品質は期待通りだったか
- [ ] テストの網羅性は十分だったか
- [ ] レビュー指摘は的確だったか

### プロセスの効率性
- [ ] ヒューマンゲートでの待ち時間は適切だったか
- [ ] フィードバックループの回数は想定内だったか
- [ ] コンテキストの枯渇は発生したか
- [ ] プレミアムリクエストの消費量は許容範囲だったか
```

### 6-2. エージェント定義のチューニング

振り返り結果に基づき、エージェント定義を調整します。

```bash
# よくある調整パターン:

# 1. description の改善（エージェントが呼ばれるべき場面で呼ばれない場合）
#    → description にトリガーキーワードを追加

# 2. 出力フォーマットの調整（出力の粒度が不適切な場合）
#    → エージェント定義の出力フォーマットセクションを修正

# 3. instructions の調整（ルールが守られない場合）
#    → .github/instructions/*.instructions.md の記述を強化
```

### 6-3. ヒューマンゲートの段階的解除

信頼性が確認されたフェーズから、ヒューマンゲートを段階的に解除します。

```json
// docs/projects/PROJ-002/project-config.json
"humanGates": {
  "gate_requirements": true,   // 要件は常に有効を推奨
  "gate_design": false,        // 2回目以降、設計品質が安定したら解除
  "gate_test": false,          // テスト結果が安定したら解除
  "gate_pr": true              // PRは常に有効を推奨
}
```

| ゲート | 解除の目安 | リスク |
|--------|----------|--------|
| `gate_design` | 設計書の手動修正が2案件連続で不要だった場合 | 低（実装・テストで検出可能） |
| `gate_test` | テスト結果に人間の介入が2案件連続で不要だった場合 | 中（レビューで補完） |
| `gate_requirements` | 解除非推奨（要件ミスは後工程で修正コスト増大） | 高 |
| `gate_pr` | 解除非推奨（本番デプロイ前の最終チェック） | 高 |

### 6-4. Hooks の追加

運用に慣れたら、Hooks で自動化を強化します。

```bash
mkdir -p .github/hooks
```

**推奨 Hook（優先順）:**

```json
// .github/hooks/pre-commit-lint.json
// コミット前に Prettier で自動フォーマット
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
          "command": "npx prettier --check 'force-app/**/*.{cls,trigger}' 2>/dev/null || true"
        }
      ]
    }
  ]
}
```

```json
// .github/hooks/deny-dangerous-commands.json
// 破壊的コマンドの実行を拒否
{
  "hooks": [
    {
      "event": "preToolUse",
      "filter": {
        "toolName": "run_terminal_command"
      },
      "steps": [
        {
          "command": "echo \"$COPILOT_TOOL_INPUT\" | jq -r .command | grep -qE '(rm -rf|git push --force|sf org:delete)' && exit 1 || exit 0"
        }
      ]
    }
  ]
}
```

### 6-5. チームメンバーへのオンボーディング

| 対象 | 提供資料 | 所要時間 |
|------|---------|---------|
| 全員 | 本導入手順書（本ドキュメント）の Stage 0 | 30分 |
| 運用者 | 本導入手順書の全体 + `03_execution_playbook.md` | 2時間 |
| 管理者 | `05_quality_and_operations.md` | 1時間 |

**オンボーディング時のハンズオン手順:**

```bash
# 1. Copilot CLI の起動体験
copilot
> こんにちは。このプロジェクトの構成を教えてください。

# 2. エージェント呼び出し体験
/agent sf-metadata-analyst
> metadata-catalog/schema/schema_summary.json の内容を要約してください。

# 3. Plan モード体験
# Shift+Tab で Plan モードに切替
> PROJ-002 の要件定義から設計までの計画を立ててください。

# 4. /diff 体験
/diff
# → セッション内の変更を確認
```

### Stage 6 完了チェックリスト

- [ ] 初回案件の振り返りが完了し、改善点が整理されている
- [ ] エージェント定義・instructions が振り返りに基づいて調整されている
- [ ] ヒューマンゲートの解除方針が決定されている
- [ ] 推奨 Hooks が追加されている
- [ ] チームメンバーのオンボーディングが完了している
- [ ] 2件目の案件で全フェーズ通しの実行が成功している

---

## Stage 7: 継続的改善（継続的）

### 目的

フレームワークの品質と効率を継続的に改善し、運用を成熟させる。

### 7-1. 定期メンテナンスサイクル

| 頻度 | 作業内容 | 担当 |
|------|---------|------|
| **週次** | エージェント出力の品質サンプリング | 運用者 |
| **月次** | エージェント定義の見直し。instructions / skills の更新 | 管理者 |
| **四半期** | Copilot CLI のバージョン確認。新機能の評価と取り込み | 管理者 |
| **四半期** | instructions / skills の棚卸し。不要ルールの廃止、新規追加 | 管理者 |
| **Salesforceリリース時** | ガバナ制限値の更新確認。新API への対応 | 管理者 |

### 7-2. Copilot CLI 新機能の活用検討

Copilot CLI は急速に進化しています。以下の機能が利用可能になった場合は積極的に取り込みましょう。

| 機能 | 活用シナリオ | 確認方法 |
|------|-------------|---------|
| `/fleet` 並列実行 | Phase 2 で設計とメタデータ追加取得を並列化 | `/fleet` コマンドの利用可否を確認 |
| Plugins | コミュニティの Salesforce 向け Plugin の導入 | `/plugin search salesforce` |
| Agentic Workflows | GitHub Actions との連携による CI/CD 統合 | `.github/workflows/` に Workflow 定義 |
| MCP サーバー拡張 | Salesforce MCP サーバーが公開された場合の統合 | Copilot CLI の MCP 設定を確認 |

### 7-3. コスト最適化

```bash
# プレミアムリクエスト消費の確認
# GitHub の Copilot 設定画面で使用量を確認

# コスト削減のヒント:
# 1. 簡単なタスクは GPT-5 mini / GPT-4.1 (0x) を使用
/model gpt-5-mini

# 2. 実装フェーズは Sonnet (1x) で十分
/model claude-sonnet-4.6

# 3. 計画・レビューのみ Opus (多倍) を使用
/model claude-opus-4.6
```

### 7-4. Skills の拡充

運用で蓄積されたナレッジを Skills として体系化します。

```bash
# 新しい Skill の追加手順
mkdir -p .github/skills/salesforce-integration-patterns
cat > .github/skills/salesforce-integration-patterns/SKILL.md << 'EOF'
---
name: salesforce-integration-patterns
description: >
  外部システム連携パターンの選定が必要な場合に使用せよ。
  Named Credential, External Service, Platform Event,
  Change Data Capture 等の使い分け判断に活用する。
---

# 外部連携パターン — 判断フロー

## 連携方式の選定
├─ リアルタイム同期 → REST Callout + Named Credential
├─ 非同期通知 → Platform Event
├─ バッチ連携 → Batch Apex + Named Credential
└─ データ変更の外部配信 → Change Data Capture
EOF
```

---

## 付録A: コマンドクイックリファレンス

| 操作 | コマンド |
|------|---------|
| Copilot CLI 起動 | `copilot` |
| エージェント一覧 | `/agent` |
| エージェント呼び出し | `/agent sf-metadata-analyst` → プロンプト |
| Skills 一覧 | `/skills list` |
| モデル切替 | `/model claude-sonnet-4.6` |
| Plan モード | `Shift+Tab` |
| コンテキスト圧縮 | `/compact` |
| コンテキストリセット | `/clear` |
| 差分確認 | `/diff` |
| コードレビュー | `/review` |
| セッション再開 | `/resume` |
| バックグラウンド委任 | `/delegate [指示]` または `& [指示]` |
| 並列エージェント | `/fleet` |
| プラグイン管理 | `/plugin install owner/repo` |

## 付録B: 全ステージの所要時間まとめ

| ステージ | 所要時間 | 前提 |
|---------|---------|------|
| Stage 0: 環境準備 | 半日 | ツール未インストール |
| Stage 1: フレームワーク初期化 | 半日〜1日 | プレースホルダ完成含む |
| Stage 2: 案件セットアップ | 半日 | 要件書の記入含む |
| Stage 3: Phase 0-1 | 1〜2日 | メタデータ量に依存 |
| Stage 4: Phase 2-4 | 3〜5日 | 案件規模に依存 |
| Stage 5: Phase 5-6 | 1〜2日 | レビュー指摘量に依存 |
| Stage 6: チーム展開 | 1〜2週間 | チーム規模に依存 |
| Stage 7: 継続改善 | 継続 | — |
| **合計（初回1案件）** | **約1〜2週間** | |
| **合計（チーム定着まで）** | **約3〜4週間** | |

## 付録C: ファイル一覧・参照先マップ

| 作業で困ったとき | 参照ドキュメント |
|---------------|----------------|
| フレームワーク全体の仕組みを知りたい | `01_architecture.md` |
| エージェントの仕様を確認したい | `02_agent_definitions.md` |
| 各フェーズの詳細手順を知りたい | `03_execution_playbook.md` |
| 設定ファイルのテンプレートが欲しい | `04_configuration_templates.md` |
| 品質基準やトラブル対処を知りたい | `05_quality_and_operations.md` |
| Copilot CLI と Claude Code の対応を知りたい | `copilot-cli-migration-guide.md` |
