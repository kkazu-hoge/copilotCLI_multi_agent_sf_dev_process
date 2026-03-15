# フェーズ別実行手順書（Execution Playbook）— Copilot CLI版

> 本ドキュメントは、Copilot CLI のカスタムエージェントを活用した Salesforce 開発プロセスの各フェーズについて、運用者が定型的に実行できるレベルで手順を記述したものである。

---

## 目次

1. [Phase 0: 初期セットアップ & メタデータ取得](#phase-0-初期セットアップ--メタデータ取得)
2. [Phase 1: 要件定義](#phase-1-要件定義)
3. [Phase 2: 設計](#phase-2-設計)
4. [Phase 3: 実装](#phase-3-実装)
5. [Phase 4: テスト](#phase-4-テスト)
6. [Phase 5: コードレビュー](#phase-5-コードレビュー)
7. [Phase 6: PR作成](#phase-6-pr作成)
8. [付録: フェーズ横断リファレンス](#付録-フェーズ横断リファレンス)

---

## フェーズ全体フロー概要

```
Phase 0          Phase 1        Phase 2       Phase 3       Phase 4        Phase 5         Phase 6
初期セットアップ → 要件定義     → 設計        → 実装        → テスト        → コードレビュー → PR作成
& メタデータ取得   [承認ゲート]    [承認ゲート]                  [承認ゲート]     [承認ゲート]
```

各フェーズ間のヒューマンゲート（承認ステップ）は案件設定ファイル（`docs/projects/{PROJECT_ID}/project-config.json`）の `humanGates` セクションで有効/無効を切り替え可能。詳細は `01_architecture.md` および `04_configuration_templates.md` を参照。

---

## Phase 0: 初期セットアップ & メタデータ取得

### エントリー条件

- [ ] Salesforce CLI (`sf`) v2 がインストール済みであること
- [ ] GitHub Copilot CLI（GA版）がインストール済みであること
- [ ] 対象 Salesforce 組織への認証が完了していること（`sf org login` 済み）
- [ ] sfdx-project.json が存在するプロジェクトディレクトリが準備されていること
- [ ] Git リポジトリが初期化済みであること

### 手順1-1: プロジェクトディレクトリの初期構成

```bash
# プロジェクトルートに移動
cd /path/to/salesforce-project

# ディレクトリ構成を作成
mkdir -p .github/agents
mkdir -p docs/requirements
mkdir -p docs/design
mkdir -p docs/test-results
mkdir -p docs/review
mkdir -p metadata-catalog/schema/objects
mkdir -p metadata-catalog/catalog
mkdir -p metadata-catalog/scripts
mkdir -p metadata-catalog/config

# サブエージェント定義ファイルを配置（02_subagent_definitions.md に基づく）
# .github/agents/sf-metadata-analyst.md
# .github/agents/sf-requirements-analyst.md
# .github/agents/sf-designer.md
# .github/agents/sf-implementer.md
# .github/agents/sf-tester.md
# .github/agents/sf-code-reviewer.md
```

### 手順1-2: 対象組織の認証確認

```bash
# 認証済み組織の一覧を確認
sf org list

# 対象組織へのアクセスを確認
sf org display --target-org <対象組織エイリアス>

# 認証が切れている場合は再認証
sf org login web --alias <対象組織エイリアス> --instance-url https://login.salesforce.com
```

### 手順1-3: Must Have メタデータの一括取得

```bash
# Must Have メタデータの一括取得
# CustomObject / CustomField / RecordType / ValidationRule
sf project retrieve start \
  --metadata CustomObject CustomField RecordType ValidationRule \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/objects

# ApexClass / ApexTrigger
sf project retrieve start \
  --metadata ApexClass ApexTrigger \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/apex

# Flow / FlowDefinition
sf project retrieve start \
  --metadata Flow FlowDefinition \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/flows

# Profile / PermissionSet
sf project retrieve start \
  --metadata Profile PermissionSet \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/permissions

# PageLayout
sf project retrieve start \
  --metadata Layout \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/layouts

# LightningComponentBundle (LWC)
sf project retrieve start \
  --metadata LightningComponentBundle \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/lwc

# PicklistValue / GlobalValueSet
sf project retrieve start \
  --metadata GlobalValueSet StandardValueSet \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/picklists
```

**一括取得用ワンライナー（全 Must Have を一度に取得）:**

```bash
sf project retrieve start \
  --metadata CustomObject CustomField RecordType ValidationRule \
    ApexClass ApexTrigger Flow FlowDefinition \
    Profile PermissionSet Layout LightningComponentBundle \
    GlobalValueSet StandardValueSet \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata
```

### 手順1-4: メタデータの構造化変換（sf-metadata-analyst の呼び出し）

Copilot CLI を起動し、`sf-metadata-analyst` カスタムエージェントにメタデータの構造化を指示する。

```bash
# Copilot CLI CLI を起動
copilot

# 以下のプロンプトをCopilot CLI内で実行
```

**Copilot CLI 内で実行するプロンプト:**

```
@sf-metadata-analyst ./raw-metadata ディレクトリに取得済みのSalesforceメタデータがあります。
以下の作業を実行してください:

1. raw-metadata/ 内の全メタデータXMLを解析し、オブジェクトごとの構造化JSONを
   metadata-catalog/schema/objects/ に生成してください。
   各JSONには以下を含めること:
   - api_name, label, description
   - fields（api_name, label, type, required, picklist_values, formula, reference_to）
   - validation_rules（api_name, active, condition, error_message）
   - record_types（api_name, label）

2. 全リレーション情報を metadata-catalog/schema/relationships.json に生成してください。
   - from_object, from_field, to_object, type, cardinality, delete_constraint

3. 全体統計を metadata-catalog/schema/schema_summary.json に生成してください。
   - オブジェクト数、項目数、リレーション数、Apex クラス数、フロー数

対象組織: <対象組織エイリアス>
```

### 手順1-5: メタデータカタログの初回構築

```
@sf-metadata-analyst metadata-catalog/schema/ の構造化データに基づき、
以下のカタログファイルを生成してください:

1. metadata-catalog/catalog/object_dictionary.json
   - 各オブジェクトの category, business_domain, description, related_objects, key_automations

2. metadata-catalog/catalog/field_dictionary.json
   - 全項目の横断一覧（object, api_name, label, type, business_meaning）

3. metadata-catalog/catalog/automation_inventory.json
   - 全ApexTrigger/Flow の一覧（type, object, events, description, dependencies）

4. metadata-catalog/catalog/permission_matrix.json
   - Profile/PermissionSet ごとのオブジェクト権限・FLS 一覧

5. metadata-catalog/catalog/glossary.json
   - 業務用語とAPI名のマッピング（初版として主要用語を自動推定）

※ descriptionが不明な項目には "[要記入]" を設定してください。
```

### 手順1-6: AGENTS.md の作成

プロジェクトルートに `AGENTS.md` を作成する。以下のテンプレートに案件情報を記入する。

```markdown
# プロジェクト: [案件名]

## 概要
- 対象組織: [組織エイリアス / 組織ID]
- 開発範囲: [概要を1〜2行で記述]
- 案件ブランチ: [feature/xxx]

## Salesforce 開発規約
- 命名規約: クラス名は PascalCase、メソッド名は camelCase、カスタム項目は PascalCase__c
- ガバナ制限: SOQLクエリはループ内禁止、DMLは一括操作、1トランザクションあたりSOQL 100回以内
- FLS準拠: CRUD/FLS チェックを全DML操作に適用（Security.stripInaccessible または WITH SECURITY_ENFORCED）
- バルク化: 全トリガ/クラスは200レコード一括処理に対応すること
- テスト: カバレッジ75%以上（目標85%）、正常系・異常系・バルクテスト必須

## コミット規約
- フォーマット: `<type>(<scope>): <subject>`
- type: feat / fix / refactor / test / docs / chore
- scope: apex / lwc / flow / metadata / config
- 例: `feat(apex): AccountTriggerHandler に取引先グレーディングロジックを追加`

## メタデータカタログ
- スキーマ情報: metadata-catalog/schema/
- カタログ情報: metadata-catalog/catalog/
- ※ 実装・設計時は必ずカタログを参照し、既存のオブジェクト構造・自動化ロジックとの整合性を確認すること

## サブエージェント利用ガイドライン
- 各サブエージェントは .github/agents/ に定義済み
- サブエージェントは順序通りに呼び出すこと（要件定義 → 設計 → 実装 → テスト → レビュー）
- 前フェーズの成果物を必ず入力として渡すこと
- ヒューマンゲートが有効な場合、次フェーズに進む前に人間の承認を得ること
```

### 中間成果物

| ファイル/ディレクトリ | 説明 |
|---|---|
| `raw-metadata/` | Salesforce組織から取得した生メタデータ |
| `metadata-catalog/schema/objects/*.json` | オブジェクト別構造化JSON |
| `metadata-catalog/schema/relationships.json` | リレーションマップ |
| `metadata-catalog/schema/schema_summary.json` | 全体統計サマリ |
| `metadata-catalog/catalog/object_dictionary.json` | オブジェクト辞書 |
| `metadata-catalog/catalog/field_dictionary.json` | 項目辞書 |
| `metadata-catalog/catalog/automation_inventory.json` | 自動化ロジック一覧 |
| `metadata-catalog/catalog/permission_matrix.json` | 権限マトリクス |
| `metadata-catalog/catalog/glossary.json` | 業務用語グロサリー |
| `AGENTS.md` | プロジェクト設定ファイル |
| `.github/agents/*.md` | サブエージェント定義ファイル |

### 完了条件

- [ ] 全 Must Have メタデータが `raw-metadata/` に取得されている
- [ ] `schema/objects/` に主要オブジェクトの構造化 JSON が生成されている
- [ ] `relationships.json` にリレーションマップが生成されている
- [ ] `schema_summary.json` で全体統計が確認できる
- [ ] カタログの5ファイルがすべて生成されている
- [ ] `AGENTS.md` に案件情報が記入されている
- [ ] サブエージェント定義ファイルが `.github/agents/` に配置されている
- [ ] 初期状態を Git にコミット済み

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| `sf project retrieve start` がタイムアウトする | メタデータ種別を分割して個別に取得する。大規模組織では CustomObject と CustomField を別々に取得する |
| 認証エラー（`INVALID_SESSION_ID`） | `sf org login web` で再認証。JWT認証の場合は証明書の有効期限を確認 |
| メタデータ量が多すぎてコンテキストに収まらない | `extraction_config.yaml` で対象オブジェクトを主要なものに限定する。除外パターン（`*_History`, `*_Share` 等）を設定 |
| 構造化変換で一部オブジェクトが失敗する | `schema_summary.json` のエラーセクションを確認し、該当オブジェクトのみ手動で再変換。XMLの構文エラーが原因の場合は生メタデータを確認 |
| LWC のメタデータが取得できない | `LightningComponentBundle` ではなく、`sfdx-project.json` の `packageDirectories` パスを確認。ネームスペース付きの場合はプレフィックスを指定 |

---

## Phase 1: 要件定義

### エントリー条件

- [ ] Phase 0が完了し、メタデータカタログが構築済みであること
- [ ] ユーザー要件（自然言語またはテンプレート形式）が準備されていること
- [ ] 案件用ブランチが作成されていること

### 手順1-1: 案件ブランチの作成

```bash
# 案件用ブランチを作成
git checkout -b feature/<案件ID>-<簡潔な説明>

# 例:
git checkout -b feature/SFDC-001-account-grading
```

### 手順2-2: ユーザー要件の準備

以下のテンプレートに要件を記入し、`docs/projects/{PROJECT_ID}/requirements/user_requirements.md` として保存する。

```markdown
# ユーザー要件書

## 基本情報
- 案件ID: [SFDC-XXX]
- 要件名: [機能名称]
- 要求者: [部署名 / 担当者名]
- 優先度: [高 / 中 / 低]
- 希望納期: [YYYY-MM-DD]

## 背景・目的
[この機能がなぜ必要なのか、業務上の背景を記述]

## 機能要件
### やりたいこと（What）
1. [要件1: 具体的な機能の説明]
2. [要件2: 具体的な機能の説明]
3. [要件3: 具体的な機能の説明]

### ユーザーストーリー
- [ペルソナ] として、[操作/機能] をしたい。なぜなら [理由/目的] だから。

### 業務フロー（現状 → あるべき姿）
- 現状: [現在の業務フロー]
- あるべき姿: [この機能導入後の業務フロー]

## 非機能要件
- パフォーマンス: [期待するレスポンス時間等]
- データ量: [想定レコード数]
- 利用ユーザー数: [想定同時利用者数]

## 対象オブジェクト（既知の場合）
- [オブジェクト名1]
- [オブジェクト名2]

## 制約事項・前提条件
- [制約1]
- [制約2]

## 補足情報
- [参考資料、画面イメージ、既存の関連機能等]
```

### 手順2-3: sf-requirements-analyst の呼び出し

```bash
# Copilot CLI CLI を起動（未起動の場合）
copilot
```

**Copilot CLI 内で実行するプロンプト:**

```
@sf-requirements-analyst 以下のインプットに基づき、要件定義書を作成してください。

## インプット
1. ユーザー要件: docs/projects/{PROJECT_ID}/requirements/user_requirements.md
2. メタデータカタログ: metadata-catalog/catalog/
3. スキーマ情報: metadata-catalog/schema/
4. システムコンテキスト図: docs/architecture/system-context.md
5. 横断的方針: docs/architecture/policies/

## 出力先
docs/projects/{PROJECT_ID}/requirements/requirements_specification.md

## 作業指示
1. ユーザー要件を読み込み、業務要件を整理してください
2. システムコンテキスト図を参照し、外部連携への影響を評価してください
3. 横断的方針（セキュリティ・パフォーマンス・連携方針）との整合性を確認してください
4. メタデータカタログと照合し、以下を特定してください:
   - 影響を受ける既存オブジェクト・項目
   - 新規作成が必要なオブジェクト・項目
   - 影響を受ける既存の自動化ロジック（Apex/Flow）
   - 必要な権限変更
5. 要件の実現可能性を評価し、リスクや懸念事項を洗い出してください
6. 要件定義書を以下の構成で出力してください:
   - 機能要件一覧（ID付き、優先度付き）
   - データモデル変更案（新規/変更オブジェクト・項目の一覧）
   - 既存資産への影響分析
   - 横断的方針への準拠確認結果
   - 技術的リスク・制約事項
   - 追加で取得すべき Nice to Have メタデータの推奨リスト
```

### 手順2-4: 要件定義書の確認ポイント

要件定義書が出力されたら、以下の観点でレビューする。

| 確認観点 | チェック内容 |
|---|---|
| 要件の網羅性 | ユーザー要件書の全項目が要件定義書に反映されているか |
| 既存資産との整合性 | 既存オブジェクト・フロー・トリガとの競合がないか |
| データモデルの妥当性 | 新規項目の型・リレーションが適切か。標準項目で代替できるものはないか |
| ガバナ制限への配慮 | 大量データ処理・複雑なクエリが必要な要件にリスク注記があるか |
| セキュリティ考慮 | FLS・共有ルールの影響が記載されているか |
| 横断的方針との整合性 | `docs/architecture/policies/` のセキュリティ方針・パフォーマンス方針・連携方針と矛盾がないか |
| 外部連携への影響 | `docs/architecture/system-context.md` のインテグレーションマップに影響がある場合、その旨が記載されているか |
| Nice to Have 推奨 | 設計フェーズで追加取得すべきメタデータが明記されているか |

### 手順2-5: ヒューマンゲート（要件定義書の承認フロー）

> ヒューマンゲートが無効の場合（`humanGates.gate_requirements: false`）、この手順は自動スキップされる。

リードエージェントは以下を実行する:

1. `docs/projects/{PROJECT_ID}/project-config.json` の `humanGates.gate_requirements` を確認する

```bash
jq -r '.humanGates.gate_requirements' docs/projects/${PROJECT_ID}/project-config.json
```

2. 値が `true` の場合、以下の形式で出力し、ターンを終了する:

```
## 要件定義完了 — 承認待ち

### 成果物
- `docs/projects/{PROJECT_ID}/requirements/requirements_specification.md`

### 確認ポイント
- ユーザー要件がすべて反映されているか
- 既存メタデータとの整合性に問題がないか
- 影響範囲分析が網羅的か
- 未決事項（Open Items）の内容が妥当か
- Nice to Have メタデータの追加取得要否が適切か

### 次のアクション
以下のいずれかで応答してください:
- **承認** → Phase 2（設計）に進行します
- **差し戻し** + 修正指示 → 要件定義を再実行します
- **中断** → 処理を停止します

⏳ 承認待ちのため、応答があるまで次フェーズには進みません。
```

3. 人間の応答を受け取り、承認の場合は Phase 2 に進む
4. 差し戻しの場合は、修正指示を `sf-requirements-analyst` に渡して再実行する:

```
@sf-requirements-analyst docs/projects/{PROJECT_ID}/requirements/requirements_specification.md を以下のレビューコメントに基づいて修正してください:

## レビューコメント
1. [コメント1]
2. [コメント2]

修正後のファイルを同じパスに上書き保存してください。
変更箇所には「[修正]」マークを付与してください。
```

5. 承認が得られたら、要件定義書をコミットし、次フェーズに進む

```bash
git add docs/projects/{PROJECT_ID}/requirements/
git commit -m "docs(requirements): SFDC-XXX 要件定義書を作成"
```

### 中間成果物

| ファイル | 説明 |
|---|---|
| `docs/projects/{PROJECT_ID}/requirements/user_requirements.md` | ユーザー要件書（インプット） |
| `docs/projects/{PROJECT_ID}/requirements/requirements_specification.md` | 要件定義書（出力） |

### 完了条件

- [ ] 要件定義書が `docs/projects/{PROJECT_ID}/requirements/requirements_specification.md` に出力されている
- [ ] 全機能要件に ID と優先度が付与されている
- [ ] 既存資産への影響分析が記載されている
- [ ] 追加取得すべき Nice to Have メタデータが明記されている
- [ ] ヒューマンゲートが有効な場合、承認が得られている
- [ ] 要件定義書が Git にコミット済み

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| サブエージェントがメタデータカタログを正しく参照できない | カタログのファイルパスが正しいか確認。`schema_summary.json` の存在を確認し、必要に応じてフェーズ1の構造化変換をやり直す |
| 要件が曖昧で定義書の品質が低い | ユーザー要件書のテンプレートを埋め直す。特に「ユーザーストーリー」と「業務フロー」の項目を具体化する |
| 既存メタデータとの照合で不整合が検出される | メタデータカタログの鮮度を確認。組織上で最近変更があった場合は `sf project retrieve start` で差分取得し、カタログを更新する |
| コンテキストが溢れる（大量のメタデータ参照） | `/compact` を実行してコンテキストを圧縮。あるいは対象オブジェクトを限定して段階的に処理する |

---

## Phase 2: 設計

### エントリー条件

- [ ] Phase 1が完了し、要件定義書が承認済みであること
- [ ] 要件定義書に記載された Nice to Have メタデータの追加取得要否が判断されていること

### 手順3-1: Nice to Have メタデータの追加取得

要件定義書の「追加取得すべき Nice to Have メタデータ」セクションを確認し、必要に応じて追加取得する。

**追加取得の判断基準:**

| メタデータ種別 | 取得する場合 |
|---|---|
| CustomMetadataType / CustomSetting | 設定値による分岐ロジックが要件に含まれる場合 |
| CustomLabel | 多言語対応やエラーメッセージのカスタマイズが必要な場合 |
| FlexiPage | Lightning ページのカスタマイズが要件に含まれる場合 |
| CompactLayout | モバイル表示のカスタマイズが必要な場合 |
| ListView | 一覧表示のカスタマイズが要件に含まれる場合 |
| Report / ReportType | レポート関連の開発が要件に含まれる場合 |
| SharingRule | 共有ルールの変更が必要な場合 |
| ApexTestClass | 既存テストの把握が必要な場合（テストフェーズに先立ち） |
| WorkflowRule / ProcessBuilder | レガシー自動化からの移行が要件に含まれる場合 |
| DuplicateRule / MatchingRule | 重複チェック機能の開発が要件に含まれる場合 |

```bash
# 例: CustomMetadataType と CustomLabel を追加取得
sf project retrieve start \
  --metadata CustomMetadataType CustomLabel \
  --target-org <対象組織エイリアス> \
  --output-dir ./raw-metadata/nice-to-have
```

追加取得したメタデータもカタログに反映する:

```
@sf-metadata-analyst ./raw-metadata/nice-to-have に追加取得したメタデータがあります。
既存の metadata-catalog/schema/ および metadata-catalog/catalog/ に
追加取得分をマージしてください。既存データは上書きせず、差分のみ追加してください。
```

### 手順3-2: sf-designer の呼び出し

```
@sf-designer 以下のインプットに基づき、技術設計書を作成してください。

## インプット
1. 要件定義書: docs/projects/{PROJECT_ID}/requirements/requirements_specification.md
2. メタデータカタログ: metadata-catalog/catalog/
3. スキーマ情報: metadata-catalog/schema/
4. システムコンテキスト図: docs/architecture/system-context.md
5. ADR（設計判断記録）: docs/architecture/decisions/
6. 横断的方針: docs/architecture/policies/

## 出力先
docs/projects/{PROJECT_ID}/design/ ディレクトリ配下に以下のファイルを生成してください。

## 作業指示
要件定義書の各機能要件について、以下の技術設計書を作成してください:

### 1. データモデル設計（docs/projects/{PROJECT_ID}/design/data_model_design.md）
- 新規オブジェクト定義（API名、ラベル、説明、共有モデル）
- 新規項目定義（API名、型、桁数、必須/任意、デフォルト値、ヘルプテキスト）
- 項目変更（既存項目の修正内容）
- リレーション設計（Lookup/MasterDetail、カスケード削除の方針）
- レコードタイプ設計
- 入力規則設計

### 2. Apex 設計（docs/projects/{PROJECT_ID}/design/apex_design.md）
- クラス設計（クラス名、責務、主要メソッド、入出力）
- トリガ設計（対象オブジェクト、イベント、処理概要）
- トリガハンドラパターンの適用方針
- 既存クラスへの影響・修正箇所
- ガバナ制限への対策（SOQL/DMLの最適化方針）
- FLS/CRUD チェック方針

### 3. LWC 設計（docs/projects/{PROJECT_ID}/design/lwc_design.md）※ UI要件がある場合のみ
- コンポーネント設計（名称、責務、プロパティ、イベント）
- Wire/Imperative Apex の使い分け
- 親子コンポーネント構成
- 既存LWCとの関係

### 4. フロー設計（docs/projects/{PROJECT_ID}/design/flow_design.md）※ 宣言的自動化が必要な場合のみ
- フロー種別（Record-Triggered / Screen / Autolaunched）
- トリガ条件（オブジェクト、イベント、条件）
- 処理フロー（ステップ一覧）
- エラーハンドリング方針
- 既存フローとの競合チェック結果

### 5. 実装計画（docs/projects/{PROJECT_ID}/design/implementation_plan.md）
- 実装タスク一覧（ID、概要、推定工数、優先順序）
- タスク間の依存関係
- ファイルオーナーシップ（どのファイルをどのタスクで作成/変更するか）
- 推奨実装順序
```

### 手順3-3: 設計書のレビュー観点

| 確認観点 | チェック内容 |
|---|---|
| 要件トレーサビリティ | 全機能要件IDが設計書内で参照されているか |
| ガバナ制限 | SOQLはループ外、DMLは一括操作、Limits考慮が記載されているか |
| FLS/CRUD | 全DML操作にセキュリティチェック方針が記載されているか |
| バルク化 | トリガ/クラスが200レコード一括処理を前提としているか |
| 既存資産との整合性 | 既存トリガ・フローとの実行順序・競合が検討されているか |
| ADRとの整合性 | `docs/architecture/decisions/` の既存ADR（トリガハンドラパターン、Named Credential必須化等）と矛盾しないか |
| 横断的方針への準拠 | `docs/architecture/policies/` のセキュリティ方針・パフォーマンス方針・連携方針・エラーハンドリング方針に準拠しているか |
| レイヤー構成の遵守 | `docs/architecture/system-context.md` のレイヤー構成（UI→コントローラー→サービス→データアクセス）に沿った設計になっているか |
| テスト容易性 | テストデータ作成の容易さ、モック可能な構造になっているか |
| 命名規約 | クラス名・メソッド名・項目名がプロジェクト規約に準拠しているか |
| ADR提案の要否 | 重要な設計判断を行っている場合、新規ADRの作成が提案されているか |

### 手順3-4: ヒューマンゲート（設計書の承認フロー）

> ヒューマンゲートが無効の場合（`humanGates.gate_design: false`）、この手順は自動スキップされる。

リードエージェントは以下を実行する:

1. `docs/projects/{PROJECT_ID}/project-config.json` の `humanGates.gate_design` を確認する

```bash
jq -r '.humanGates.gate_design' docs/projects/${PROJECT_ID}/project-config.json
```

2. 値が `true` の場合、以下の形式で出力し、ターンを終了する:

```
## 設計完了 — 承認待ち

### 成果物
- `docs/projects/{PROJECT_ID}/design/data_model_design.md`
- `docs/projects/{PROJECT_ID}/design/apex_design.md`
- `docs/projects/{PROJECT_ID}/design/lwc_design.md`（該当する場合）
- `docs/projects/{PROJECT_ID}/design/flow_design.md`（該当する場合）
- `docs/projects/{PROJECT_ID}/design/implementation_plan.md`

### 確認ポイント
- 要件定義書の全項目が設計書内で参照されているか
- ガバナ制限の事前評価が記載されているか
- FLS/CRUD権限チェック方針が明記されているか
- 既存ADR・横断的方針と矛盾がないか
- 実装順序と依存関係が明確か

### 次のアクション
以下のいずれかで応答してください:
- **承認** → Phase 3（実装）に進行します
- **差し戻し** + 修正指示 → 設計書を修正します
- **中断** → 処理を停止します

⏳ 承認待ちのため、応答があるまで次フェーズには進みません。
```

3. 人間の応答を受け取り、承認の場合は Phase 3 に進む
4. 差し戻しの場合は、修正指示を `sf-designer` に渡して再実行する:

```
@sf-designer docs/projects/{PROJECT_ID}/design/ 配下の設計書を以下のレビューコメントに基づいて修正してください:

## レビューコメント
1. [コメント1: 対象ファイルと箇所を明記]
2. [コメント2: 対象ファイルと箇所を明記]

修正後のファイルを同じパスに上書き保存してください。
変更箇所には「[修正]」マークを付与してください。
```

5. 承認が得られたら、設計書をコミットする

```bash
git add docs/projects/{PROJECT_ID}/design/
git commit -m "docs(design): SFDC-XXX 技術設計書を作成"
```

### 中間成果物

| ファイル | 説明 |
|---|---|
| `docs/projects/{PROJECT_ID}/design/data_model_design.md` | データモデル設計書 |
| `docs/projects/{PROJECT_ID}/design/apex_design.md` | Apex 設計書 |
| `docs/projects/{PROJECT_ID}/design/lwc_design.md` | LWC 設計書（該当する場合） |
| `docs/projects/{PROJECT_ID}/design/flow_design.md` | フロー設計書（該当する場合） |
| `docs/projects/{PROJECT_ID}/design/implementation_plan.md` | 実装計画書 |

### 完了条件

- [ ] データモデル設計書が出力されている
- [ ] 実装対象に応じた設計書（Apex / LWC / フロー）が出力されている
- [ ] 実装計画書にタスク一覧・依存関係・ファイルオーナーシップが記載されている
- [ ] ヒューマンゲートが有効な場合、承認が得られている
- [ ] 設計書が Git にコミット済み

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| 設計書が要件を満たしていない | 要件定義書と設計書を再度付き合わせ、漏れている要件IDを明示して `sf-designer` に修正を指示 |
| 既存資産との競合が設計段階で判明 | 要件定義書にフィードバックし、必要に応じてフェーズ2に戻る。要件の優先度を再評価 |
| Nice to Have メタデータの追加取得が必要と判明 | 手順3-1に戻り、追加取得を実施。カタログ更新後に設計書を再生成 |
| コンテキストが溢れる | `/compact` を実行。設計書の生成を「データモデル → Apex → LWC → フロー」と段階的に分割して実行 |

---

## Phase 3: 実装

### エントリー条件

- [ ] Phase 2が完了し、設計書が承認済みであること
- [ ] 実装計画書（`docs/projects/{PROJECT_ID}/design/implementation_plan.md`）のタスク一覧が確定していること
- [ ] ファイルオーナーシップが明確になっていること

### 手順4-1: 実装タスクの分割戦略

`sf-implementer` サブエージェントに渡すタスクは以下の基準で分割する。

**1サブエージェント呼び出しあたりのタスク量目安:**

| 実装カテゴリ | 1回あたりの上限目安 | 理由 |
|---|---|---|
| Apexクラス | 2〜3クラス（合計300行以内） | コンテキスト内でクラス間の整合性を保つため |
| Apexトリガ | 1トリガ + ハンドラ1クラス | トリガとハンドラの一貫性を保つため |
| LWC | 1コンポーネント（HTML + JS + CSS） | コンポーネント内の整合性を保つため |
| フローメタデータ | 1フロー | フローは単独で完結するため |
| データモデル変更 | 1オブジェクト + 関連項目 | リレーション整合性を保つため |

**推奨実装順序:**

1. データモデル変更（オブジェクト・項目の作成/変更）
2. ユーティリティクラス・共通クラス
3. トリガハンドラ・サービスクラス
4. トリガ
5. LWC（UI がある場合）
6. フロー（宣言的自動化がある場合）

### 手順4-2: ファイルオーナーシップの管理方針

サブエージェント間のファイル競合を防ぐために、以下のルールを適用する。

1. **1つのファイルは1回のサブエージェント呼び出しでのみ作成/変更する**
2. 実装計画書の「ファイルオーナーシップ」セクションに基づき、各呼び出しで変更対象のファイルを明示的に指定する
3. 共通ユーティリティクラスは最初のタスクで作成し、後続タスクでは参照のみとする
4. 既存ファイルを変更する場合は、変更箇所を設計書で限定し、指示に明記する

### 手順4-3: sf-implementer の呼び出し（基本パターン）

```
@sf-implementer 以下の設計書に基づき、実装タスク [タスクID] を実装してください。

## インプット
1. 設計書: docs/projects/{PROJECT_ID}/design/apex_design.md（該当セクション: [セクション名]）
2. データモデル設計: docs/projects/{PROJECT_ID}/design/data_model_design.md
3. 既存コード参照: force-app/main/default/classes/[関連クラス名].cls
4. メタデータカタログ: metadata-catalog/catalog/

## 実装対象
- [作成するファイル1のパス]: [概要]
- [作成するファイル2のパス]: [概要]

## 実装ルール
- Salesforce 開発規約（AGENTS.md参照）に準拠すること
- ガバナ制限を遵守すること（ループ内SOQL禁止、DML一括操作）
- FLS/CRUD チェックを全DML操作に適用すること
- バルク化対応すること（Trigger.new が200件でも動作する設計）
- 全 public メソッドに JavaDoc スタイルのコメントを付与すること
- テストで使用するための @TestVisible アノテーションを必要に応じて付与すること
```

### 手順4-4: sf-implementer の呼び出し（実装カテゴリ別の例）

#### Apex トリガ + ハンドラの実装

```
@sf-implementer 設計書 docs/projects/{PROJECT_ID}/design/apex_design.md の「AccountTrigger」セクションに基づき、
以下のファイルを実装してください。

## 作成ファイル
1. force-app/main/default/triggers/AccountTrigger.trigger
   - before insert, before update, after update イベントを処理
   - TriggerHandler パターンを適用
2. force-app/main/default/classes/AccountTriggerHandler.cls
   - トリガから呼び出されるハンドラクラス
   - 各イベントの処理メソッドを実装
3. force-app/main/default/classes/AccountTriggerHandler.cls-meta.xml
   - APIバージョン: 62.0

## 参照（変更不可）
- force-app/main/default/classes/TriggerHandler.cls（既存の基底クラス）
- metadata-catalog/schema/objects/Account.json

## 実装ルール
- AGENTS.md の開発規約に準拠すること
```

#### LWC コンポーネントの実装

```
@sf-implementer 設計書 docs/projects/{PROJECT_ID}/design/lwc_design.md の「accountGradingPanel」セクションに基づき、
以下のファイルを実装してください。

## 作成ファイル
1. force-app/main/default/lwc/accountGradingPanel/accountGradingPanel.html
2. force-app/main/default/lwc/accountGradingPanel/accountGradingPanel.js
3. force-app/main/default/lwc/accountGradingPanel/accountGradingPanel.css
4. force-app/main/default/lwc/accountGradingPanel/accountGradingPanel.js-meta.xml

## 参照（変更不可）
- force-app/main/default/classes/AccountGradingController.cls（Apex コントローラ）
- docs/projects/{PROJECT_ID}/design/lwc_design.md の画面レイアウト仕様

## 実装ルール
- @wire デコレータで Apex メソッドを呼び出すこと
- エラーハンドリングを実装し、ユーザーに toast メッセージで通知すること
- lightning-datatable を使用する場合はページネーションを実装すること
```

#### データモデル変更（メタデータ XML の生成）

```
@sf-implementer 設計書 docs/projects/{PROJECT_ID}/design/data_model_design.md に基づき、
以下のメタデータファイルを生成してください。

## 作成ファイル
1. force-app/main/default/objects/Account/fields/Grade__c.field-meta.xml
   - 型: Picklist、値: A, B, C, D
2. force-app/main/default/objects/Account/fields/LastGradingDate__c.field-meta.xml
   - 型: Date
3. force-app/main/default/objects/Account/validationRules/Grade_Required_For_Active.validationRule-meta.xml
   - 条件: Active__c = true かつ Grade__c が空

## 参照
- metadata-catalog/schema/objects/Account.json（既存項目との重複確認）
```

### 手順4-5: コミット粒度とメッセージ規約

実装完了後、以下の粒度でコミットする。

**コミット粒度:**

| 単位 | コミットメッセージ例 |
|---|---|
| 1トリガ + ハンドラ | `feat(apex): AccountTrigger と AccountTriggerHandler を実装` |
| 1サービスクラス | `feat(apex): AccountGradingService を実装` |
| 1 LWC コンポーネント | `feat(lwc): accountGradingPanel コンポーネントを実装` |
| データモデル変更一式 | `feat(metadata): Account オブジェクトにグレーディング関連項目を追加` |
| 1フロー | `feat(flow): Account グレーディング自動計算フローを実装` |

```bash
# コミットの実行例
git add force-app/main/default/triggers/AccountTrigger.trigger
git add force-app/main/default/classes/AccountTriggerHandler.cls
git add force-app/main/default/classes/AccountTriggerHandler.cls-meta.xml
git commit -m "feat(apex): AccountTrigger と AccountTriggerHandler を実装

- before insert / before update / after update イベントを処理
- TriggerHandler パターンを適用
- ガバナ制限・FLS チェック対応済み

Refs: SFDC-XXX"
```

### 中間成果物

| ファイル/ディレクトリ | 説明 |
|---|---|
| `force-app/main/default/classes/*.cls` | Apex クラス |
| `force-app/main/default/triggers/*.trigger` | Apex トリガ |
| `force-app/main/default/lwc/*` | LWC コンポーネント |
| `force-app/main/default/flows/*.flow-meta.xml` | フロー定義 |
| `force-app/main/default/objects/*/fields/*.field-meta.xml` | カスタム項目 |
| `force-app/main/default/objects/*/validationRules/*.validationRule-meta.xml` | 入力規則 |

### 完了条件

- [ ] 実装計画書の全タスクが実装されている
- [ ] 全ファイルが Git にコミット済み
- [ ] コミットメッセージがプロジェクト規約に準拠している
- [ ] コードが構文的に正しい（明らかなコンパイルエラーがない）
- [ ] AGENTS.md の開発規約（ガバナ制限、FLS、バルク化）が遵守されている

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| サブエージェントが設計書と異なる実装をする | 設計書の該当セクションを引用して再実装を指示。具体的なメソッドシグネチャやクラス名を明示する |
| ファイル競合が発生する | 競合ファイルを特定し、最新のコミットをベースに再実装を指示。`git diff` で差分を確認 |
| コンテキストが溢れる | `/compact` を実行し、タスクをより細かく分割して再実行。1回の呼び出しで1クラスのみに限定する |
| 既存コードとの整合性が取れない | 既存コードの該当部分を明示的にプロンプトに含め、変更箇所を具体的に指示する |
| Apex コンパイルエラーが検出される | エラーメッセージを `sf-implementer` に渡して修正を指示: `@sf-implementer 以下のコンパイルエラーを修正してください: [エラーメッセージ]` |

---

## Phase 4: テスト

### エントリー条件

- [ ] Phase 3が完了し、全実装コードがコミット済みであること
- [ ] テスト対象のクラス・トリガが明確であること

### 手順5-1: sf-tester の呼び出し（テストコード作成）

```
@sf-tester 以下のインプットに基づき、Apex テストクラスを作成してください。

## インプット
1. 設計書: docs/projects/{PROJECT_ID}/design/apex_design.md
2. 実装コード:
   - force-app/main/default/classes/AccountTriggerHandler.cls
   - force-app/main/default/classes/AccountGradingService.cls
   - force-app/main/default/triggers/AccountTrigger.trigger
3. データモデル: docs/projects/{PROJECT_ID}/design/data_model_design.md
4. メタデータカタログ: metadata-catalog/schema/objects/Account.json

## 出力先
- force-app/main/default/classes/AccountTriggerHandlerTest.cls
- force-app/main/default/classes/AccountGradingServiceTest.cls

## テスト作成ルール
1. テストデータは TestDataFactory パターンで作成すること
2. 以下のテストケースを網羅すること:
   - 正常系: 期待通りの入力で期待通りの結果が得られること
   - 異常系: 不正な入力でエラーが適切にハンドリングされること
   - バルクテスト: 200件のレコードで正常動作すること
   - 権限テスト: 異なるプロファイルでの動作確認（可能な場合）
   - 境界値テスト: 境界値での動作確認
3. @TestSetup メソッドで共通テストデータを作成すること
4. System.assert / System.assertEquals には必ずメッセージ引数を付与すること
5. Test.startTest() / Test.stopTest() でガバナ制限のリセットを活用すること
6. カバレッジ目標: 各クラス85%以上、全体75%以上
```

### 手順5-2: テスト実行 → 失敗分析 → 修正の自律ループ

テストの実行と修正は、以下の自律ループで行う。運用者は最終結果のみ確認する。

```
@sf-tester 作成したテストクラスを実行し、結果を分析してください。

## 実行手順
1. 以下のコマンドでテストを実行してください:
   sf apex run test \
     --class-names AccountTriggerHandlerTest AccountGradingServiceTest \
     --result-format json \
     --code-coverage \
     --target-org <対象組織エイリアス> \
     --wait 10

2. テスト結果を分析し、以下を報告してください:
   - 成功/失敗の概要
   - 失敗テストの原因分析
   - コードカバレッジ率（クラスごと・全体）

3. 失敗テストがある場合:
   a. 失敗原因がテストコードにある場合 → テストコードを修正
   b. 失敗原因が実装コードにある場合 → 実装コードを修正
   c. 修正後、再度テストを実行
   d. 全テストが成功するまで繰り返す（最大3回）

4. カバレッジが目標に達しない場合:
   a. カバレッジが不足している行を特定
   b. 追加のテストメソッドを作成
   c. 再度テストを実行

5. 最終結果を docs/projects/{PROJECT_ID}/test-results/test_report.md に出力してください。
```

**自律ループのフロー:**

```
テスト作成 → テスト実行 → 結果分析
                              │
                    ┌─────────┤
                    │         │
              全テスト成功   失敗あり
              カバレッジOK     │
                    │    原因分析 → 修正
                    │         │
                    │    テスト再実行（最大3回）
                    │         │
                    ▼         │
              テストレポート出力 ◄──┘
```

### 手順5-3: テスト結果レポートの形式

テストレポート（`docs/projects/{PROJECT_ID}/test-results/test_report.md`）は以下の形式で出力される。

```markdown
# テスト結果レポート

## 実行日時
YYYY-MM-DD HH:MM:SS

## サマリ
- 実行テストクラス数: X
- 実行テストメソッド数: X
- 成功: X
- 失敗: 0
- 全体カバレッジ: XX%

## クラス別カバレッジ

| クラス名 | カバレッジ | 目標達成 |
|---|---|---|
| AccountTriggerHandler | 87% | OK |
| AccountGradingService | 92% | OK |

## テストケース一覧

| テストクラス | テストメソッド | 結果 | 実行時間 |
|---|---|---|---|
| AccountTriggerHandlerTest | testInsertSingle | Pass | 120ms |
| AccountTriggerHandlerTest | testInsertBulk | Pass | 350ms |
| AccountTriggerHandlerTest | testUpdateGrade | Pass | 180ms |
| AccountGradingServiceTest | testCalculateGrade | Pass | 90ms |
| AccountGradingServiceTest | testInvalidInput | Pass | 60ms |

## 修正履歴（自律ループでの修正がある場合）
1. [1回目] AccountTriggerHandlerTest.testInsertBulk が失敗
   - 原因: テストデータのフィールド値が入力規則に抵触
   - 対応: TestDataFactory の生成データを修正
2. [2回目] 全テスト成功
```

### 手順5-4: カバレッジ目標と達成基準

| レベル | カバレッジ目標 | 必須/推奨 |
|---|---|---|
| Salesforce デプロイ最低要件 | 全体75%以上 | 必須 |
| プロジェクト推奨 | 各クラス85%以上 | 推奨 |
| 重要ビジネスロジック | 各クラス90%以上 | 推奨 |

**カバレッジ除外対象:**

- テストクラス自体
- テストデータファクトリ
- 定数定義のみのクラス
- インターフェース定義のみのクラス

### 手順5-4b: 静的解析スクリプトの実行

テスト全件合格・カバレッジ基準達成後、`sf-tester` に静的解析の実行を指示する。

```
@sf-tester テストが全件合格しました。次に、以下の静的解析スクリプトを実行し、
結果を docs/projects/{PROJECT_ID}/test-results/ に出力してください。

1. .github/skills/salesforce-governor-limits/scripts/scan-governor-violations.sh force-app/
   → 出力先: docs/projects/{PROJECT_ID}/test-results/static-analysis-governor.txt

2. .github/skills/salesforce-fls-security/scripts/scan-fls-compliance.sh force-app/
   → 出力先: docs/projects/{PROJECT_ID}/test-results/static-analysis-fls.txt

結果をテスト結果レポートの「静的解析結果」セクションにサマリとして追記してください。
```

### 手順5-5: ヒューマンゲート（テスト結果の承認フロー）

> ヒューマンゲートが無効の場合（`humanGates.gate_test: false`）、この手順は自動スキップされる。

リードエージェントは以下を実行する:

1. `docs/projects/{PROJECT_ID}/project-config.json` の `humanGates.gate_test` を確認する

```bash
jq -r '.humanGates.gate_test' docs/projects/${PROJECT_ID}/project-config.json
```

2. 値が `true` の場合、以下の形式で出力し、ターンを終了する:

```
## テスト完了 — 承認待ち

### 成果物
- `docs/projects/{PROJECT_ID}/test-results/test_report.md`
- `docs/projects/{PROJECT_ID}/test-results/static-analysis-governor.txt`
- `docs/projects/{PROJECT_ID}/test-results/static-analysis-fls.txt`

### 確認ポイント
- 全テストが成功しているか
- カバレッジ目標を達成しているか
- テストケースの網羅性は十分か（正常系・異常系・バルク）
- テストデータが現実的な値を使用しているか
- 静的解析の違反候補に重大な問題がないか

### 次のアクション
以下のいずれかで応答してください:
- **承認** → Phase 5（コードレビュー）に進行します
- **差し戻し** + 修正指示 → テストを再実行します
- **中断** → 処理を停止します

⏳ 承認待ちのため、応答があるまで次フェーズには進みません。
```

3. 人間の応答を受け取り、承認の場合は Phase 5 に進む
4. 差し戻しの場合は、修正指示を `sf-tester` に渡して再実行する
5. 承認が得られたら、テストコードとレポートをコミットする

```bash
git add force-app/main/default/classes/*Test.cls
git add force-app/main/default/classes/*Test.cls-meta.xml
git add docs/projects/{PROJECT_ID}/test-results/
git commit -m "test(apex): SFDC-XXX テストクラスを作成・全テスト成功

- AccountTriggerHandlerTest: カバレッジ 87%
- AccountGradingServiceTest: カバレッジ 92%
- 全体カバレッジ: 89%

Refs: SFDC-XXX"
```

### 中間成果物

| ファイル | 説明 |
|---|---|
| `force-app/main/default/classes/*Test.cls` | テストクラス |
| `force-app/main/default/classes/*Test.cls-meta.xml` | テストクラスのメタデータ |
| `docs/projects/{PROJECT_ID}/test-results/test_report.md` | テスト結果レポート |
| `docs/projects/{PROJECT_ID}/test-results/static-analysis-governor.txt` | ガバナ制限違反候補スキャン結果 |
| `docs/projects/{PROJECT_ID}/test-results/static-analysis-fls.txt` | FLS準拠チェック結果 |

### 完了条件

- [ ] 全テストクラスが作成されている
- [ ] 全テストが成功している（失敗テスト 0 件）
- [ ] 各クラスのカバレッジが85%以上を達成している
- [ ] 全体カバレッジが75%以上を達成している
- [ ] テストレポートが `docs/projects/{PROJECT_ID}/test-results/test_report.md` に出力されている
- [ ] 静的解析スクリプトが実行され、結果が `static-analysis-governor.txt` と `static-analysis-fls.txt` に出力されている
- [ ] ヒューマンゲートが有効な場合、承認が得られている
- [ ] テストコードとレポートが Git にコミット済み

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| テスト実行がタイムアウトする | `--wait` パラメータを延長（例: 30）。大量のテストは分割実行する |
| 自律ループが3回で収束しない | 手動でエラーログを確認し、根本原因を特定。設計の問題であればフェーズ3に戻る |
| カバレッジが目標に達しない | カバレッジレポートの「未カバー行」を確認し、追加テストケースの作成を `sf-tester` に指示 |
| テスト実行環境でデータ不整合 | テスト用の Scratch Org を使用するか、`@TestSetup` でデータを完全に自己完結させる |
| テストが他のテストに依存している | `@TestSetup` と `SeeAllData=false` を徹底し、テスト間の独立性を確保 |
| `sf apex run test` コマンドがエラーを返す | 組織への認証を再確認。デプロイが未完了の場合は先にデプロイする: `sf project deploy start --source-dir force-app --target-org <alias>` |

---

## Phase 5: コードレビュー

### エントリー条件

- [ ] Phase 4が完了し、全テストが成功していること
- [ ] テストレポートが承認済みであること
- [ ] 全実装コードとテストコードが Git にコミット済みであること

### 手順6-1: sf-code-reviewer の呼び出し

```
@sf-code-reviewer 以下のインプットに基づき、コードレビューを実施してください。

## インプット
1. 設計書: docs/projects/{PROJECT_ID}/design/（全ファイル）
2. 実装コード: force-app/main/default/（今回変更された全ファイル）
3. テストコード: force-app/main/default/classes/*Test.cls
4. テストレポート: docs/projects/{PROJECT_ID}/test-results/test_report.md
5. メタデータカタログ: metadata-catalog/catalog/
6. 横断的方針: docs/architecture/policies/
7. ADR（設計判断記録）: docs/architecture/decisions/

## レビュー対象ファイルの特定
以下のコマンドで変更ファイル一覧を確認してください:
git diff --name-only main...HEAD

## レビュー観点
以下の観点で全ファイルをレビューし、JSON形式で結果を報告してください:

### 1. ガバナ制限
- ループ内の SOQL/DML がないか
- SOQL クエリ数が上限に近い処理がないか
- ヒープサイズを圧迫するコレクション操作がないか
- CPU タイムリミットのリスクがある処理がないか

### 2. セキュリティ（FLS/CRUD）
- 全DML操作に FLS/CRUD チェックがあるか
- SOQL に WITH SECURITY_ENFORCED または stripInaccessible が適用されているか
- Lightning コンポーネントに CSRF 対策があるか

### 3. バルク化
- トリガハンドラが200レコードで動作する設計か
- コレクション操作（Map/Set/List）が適切に使われているか
- N+1 クエリパターンがないか

### 4. 命名規約
- クラス名: PascalCase
- メソッド名: camelCase
- 定数: UPPER_SNAKE_CASE
- カスタム項目: PascalCase__c
- テストメソッド: test で始まる説明的な名前

### 5. コード品質
- デッドコードがないか
- 重複ロジックがないか
- エラーハンドリングが適切か
- コメントが十分か

### 6. テスト品質
- テストケースの網羅性（正常系・異常系・バルク・境界値）
- アサーションの品質（具体的なメッセージ付き）
- テストデータの妥当性

## 出力形式
docs/projects/{PROJECT_ID}/review/review_report.json に以下の形式で出力してください:

{
  "review_date": "YYYY-MM-DD",
  "reviewer": "sf-code-reviewer",
  "summary": {
    "total_issues": N,
    "p1_critical": N,
    "p2_major": N,
    "p3_minor": N,
    "p4_info": N
  },
  "issues": [
    {
      "id": "REV-001",
      "severity": "P1",
      "category": "ガバナ制限",
      "file": "force-app/.../ClassName.cls",
      "line": 45,
      "description": "ループ内でSOQLクエリが実行されている",
      "recommendation": "ループ外でMapに格納し、ループ内ではMapから取得する",
      "code_snippet": "for (Account acc : accounts) { ... }"
    }
  ],
  "approval": "APPROVED" | "CHANGES_REQUESTED"
}

Severity定義:
- P1 (Critical): デプロイ不可。ガバナ制限違反、セキュリティ脆弱性
- P2 (Major): 修正推奨。パフォーマンス問題、バルク化不足
- P3 (Minor): 改善推奨。命名規約違反、コメント不足
- P4 (Info): 参考情報。リファクタリング提案、ベストプラクティスの紹介

判定基準:
- P1が1件でもある場合: CHANGES_REQUESTED
- P2が3件以上ある場合: CHANGES_REQUESTED
- それ以外: APPROVED

また、人間が読みやすいMarkdown形式のレポートも出力してください:
docs/projects/{PROJECT_ID}/review/review_report.md
```

### 手順6-2: レビュー指摘の修正

レビュー結果が `CHANGES_REQUESTED` の場合、指摘事項を修正する。

```
@sf-implementer docs/projects/{PROJECT_ID}/review/review_report.json のレビュー指摘に基づき、
以下の修正を実施してください。

## 修正対象
[レビューレポートの issues から P1/P2 の指摘を列挙]

## 修正ルール
- P1（Critical）の指摘は全て修正すること
- P2（Major）の指摘は全て修正すること
- P3（Minor）の指摘は可能な範囲で修正すること
- 修正後、該当するテストが引き続き成功することを確認すること
```

修正後、再度レビューを実施する:

```
@sf-code-reviewer 修正が完了しました。再レビューを実施してください。
前回のレビューレポート: docs/projects/{PROJECT_ID}/review/review_report.json
修正コミット: [git log で確認]
```

### 手順6-3: PR本文の自動生成

レビューが `APPROVED` になったら、PR本文を生成する。

```
@sf-code-reviewer 以下の情報に基づき、PR本文を生成してください。

## インプット
1. 要件定義書: docs/projects/{PROJECT_ID}/requirements/requirements_specification.md
2. 設計書: docs/projects/{PROJECT_ID}/design/（全ファイル）
3. テストレポート: docs/projects/{PROJECT_ID}/test-results/test_report.md
4. レビューレポート: docs/projects/{PROJECT_ID}/review/review_report.json
5. 変更ファイル一覧: git diff --name-only main...HEAD
6. コミット履歴: git log --oneline main...HEAD

## 出力先
docs/projects/{PROJECT_ID}/review/pr_description.md

## PR本文テンプレート

# [案件ID] [案件名]

## 変更概要
[要件定義書のサマリから1〜3行で記述]

## 変更内容

### データモデル変更
- [新規/変更されたオブジェクト・項目の一覧]

### Apex
- [新規/変更されたクラス・トリガの一覧と概要]

### LWC
- [新規/変更されたコンポーネントの一覧と概要]（該当する場合）

### フロー
- [新規/変更されたフローの一覧と概要]（該当する場合）

## テスト結果
- 実行テスト数: X
- 成功: X / 失敗: 0
- 全体カバレッジ: XX%

| クラス名 | カバレッジ |
|---|---|
| [クラス名] | XX% |

## レビュー結果
- レビュー実施日: YYYY-MM-DD
- P1 (Critical): 0件
- P2 (Major): 0件
- P3 (Minor): X件（許容範囲）
- 判定: APPROVED

## 影響範囲
- 影響を受けるオブジェクト: [一覧]
- 影響を受ける既存機能: [一覧]
- 影響を受けるプロファイル/権限: [一覧]

## デプロイ手順
1. [デプロイ前に必要な手順があれば記載]
2. `sf project deploy start --source-dir force-app --target-org <target>`
3. [デプロイ後に必要な手順があれば記載]

## ロールバック手順
1. `sf project deploy start --source-dir force-app --target-org <target> --dry-run` で確認
2. 問題発生時は前回デプロイのメタデータで再デプロイ

## チェックリスト
- [ ] 全テスト成功
- [ ] カバレッジ75%以上達成
- [ ] コードレビュー APPROVED
- [ ] ガバナ制限確認済み
- [ ] FLS/CRUD チェック確認済み
- [ ] バルク化対応確認済み
```

### 手順6-4: PR の作成

```bash
# PR を作成（GitHub CLI を使用）
gh pr create \
  --title "[SFDC-XXX] <案件名の簡潔な説明>" \
  --body-file docs/projects/{PROJECT_ID}/review/pr_description.md \
  --base main \
  --head feature/SFDC-XXX-<説明>
```

### 手順6-5: ヒューマンゲート（PR 承認フロー）

> ヒューマンゲートが無効の場合（`humanGates.gate_pr: false`）、この手順は自動スキップされる。

リードエージェントは以下を実行する:

1. `docs/projects/{PROJECT_ID}/project-config.json` の `humanGates.gate_pr` を確認する

```bash
jq -r '.humanGates.gate_pr' docs/projects/${PROJECT_ID}/project-config.json
```

2. 値が `true` の場合、以下の形式で出力し、ターンを終了する:

```
## PR作成準備完了 — 承認待ち

### 成果物
- `docs/projects/{PROJECT_ID}/review/review_report.json` — レビュー結果
- `docs/projects/{PROJECT_ID}/review/pr_description.md` — PR本文

### 確認ポイント
- コードレビューが APPROVED であること
- P1/P2指摘が全て解消済みであること
- PR本文に変更概要・テスト結果・影響範囲が記載されていること
- デプロイ手順・ロールバック手順が明記されていること

### 次のアクション
以下のいずれかで応答してください:
- **承認** → PR を作成・提出します
- **差し戻し** + 修正指示 → 指摘箇所を修正します
- **中断** → 処理を停止します

⏳ 承認待ちのため、応答があるまでPRは作成しません。
```

3. 人間の応答を受け取り、承認の場合は PR を作成する
4. 差し戻しの場合は、修正指示に基づいて対応する
5. PR 作成後、GitHub 上でレビューを実施する
6. レビューコメントに対する修正が必要な場合:

```
@sf-implementer PR レビューで以下のコメントを受けました。修正してください:

## レビューコメント
1. [ファイル名:行番号] [コメント内容]
2. [ファイル名:行番号] [コメント内容]

修正後、テストが引き続き成功することを確認してください。
```

7. 修正をコミット・プッシュする

```bash
git add [修正ファイル]
git commit -m "fix(apex): PR レビュー指摘事項を修正

- [修正内容1]
- [修正内容2]

Refs: SFDC-XXX"
git push
```

8. PR が承認されたら、マージする

### 中間成果物

| ファイル | 説明 |
|---|---|
| `docs/projects/{PROJECT_ID}/review/review_report.json` | レビュー結果（JSON） |
| `docs/projects/{PROJECT_ID}/review/review_report.md` | レビュー結果（Markdown） |
| `docs/projects/{PROJECT_ID}/review/pr_description.md` | PR 本文 |

### 完了条件

- [ ] コードレビューが `APPROVED` であること
- [ ] P1（Critical）の指摘が 0 件であること
- [ ] PR が作成されていること
- [ ] PR 本文に変更概要・テスト結果・影響範囲が記載されていること
- [ ] ヒューマンゲートが有効な場合、PR が承認されていること

### エラーハンドリング

| エラー状況 | 対応手順 |
|---|---|
| レビューで設計レベルの問題が見つかる | フェーズ3（設計）に戻り、設計書を修正。影響範囲を再評価した上で実装を再実施 |
| レビューと修正のループが3回以上になる | 手動でコードを確認し、根本的な設計問題がないか検討。必要に応じてペアプログラミングで解決 |
| PR の CI/CD チェックが失敗する | CI ログを確認し、`sf-tester` にエラーの分析と修正を指示 |
| マージコンフリクトが発生する | `git rebase main` でコンフリクトを解消。大規模なコンフリクトの場合は手動で対応 |
| `gh pr create` が失敗する | GitHub CLI の認証を確認（`gh auth status`）。リモートブランチがプッシュ済みか確認 |

---

## 付録: フェーズ横断リファレンス

### A. コンテキスト管理のタイミング

| タイミング | アクション |
|---|---|
| フェーズ開始時 | `/clear` でコンテキストをリセット（前フェーズの残留情報を除去） |
| コンテキスト使用率50%到達時 | `/compact` でコンテキストを圧縮 |
| サブエージェント呼び出し前 | 必要なファイルパスのみをプロンプトに含める（ファイル内容はサブエージェントに読ませる） |
| エラー発生時の再試行前 | `/compact` でコンテキストを圧縮してから再実行 |
| タスク切り替え時 | `/clear` で完全リセット |

### B. 全フェーズのサブエージェント呼び出しサマリ

| フェーズ | サブエージェント | 主要インプット | 主要アウトプット |
|---|---|---|---|
| Phase 0 | `sf-metadata-analyst` | raw-metadata/ | metadata-catalog/schema/, metadata-catalog/catalog/ |
| Phase 1 | `sf-requirements-analyst` | docs/projects/{PID}/requirements/user_requirements.md, catalog/, docs/architecture/system-context.md, docs/architecture/policies/ | docs/projects/{PID}/requirements/ |
| Phase 2 | `sf-designer`, `sf-metadata-analyst` | docs/projects/{PID}/requirements/requirements_specification.md, catalog/, docs/architecture/decisions/, docs/architecture/policies/ | docs/projects/{PID}/design/ |
| Phase 3 | `sf-implementer` | docs/projects/{PID}/design/ | force-app/ 配下のコード |
| Phase 4 | `sf-tester` | 実装コード, docs/projects/{PID}/design/ | テストコード, docs/projects/{PID}/test-results/ |
| Phase 5 | `sf-code-reviewer` | 全実装コード, テストレポート, docs/architecture/policies/, docs/architecture/decisions/ | docs/projects/{PID}/review/ |
| Phase 6 | リードエージェント | レビュー合格済み | GitHub Pull Request |

### C. ヒューマンゲート設定一覧

案件設定ファイル（`docs/projects/{PROJECT_ID}/project-config.json`）の `humanGates` セクションで以下のフラグを制御する:

```json
// docs/projects/{PROJECT_ID}/project-config.json 内
"humanGates": {
  "gate_requirements": true,
  "gate_design": true,
  "gate_test": true,
  "gate_pr": true
}
```

リードエージェントは各フェーズ完了時に以下のコマンドでゲート設定を確認する:

```bash
jq -r '.humanGates.gate_requirements' docs/projects/${PROJECT_ID}/project-config.json
```

| フラグ | デフォルト | 説明 |
|---|---|---|
| `gate_requirements` | `true` | Phase 1完了時に要件定義書の承認を要求 |
| `gate_design` | `true` | Phase 2完了時に設計書の承認を要求 |
| `gate_test` | `true` | Phase 4完了時にテスト結果の承認を要求 |
| `gate_pr` | `true` | Phase 5完了後、PR作成前の承認を要求 |

**全ゲートを無効にする場合**（自動実行モード）:

```json
"humanGates": {
  "gate_requirements": false,
  "gate_design": false,
  "gate_test": false,
  "gate_pr": false
}
```

### D. 案件ごとのブランチ運用

```
main
 ├── feature/SFDC-001-account-grading    ← 案件1
 ├── feature/SFDC-002-lead-scoring       ← 案件2
 └── feature/SFDC-003-report-dashboard   ← 案件3
```

各案件は独立したブランチで作業し、PR を通じて main にマージする。案件間で依存がある場合は、先行案件を先にマージするか、共通ブランチから分岐する。

### E. トラブル発生時のフェーズ戻り判断基準

| 検出フェーズ | 問題の種類 | 戻り先 |
|---|---|---|
| Phase 3（実装） | 設計に曖昧さがある | Phase 2（設計）で設計書を補完 |
| Phase 4（テスト） | 実装のバグ | Phase 3（実装）で修正 |
| Phase 4（テスト） | 要件の漏れが判明 | Phase 1（要件定義）で要件書を更新 |
| Phase 5（レビュー） | ガバナ制限違反 | Phase 3（実装）で修正 |
| Phase 5（レビュー） | 設計方針レベルの問題 | Phase 2（設計）で再設計 |
| Phase 5（レビュー） | 要件の誤解 | Phase 1（要件定義）で確認・修正 |
