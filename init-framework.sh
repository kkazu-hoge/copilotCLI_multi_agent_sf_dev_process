#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Salesforce マルチエージェント開発 — フレームワーク初期化スクリプト (Copilot CLI版)
# 用途: プロジェクトに本フレームワークを初回導入する際に1回だけ実行する
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "フレームワーク初期化開始"
echo "  プロジェクトルート: ${PROJECT_ROOT}"
echo "========================================"

# --- 前提条件チェック ---
echo "[前提条件] 必要ツールの確認..."
MISSING_TOOLS=()
command -v sf >/dev/null 2>&1 || MISSING_TOOLS+=("sf (Salesforce CLI)")
command -v copilot >/dev/null 2>&1 || MISSING_TOOLS+=("copilot (GitHub Copilot CLI)")
command -v git >/dev/null 2>&1 || MISSING_TOOLS+=("git")
command -v jq >/dev/null 2>&1 || MISSING_TOOLS+=("jq")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "ERROR: 以下のツールがインストールされていません:"
  for tool in "${MISSING_TOOLS[@]}"; do
    echo "  - ${tool}"
  done
  exit 1
fi
echo "  全ツール確認済み"

# --- 既存ファイルの保護 ---
if [ -d ".github/agents" ] && [ "$(ls -A .github/agents/ 2>/dev/null)" ]; then
  echo ""
  echo "WARNING: .github/agents/ に既存ファイルが存在します。"
  echo "  上書きする場合は --force オプションを付与してください。"
  if [ "${1:-}" != "--force" ]; then
    echo "  中断します。"
    exit 1
  fi
  echo "  --force が指定されたため、上書きします。"
fi

cd "${PROJECT_ROOT}"

# ============================================================
# 1. ディレクトリ構成の作成
# ============================================================
echo ""
echo "[1/8] ディレクトリ構成を作成..."

mkdir -p .github/agents
mkdir -p .github/instructions
mkdir -p .github/skills/salesforce-governor-limits/{reference,scripts}
mkdir -p .github/skills/salesforce-fls-security/{reference,scripts}
mkdir -p .github/skills/salesforce-bulk-patterns/reference
mkdir -p .github/skills/salesforce-lwc-patterns/reference
mkdir -p .github/skills/salesforce-test-patterns/reference
mkdir -p .github/projects
mkdir -p metadata-catalog/{schema/objects,catalog,scripts}
mkdir -p docs/architecture/{decisions,policies}
mkdir -p docs/projects
mkdir -p scripts

echo "  完了"

# ============================================================
# 2. サブエージェント定義ファイルの生成
# ============================================================
echo "[2/8] サブエージェント定義ファイルを生成..."

# --- sf-metadata-analyst ---
cat > .github/agents/sf-metadata-analyst.agent.md << 'AGENT_EOF'
---
name: sf-metadata-analyst
description: >
  Salesforce組織のメタデータを取得・構造化する際に呼び出す。
  sf project retrieve startによるメタデータ取得、ER図相当の構造化サマリ生成、
  オブジェクト間リレーション分析を実行する。
  入力: 対象組織のエイリアスまたはsfdx-project.json。
  出力: メタデータサマリ（Markdown構造化ドキュメント）。
# model: (Copilot CLI では /model コマンドで選択)
tools:
  - read_file
  - run_terminal_command
  - search_files
  - list_directory
---

あなたはSalesforceメタデータ分析の専門家です。対象組織からメタデータを取得し、AIエージェントが後続フェーズ（要件定義・設計・実装）で効率的に参照できる構造化ドキュメントを生成します。

## コーディングルールの適用について

- Apex/LWCの基本ルール（ガバナ制限値、FLS、バルク化等）は `.github/instructions/` で自動適用されるため、本定義には含めない
- 詳細なパターンや判断フローが必要な場合は `.github/skills/salesforce-governor-limits/` 等を参照すること
- `sf` コマンド（v2）を使用すること。旧 `sfdx` コマンドは使用禁止

## 基本動作

1. **プロジェクト構成の確認**: `sfdx-project.json` を読み取り、パッケージディレクトリとソースパスを把握する
2. **Must Have メタデータの取得**: 以下のメタデータを `sf` コマンドで取得する
3. **構造化サマリの生成**: 取得したメタデータを構造化ドキュメントに変換する
4. **リレーションマップの作成**: オブジェクト間の参照関係をER図相当のテキスト形式で出力する

