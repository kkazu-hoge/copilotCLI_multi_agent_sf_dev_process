# 命名規約方針（Naming Convention Policy）

> 最終更新: 2026-03-09
> 管理者: {チーム名}
> ステータス: 承認済み

---

## 1. 目的

Salesforce 組織内のすべてのメタデータ・コード資産に対する統一的な命名規約を定義し、可読性・検索性・保守性を確保する。本ドキュメントは全案件に適用される。

> **注記**: 本ドキュメントは設計レベルの命名方針を定義する。Apex コードの変数名・メソッド名等の詳細な規約は `.github/instructions/apex-coding.md` に記載する。

---

## 2. 共通原則

| 原則 | 内容 |
|------|------|
| 英語で命名 | すべてのメタデータ名・コード名は英語を使用する。日本語ラベルは `label` に設定する |
| 意味のある名前 | 略語を避け、名前から用途・役割が推測できること |
| 一貫性 | 同じ概念には同じ単語を使用する（例: "Account" と "Acct" を混在させない） |
| 許可する略語 | 業界標準の略語のみ許可（下表参照）。プロジェクト固有の略語は `metadata-catalog/catalog/glossary.json` に登録すること |

### 2.1 許可する略語一覧

| 略語 | 正式名称 | 用途 |
|------|---------|------|
| Id | Identifier | ID 項目 |
| Num | Number | 番号・件数 |
| Qty | Quantity | 数量 |
| Amt | Amount | 金額 |
| Dt | Date | 日付 |
| Desc | Description | 説明 |
| Mgr | Manager | マネージャー |
| Config | Configuration | 設定 |
| Info | Information | 情報 |
| Max / Min | Maximum / Minimum | 最大値/最小値 |

上記以外の略語を使用する場合は、`glossary.json` に追加してチームの合意を得ること。

---

## 3. Salesforce メタデータの命名規約

### 3.1 オブジェクト

| 種別 | 規約 | 例 |
|------|------|-----|
| カスタムオブジェクト | PascalCase + `__c` | `Account_Score__c`, `Integration_Log__c` |
| ラベル | 日本語で業務用語を使用 | 「取引先スコア」、「連携ログ」 |
| 説明 | 用途・管理者を記載 | 「取引先の活動スコアを管理するオブジェクト。PROJ-001 で作成。」 |

### 3.2 項目

| 種別 | 規約 | 例 |
|------|------|-----|
| カスタム項目 | PascalCase + `__c` | `Score_Grade__c`, `Calculated_At__c` |
| 外部 ID 項目 | `{連携先}_{キー名}_External_Id__c` | `ERP_Account_External_Id__c` |
| 数式項目 | `{対象}_Formula__c` | `Days_Since_Last_Activity_Formula__c` |
| 積み上げ集計 | `{集計対象}_Rollup__c` | `Total_Score_Rollup__c` |

### 3.3 その他のメタデータ

| メタデータ種別 | 規約 | 例 |
|-------------|------|-----|
| フロー | `{オブジェクト}_{トリガ/操作}_{概要}` | `Account_AfterUpdate_ScoreNotification` |
| バリデーションルール | `{オブジェクト}_{検証内容}` | `Opportunity_CloseDate_FutureOnly` |
| 権限セット | `PS_{機能/ロール}` | `PS_ScoreViewer`, `PS_SalesManager` |
| ページレイアウト | `{オブジェクト}-{プロファイル/用途} Layout` | `Account-Sales Layout`, `Account-Manager Layout` |
| レコードタイプ | PascalCase | `Enterprise`, `SmallBusiness` |
| カスタムメタデータ型 | `{用途}_Config__mdt` | `Integration_Config__mdt`, `Score_Threshold__mdt` |
| カスタム設定 | `{用途}_Setting__c` | `App_Setting__c` |
| Platform Event | `{イベント内容}__e` | `Score_Updated__e`, `Integration_Error__e` |

---

## 4. Apex コードの命名規約

### 4.1 クラス命名