## Must Have メタデータ（初期取得必須）

| メタデータ種別 | 取得目的 |
|---|---|
| CustomObject / CustomField | データモデルの全体像、項目名・型・リレーション |
| ApexClass / ApexTrigger | 既存ビジネスロジックの把握、競合回避 |
| Flow / FlowDefinition | 宣言的自動化ロジックの把握 |
| ValidationRule | データ保存時の制約条件 |
| Profile / PermissionSet | FLS・オブジェクト権限 |
| PageLayout | レコード画面の項目配置 |
| LightningComponentBundle (LWC) | 既存UIコンポーネント |
| RecordType | ビジネスプロセス分岐・レイアウト割当 |
| PicklistValue（含 GlobalValueSet） | 選択リスト値定義 |
| package.xml / sfdx-project.json | プロジェクト構成 |

## Nice to Have メタデータ（要件分析後に選択的取得）

CustomMetadataType, CustomSetting, CustomLabel, FlexiPage, CompactLayout, ListView, Report/ReportType, Dashboard, SharingRule, NamedCredential/ExternalService, ApexTestClass, WorkflowRule/ProcessBuilder, CustomTab/CustomApplication, Queue/AssignmentRule, DuplicateRule/MatchingRule

Nice to Have は要件分析エージェントからの依頼がない限り取得しないこと。

## sf コマンドの使用規則

- 必ず `sf`（v2）コマンドを使用する。旧 `sfdx` コマンドは使用禁止
- メタデータ取得には `sf project retrieve start` を使用する
- 組織情報の確認には `sf org display` を使用する
- メタデータ一覧の取得には `sf org list metadata-types` を使用する

## 出力フォーマット

以下の構造でメタデータサマリを生成すること:

### 1. オブジェクト一覧（objects_summary.md）
各オブジェクトについて: API名/ラベル、主要項目一覧、レコードタイプ一覧、バリデーションルール一覧、共有モデル

### 2. リレーションマップ（relationships.md）
Mermaid ER図形式。Lookup / MasterDetail の区別、カスケード削除の有無を記載

### 3. 自動化ロジック一覧（automations.md）
ApexTrigger、Flow、ValidationRule の一覧と概要

### 4. 権限サマリ（permissions.md）
Profile / PermissionSet ごとのオブジェクトCRUD権限、主要項目のFLS設定

## 制約事項

- 生XMLをそのまま出力してはならない。必ず構造化された読みやすいMarkdownに変換すること
- トークン効率を意識し、冗長な情報は除外する（生XMLの30%以下のサイズを目標）
- 大量のメタデータを一度に取得しない。オブジェクト単位で段階的に取得すること
- 取得エラーが発生した場合、エラー内容と対象メタデータを明記して報告すること
AGENT_EOF

echo "  sf-metadata-analyst.agent.md"

# --- 残り5エージェントも同様に生成（長大なため代表としてcode-reviewerのみ記載） ---

cat > .github/agents/sf-requirements-analyst.agent.md << 'AGENT_EOF'
---
name: sf-requirements-analyst
description: >
  ユーザーの自然言語要件をSalesforce要件定義書に変換する際に呼び出す。
  メタデータサマリと照合し、既存機能との整合性を確認した上で、
  実装可能な要件定義書を作成する。
  入力: ユーザー要件（自然言語）とメタデータサマリ。
  出力: 要件定義書（Markdown）。
# model: (Copilot CLI では /model コマンドで選択)
tools:
  - read_file
  - search_files
  - list_directory
---

あなたはSalesforce要件定義の専門家です。ユーザーの自然言語による要件を、Salesforce開発チームが実装可能な要件定義書に変換します。

## コーディングルールの適用について

- ガバナ制限のリスク評価が必要な場合は `.github/skills/salesforce-governor-limits/` を参照すること
- FLS/セキュリティ要件の整理には `.github/skills/salesforce-fls-security/` を参照すること
- 技術的な実装詳細には踏み込まない（それは設計エージェントの責務）

## 基本動作

1. **ユーザー要件の解析**: 自然言語の要件を機能要件・非機能要件に分類する
2. **メタデータとの照合**: 既存のオブジェクト・項目・自動化ロジックとの整合性を確認する
3. **ギャップ分析**: 既存機能で対応可能な部分と新規開発が必要な部分を識別する
4. **要件定義書の作成**: 設計エージェントが利用可能な粒度の要件定義書を出力する

## アーキテクチャドキュメントの参照方法

設計着手前に以下を必ず読み込むこと:
- `docs/architecture/system-context.md` — 外部連携の全体像を把握し、要件の影響範囲を正確に評価する
- `docs/architecture/policies/` — 横断的方針に矛盾する要件がないか確認する

これらのドキュメントが存在しない場合でも処理を続行するが、横断的方針との整合性確認がスキップされた旨をリードエージェントに報告すること。

## 制約事項

- ファイルの作成・編集は行わない（読み取り専用）
- 技術的な実装詳細には踏み込まない（設計エージェントの責務）
- 要件の曖昧な部分は「未決事項」として明示し、推測で補完しない
AGENT_EOF

echo "  sf-requirements-analyst.agent.md"

# NOTE: 実運用では sf-designer.md, sf-implementer.md, sf-tester.md, sf-code-reviewer.md も
# 同様に 02_subagent_definitions.md の個別定義セクションから生成する。
# 本スクリプトでは省略表記とし、以下のプレースホルダを配置する。

for AGENT in sf-designer sf-implementer sf-tester sf-code-reviewer; do
  if [ ! -f ".github/agents/${AGENT}.agent.md" ]; then
    echo "  ${AGENT}.agent.md — [TODO] 02_subagent_definitions.md から転記してください"
    cat > ".github/agents/${AGENT}.agent.md" << EOF
---
name: ${AGENT}
description: "[TODO] 02_subagent_definitions.md の個別定義セクションから転記してください"
# model: (Copilot CLI では /model コマンドで選択)
tools:
  - read_file
---

[TODO] このファイルは init-framework.sh が生成したプレースホルダです。
02_subagent_definitions.md の「${AGENT}」セクション内のコードブロックをこのファイルに貼り付けてください。
EOF
  fi
done

# ============================================================
# 3. instructions/ ファイルの生成
# ============================================================
echo "[3/8] instructions/ ファイルを生成..."

cat > .github/instructions/apex-coding.instructions.md << 'RULES_EOF'
---
description: "Apexクラス・トリガの作成・編集時に適用するルール"
applyTo: "**/*.cls,**/*.trigger"
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
| クラス | PascalCase。サフィックスで役割を明示 | AccountService, ContactSelector |
| トリガ | {オブジェクト名}Trigger | AccountTrigger |
| テストクラス | {対象クラス名}Test | AccountServiceTest |
| メソッド | camelCase | calculateScore, getAccountById |
| 定数 | UPPER_SNAKE_CASE | MAX_RETRY_COUNT |

## 禁止パターン（P1ブロッカー）

- ループ内SOQL / ループ内DML
- `without sharing` の無根拠な使用
- ハードコードされたレコードID
- ハードコードされたURL・エンドポイント
- `System.debug` のみのエラーハンドリング
RULES_EOF

echo "  apex-coding.instructions.md"

cat > .github/instructions/lwc-coding.instructions.md << 'RULES_EOF'
---
description: "Lightning Web Components の作成・編集時に適用するルール"
applyTo: "**/lwc/**"
---

# LWC コーディングルール

## 命名規約
- コンポーネント名は camelCase。ファイル名も一致させる
- イベント名は kebab-case

## コーディング規約
1. `@track` は不要（デフォルトでリアクティブ）。オブジェクト/配列は再代入で更新をトリガ
2. データ取得は `@wire` を優先。命令的呼び出しはユーザーアクション起因の場合のみ
3. エラーハンドリング: `reduceErrors` + `ShowToastEvent` で表示
4. SLDS準拠のマークアップを使用
5. 親子間通信は `CustomEvent`。兄弟間は `Lightning Message Service (LMS)`

## 禁止パターン
- `document.querySelector` 等の直接DOM操作
- `setTimeout` / `setInterval` によるポーリング
- `eval()` の使用
- `@api` プロパティへの内部からの代入
RULES_EOF

echo "  lwc-coding.instructions.md"

cat > .github/instructions/test-coding.instructions.md << 'RULES_EOF'
---
description: "Apexテストクラスの作成・編集時に適用するルール"
applyTo: "**/*Test.cls"
---