| 種別 | 規約 | 例 |
|------|------|-----|
| トリガ | `{オブジェクト}Trigger` | `AccountTrigger` |
| トリガハンドラ | `{オブジェクト}TriggerHandler` | `AccountTriggerHandler` |
| サービスクラス | `{ドメイン}Service` | `AccountScoringService` |
| セレクタクラス | `{オブジェクト}Selector` | `AccountSelector` |
| ドメインクラス | `{オブジェクト}Domain` / `{オブジェクト複数形}` | `Accounts`, `Opportunities` |
| コントローラ | `{機能}Controller` | `ScoreDashboardController` |
| バッチクラス | `{処理内容}Batch` | `AccountScoreRecalculationBatch` |
| スケジューラ | `{処理内容}Scheduler` | `AccountScoreRecalculationScheduler` |
| Queueable | `{処理内容}Queueable` | `ScoreNotificationQueueable` |
| テストクラス | `{対象クラス}Test` | `AccountScoringServiceTest` |
| テストデータファクトリ | `TestDataFactory` | `TestDataFactory`（プロジェクトで1つ） |
| カスタム例外 | `{種別}Exception` | `BusinessException`, `IntegrationException` |
| ユーティリティ | `{機能}Util` / `{機能}Helper` | `DateUtil`, `JsonHelper` |

### 4.2 メソッド・変数命名

| 種別 | 規約 | 例 |
|------|------|-----|
| メソッド名 | camelCase / 動詞始まり | `calculateScore()`, `getAccountsByIds()` |
| 変数名 | camelCase | `accountScore`, `targetRecords` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_SCORE` |
| パラメータ | camelCase | `accountIds`, `scoreThreshold` |
| Map 変数 | `{キーの意味}To{値の意味}` / `{値}By{キー}` | `accountById`, `scoreByAccountId` |
| List 変数 | 複数形 | `accounts`, `updatedScores` |
| Boolean 変数 | `is` / `has` / `should` 始まり | `isActive`, `hasPermission`, `shouldRecalculate` |

---

## 5. LWC コンポーネントの命名規約

### 5.1 コンポーネント命名

| 種別 | 規約 | 例 |
|------|------|-----|
| コンポーネントフォルダ | camelCase | `accountScoreCard`, `scoreDashboard` |
| HTML テンプレート | コンポーネントと同名 | `accountScoreCard.html` |
| JavaScript | コンポーネントと同名 | `accountScoreCard.js` |
| CSS | コンポーネントと同名 | `accountScoreCard.css` |
| テスト | `__tests__/{コンポーネント名}.test.js` | `__tests__/accountScoreCard.test.js` |

### 5.2 LWC 内部の命名

| 種別 | 規約 | 例 |
|------|------|-----|
| プロパティ（`@api`） | camelCase | `recordId`, `scoreGrade` |
| リアクティブプロパティ | camelCase | `isLoading`, `errorMessage` |
| イベント名 | kebab-case（`CustomEvent`） | `score-updated`, `filter-changed` |
| Apex メソッド import | camelCase | `getAccountScore`, `updateScore` |
| CSS クラス | SLDS 準拠 / BEM | `slds-card`, `score-card__header` |

---

## 6. Git・ブランチ・コミットの命名規約

### 6.1 ブランチ命名

```
{type}/{PROJECT_ID}-{short-description}
```

| type | 用途 | 例 |
|------|------|-----|
| `feature/` | 新機能 | `feature/PROJ-001-account-scoring` |
| `bugfix/` | バグ修正 | `bugfix/PROJ-003-flow-error` |
| `hotfix/` | 緊急修正 | `hotfix/PROJ-004-urgent-fix` |
| `refactor/` | リファクタリング | `refactor/PROJ-005-service-layer` |

### 6.2 コミットメッセージ

```
{type}({scope}): {description}

例:
feat(Account): add score calculation trigger
fix(Flow): correct stage transition condition
test(AccountScoring): add bulk test for 200 records
docs(ADR): add ADR-001 score data placement
```

| type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `test` | テスト追加・修正 |
| `refactor` | リファクタリング |
| `docs` | ドキュメント |
| `chore` | ビルド・設定変更 |

---

## 7. 本ドキュメントの参照方法

### サブエージェントへのガイダンス

- **sf-designer**: 設計書にオブジェクト名・項目名・クラス名を記載する際に本規約に準拠すること
- **sf-implementer**: Apex クラス・メソッド・変数、LWC コンポーネントの命名を本規約に従うこと
- **sf-tester**: テストクラス・テストメソッドの命名を本規約に従うこと
- **sf-code-reviewer**: 命名規約違反をレビュー指摘項目に含めること（Severity: P3）

### 詳細リファレンス

- Apex 変数・メソッドの詳細規約: `.github/instructions/apex-coding.md`
- LWC の詳細規約: `.github/instructions/lwc-coding.md`
- 業務用語辞書: `metadata-catalog/catalog/glossary.json`