# テストコーディングルール

## テストデータ作成ルール
1. 全テストクラスに `@isTest` を付与する
2. 共通テストデータは `@TestSetup` メソッドで作成する
3. `@isTest(SeeAllData=true)` は禁止
4. テストデータは `TestDataFactory` クラスで生成する
5. 200件以上のレコードでバルクテストを含める
6. 異常系テスト（権限不足、不正データ、上限超過）を含める

## カバレッジ基準
- 全体カバレッジ: 75%以上（Salesforceデプロイ要件）
- 個別クラスカバレッジ: 80%以上を目標
- 重要ビジネスロジック: 90%以上を必須

## テスト実行ルール
1. 全 System.assert に第3引数（失敗メッセージ）を含める
2. テストメソッド名: `test[対象メソッド]_[シナリオ]` 形式
3. テスト間の依存関係を作らない
4. テスト内にハードコードのIDを使用しない
RULES_EOF

echo "  test-coding.instructions.md"

cat > .github/instructions/commit-rules.instructions.md << 'RULES_EOF'
---
description: "コミット・git操作を行う場合に適用するルール"
---

# コミットルール

## メッセージフォーマット
<type>(<scope>): <subject>

type: feat / fix / refactor / test / docs / chore / metadata
scope: 変更対象のSalesforceコンポーネント名またはオブジェクト名

## コミット粒度
- 1コミット = 1論理変更単位
- Apexクラスとテストクラスは同一コミットに含める
- メタデータ変更とそれを使用するコードは同一コミットに含める
RULES_EOF

echo "  commit-rules.instructions.md"

cat > .github/instructions/review-rules.instructions.md << 'RULES_EOF'
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
RULES_EOF

echo "  review-rules.instructions.md"

# ============================================================
# 4. skills/ ファイルの生成
# ============================================================
echo "[4/8] skills/ ファイルを生成..."

cat > .github/skills/salesforce-governor-limits/SKILL.md << 'SKILL_EOF'
---
description: >
  ガバナ制限の回避パターンやBatch/Queueable/Futureの選定が必要な場合に使用せよ。
  基本的な制限値は instructions/apex-coding.instructions.md で自動適用されるため、本スキルは
  「どのパターンで回避するか」の判断が必要な場面で参照すること。
  「Batchサイズ」「Queueable連鎖」「Too many SOQL queries」「System.LimitException」
  「パフォーマンス最適化」等のキーワードが出たら即座にロード。
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

## 詳細リファレンスへの誘導

- Batchサイズの計算・非同期処理の全制限値 → `reference/async-limits.md`
- 同期トランザクションの全制限値一覧 → `reference/sync-limits.md`
SKILL_EOF

echo "  salesforce-governor-limits/SKILL.md"

# --- 検査スクリプトの生成 ---
cat > .github/skills/salesforce-governor-limits/scripts/scan-governor-violations.sh << 'SCRIPT_EOF'
#!/usr/bin/env bash
# ガバナ制限違反候補のスキャン
# Usage: bash scan-governor-violations.sh <target-directory>
set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target-directory>}"
VIOLATIONS=0

echo "=== ガバナ制限違反候補スキャン ==="
echo "対象: ${TARGET_DIR}"
echo "実行日時: $(date)"
echo ""

# ループ内SOQL
echo "--- ループ内SOQL候補 ---"
grep -rn --include="*.cls" --include="*.trigger" -P 'for\s*\(' "${TARGET_DIR}" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINE_NUM=$(echo "$line" | cut -d: -f2)
  # 同一ファイルのループ内にSELECTがあるか簡易チェック
  if sed -n "${LINE_NUM},$((LINE_NUM+20))p" "$FILE" 2>/dev/null | grep -qi 'SELECT'; then
    echo "  [候補] ${FILE}:${LINE_NUM}"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done || true

# ループ内DML
echo ""
echo "--- ループ内DML候補 ---"
grep -rn --include="*.cls" --include="*.trigger" -P 'for\s*\(' "${TARGET_DIR}" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINE_NUM=$(echo "$line" | cut -d: -f2)
  if sed -n "${LINE_NUM},$((LINE_NUM+20))p" "$FILE" 2>/dev/null | grep -qiE '\b(insert|update|delete|upsert)\b'; then
    echo "  [候補] ${FILE}:${LINE_NUM}"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done || true

echo ""
echo "=== スキャン完了: 違反候補 ${VIOLATIONS} 件 ==="
echo "※ これらは候補であり、コードレビューで真の違反か判定してください"
SCRIPT_EOF

chmod +x .github/skills/salesforce-governor-limits/scripts/scan-governor-violations.sh

cat > .github/skills/salesforce-fls-security/SKILL.md << 'SKILL_EOF'
---
description: >
  FLS/CRUDチェックの具体的な使い分け判断が必要な場合に使用せよ。
  基本ルール（WITH USER_MODE原則等）は instructions/apex-coding.instructions.md で自動適用されるため、
  本スキルは「どのパターンを使うか」の詳細判断が必要な場面で参照すること。
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
SKILL_EOF

echo "  salesforce-fls-security/SKILL.md"

cat > .github/skills/salesforce-fls-security/scripts/scan-fls-compliance.sh << 'SCRIPT_EOF'
#!/usr/bin/env bash
# FLS準拠チェックスクリプト
# Usage: bash scan-fls-compliance.sh <target-directory>
set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target-directory>}"

echo "=== FLS準拠チェック ==="
echo "対象: ${TARGET_DIR}"
echo "実行日時: $(date)"
echo ""

echo "--- FLSチェック欠落候補（SOQLにWITH USER_MODE/SECURITY_ENFORCEDなし） ---"
grep -rn --include="*.cls" 'SELECT.*FROM' "${TARGET_DIR}" | \
  grep -vi 'WITH USER_MODE\|WITH SECURITY_ENFORCED\|@isTest\|Test' | \
  grep -vi '// FLS exempt' || echo "  検出なし"

echo ""
echo "--- without sharing 使用箇所 ---"
grep -rn --include="*.cls" 'without sharing' "${TARGET_DIR}" || echo "  検出なし"

echo ""
echo "=== スキャン完了 ==="
SCRIPT_EOF

chmod +x .github/skills/salesforce-fls-security/scripts/scan-fls-compliance.sh

# 残りの3 Skills（bulk-patterns, lwc-patterns, test-patterns）は
# SKILL.md のプレースホルダを配置
for SKILL_NAME in salesforce-bulk-patterns salesforce-lwc-patterns salesforce-test-patterns; do
  cat > ".github/skills/${SKILL_NAME}/SKILL.md" << EOF
---
description: "[TODO] 04_configuration_templates.md セクション7 のテンプレートに基づき記述してください"
---

# ${SKILL_NAME}

[TODO] このファイルは init-framework.sh が生成したプレースホルダです。
04_configuration_templates.md のセクション7を参照して内容を記述してください。
EOF
  echo "  ${SKILL_NAME}/SKILL.md (プレースホルダ)"
done

# ============================================================
# 5. settings.json の生成
# ============================================================
echo "[5/8] copilot.json を生成..."

cat > copilot.json << 'SETTINGS_EOF'
{
  "tools": {
    "allowed": [
      "run_terminal_command:sf project:*)",
      "run_terminal_command:sf apex:*)",
      "run_terminal_command:sf org:display)",
      "run_terminal_command:sf org:list)",
      "run_terminal_command:sf data:query:*)",
      "run_terminal_command:git add:*)",
      "run_terminal_command:git commit:*)",
      "run_terminal_command:git checkout:*)",
      "run_terminal_command:git branch:*)",
      "run_terminal_command:git merge:*)",
      "run_terminal_command:git log:*)",
      "run_terminal_command:git diff:*)",
      "run_terminal_command:git status)",
      "run_terminal_command:git stash:*)",
      "run_terminal_command:npx prettier:*)",
      "run_terminal_command:npm test:*)",
      "run_terminal_command:node:*)",
      "run_terminal_command:cat:*)",
      "run_terminal_command:mkdir:*)",
      "run_terminal_command:cp:*)",
      "run_terminal_command:mv:*)",
      "run_terminal_command:jq:*)",
      "run_terminal_command:bash .github/skills:*)",
      "read_file",
      "write_new_file",
      "edit_file",
      "search_files",
      "list_directory"
    ],
    "denied": [
      "run_terminal_command:sf org:delete:*)",
      "run_terminal_command:sf org:create:*)",
      "run_terminal_command:rm -rf:*)",
      "run_terminal_command:git push --force:*)",
      "run_terminal_command:git reset --hard:*)",
      "run_terminal_command:sf data:delete:*)",
      "run_terminal_command:curl:*)",
      "run_terminal_command:wget:*)"
    ]
  },
  "env": {
    "SF_API_VERSION": "62.0",
    "ARTIFACTS_DIR": "docs/projects",
    "METADATA_CATALOG_PATH": "metadata-catalog"
  }
}
SETTINGS_EOF

echo "  完了"

# ============================================================
# 6. AGENTS.md テンプレートの生成
# ============================================================
echo "[6/8] AGENTS.md テンプレートを生成..."

if [ ! -f "AGENTS.md" ]; then
cat > AGENTS.md << 'AGENTS_EOF'
# AGENTS.md — プロジェクトルート設定

## プロジェクト概要

- **案件名**: [TODO: 案件名を記入]
- **案件ID**: [TODO: 案件IDを記入]
- **対象Salesforce組織**: [TODO: 組織エイリアスを記入]
- **開発範囲**: [TODO: 開発範囲の概要を記入]

## コーディングルールの配置先

Salesforce開発のコーディングルールは `.github/instructions/` に配置されている。ファイル操作時に自動適用されるため、AGENTS.md には記載しない。

| ルールファイル | 適用条件 | 主な内容 |
|---|---|---|
| `.github/instructions/apex-coding.md` | `*.cls`, `*.trigger` 作業時 | ガバナ制限値、FLS必須、バルク化原則、命名規約、禁止パターン |
| `.github/instructions/lwc-coding.md` | `lwc/` 配下作業時 | Wire優先、SLDS準拠、イベント設計 |
| `.github/instructions/test-coding.md` | `*Test.cls` 作業時 | @TestSetup、SeeAllData禁止、カバレッジ基準 |
| `.github/instructions/commit-rules.md` | コミット操作時 | メッセージフォーマット、粒度ルール |
| `.github/instructions/review-rules.md` | レビュー作業時 | Severity定義、ゲート通過条件 |

## メタデータカタログ

- **スキーマ情報**: metadata-catalog/schema/
- **カタログ情報**: metadata-catalog/catalog/

## サブエージェント利用ガイドライン

### 利用可能なサブエージェント

| エージェント名 | 役割 | 呼び出しタイミング |
|---|---|---|
| `sf-metadata-analyst` | メタデータ取得・構造化 | Phase 0, Phase 2 |
| `sf-requirements-analyst` | 要件定義書の作成 | Phase 1 |
| `sf-designer` | 技術設計書の作成 | Phase 2 |
| `sf-implementer` | コードの新規作成・修正 | Phase 3 |
| `sf-tester` | テストコード作成・実行・静的解析 | Phase 4 |
| `sf-code-reviewer` | コードレビュー・品質チェック | Phase 5 |

### ヒューマンゲート制御手順

フェーズ完了時、リードエージェントは以下の手順でヒューマンゲートを制御する。

1. `docs/projects/${PROJECT_ID}/project-config.json` の `humanGates` 設定を `jq` で読み取る
2. ゲートが `true` の場合: 成果物サマリを出力し、承認/差し戻し/中断の応答を要求してターンを終了する
3. ゲートが `false` の場合: 成果物を保存し、自動的に次フェーズに進行する
4. ゲート設定の読み取りに失敗した場合: ゲート有効として扱う（フェイルセーフ）

**禁止**: ゲートが `true` の場合、人間の明示的な承認なしに次フェーズに進んではならない。

### コンテキスト管理

1. フェーズ完了ごとに `/compact` を実行してコンテキストを圧縮する
2. 大規模なメタデータはファイルに書き出し、サブエージェントには必要部分のみを渡す
3. 中間成果物は `docs/projects/` に保存し、後続フェーズで参照する

## 禁止事項

- 本番組織への直接デプロイ禁止
- `dangerously-skip-permissions` の使用禁止
- 旧 `sfdx` コマンドの使用禁止（`sf` v2 を使用すること）
AGENTS_EOF
echo "  AGENTS.md（新規作成）"
else
  echo "  AGENTS.md（既存のためスキップ）"
fi

if [ ! -f "force-app/.github/copilot-instructions.md" ]; then
  mkdir -p force-app
cat > force-app/.github/copilot-instructions.md << 'AGENTS_EOF'
# AGENTS.md — force-app 配下設定

## アーキテクチャ原則

### トリガフレームワーク
1. 1オブジェクト1トリガ構成を厳守する
2. トリガからハンドラクラスにロジックを委譲する

### レイヤー分離
- Selector層: SOQLクエリの集約
- Service層: ビジネスロジックの集約
- Domain層: トリガハンドラとバリデーション
- Controller層: LWC/Aura向けの @AuraEnabled メソッド

## コーディングルールの配置先

具体的なコーディングルールは `.github/instructions/` で自動適用される。

## メタデータ操作ルール

### 取得（Retrieve）
1. `sf project retrieve start` を使用
2. 全量取得禁止（メタデータタイプ指定なしでの実行は不可）

### デプロイ（Deploy）
1. 本番デプロイ前に必ず `--dry-run` で検証する
2. 本番デプロイ時は `-l RunLocalTests` を必ず指定する
AGENTS_EOF
echo "  force-app/.github/copilot-instructions.md（新規作成）"
else
  echo "  force-app/.github/copilot-instructions.md（既存のためスキップ）"
fi

# ============================================================
# 7. docs/architecture/ テンプレートの生成
# ============================================================
echo "[7/8] docs/architecture/ テンプレートを生成..."

if [ ! -f "docs/architecture/decisions/_template.md" ]; then
cat > docs/architecture/decisions/_template.md << 'ADR_EOF'
# ADR-XXX: [タイトル]

## ステータス
提案 / 承認 / 却下 / 廃止

## コンテキスト
[この判断が必要になった背景・状況]

## 判断
[選択した方針とその理由]

## 代替案
[検討した他の選択肢とその長所・短所]

## 影響
[この判断によって影響を受けるコンポーネント・プロセス]
ADR_EOF
echo "  decisions/_template.md"
fi

if [ ! -f "docs/architecture/system-context.md" ]; then
cat > docs/architecture/system-context.md << 'CTX_EOF'
# システムコンテキスト図

## レイヤー構成

[TODO: プロジェクト固有のレイヤー構成を記述]

## 外部連携マップ

[TODO: 外部システムとの連携を記述]
CTX_EOF
echo "  system-context.md"
fi

# ============================================================
# 8. .gitignore の更新
# ============================================================
echo "[8/8] .gitignore を更新..."

GITIGNORE_ENTRIES=(
  "raw-metadata/"
  ".copilot/worktrees/"
  "docs/projects/notifications.log"
  "docs/projects/execution.log"
)

for entry in "${GITIGNORE_ENTRIES[@]}"; do
  if ! grep -qF "${entry}" .gitignore 2>/dev/null; then
    echo "${entry}" >> .gitignore
  fi
done

echo "  完了"

# ============================================================
# 完了サマリ
# ============================================================
echo ""
echo "========================================"
echo "フレームワーク初期化完了"
echo ""
echo "生成されたファイル:"
echo "  .github/agents/          — カスタムエージェント定義 (6ファイル)"
echo "  .github/instructions/    — 条件付き自動適用ルール (5ファイル)"
echo "  .github/skills/          — 詳細ドメイン知識 (5ディレクトリ)"
echo "  copilot.json    — ツール許可/拒否設定"
echo "  AGENTS.md                — プロジェクトルート設定"
echo "  force-app/.github/copilot-instructions.md      — force-app配下設定"
echo "  docs/architecture/       — アーキテクチャテンプレート"
echo ""
echo "[TODO] 以下のプレースホルダファイルを完成させてください:"
find .github/agents -name "*.md" -exec grep -l "TODO" {} \; 2>/dev/null | sed 's/^/  /'
find .github/skills -name "SKILL.md" -exec grep -l "TODO" {} \; 2>/dev/null | sed 's/^/  /'
echo ""
echo "次のステップ:"
echo "  1. [TODO] マークのファイルを 02/04_*.md の定義に基づいて完成させる"
echo "  2. AGENTS.md のプロジェクト概要を記入する"
echo "  3. docs/architecture/system-context.md を記述する"
echo "  4. git add . && git commit -m 'chore: フレームワーク初期化'"
echo "  5. scripts/setup-project.sh で最初の案件をセットアップする"
echo "========================================"