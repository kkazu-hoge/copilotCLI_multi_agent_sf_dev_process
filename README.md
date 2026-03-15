# Salesforce マルチエージェント開発プロセスフレームワーク（Copilot CLI版）

GitHub Copilot CLI のカスタムエージェント構成を活用し、Salesforce 開発の全工程（メタデータ分析 → 要件定義 → 設計 → 実装 → テスト → コードレビュー → PR作成）をAIエージェントで自動化・半自動化するためのフレームワークです。

---

## 概要

本フレームワークは、Copilot CLI のメインエージェント（Claude Opus 4.6 / GPT-5.3-Codex 等）が6つの専門カスタムエージェントをオーケストレーションし、Salesforce開発のフェーズを逐次的に進行させます。各フェーズの境界にはヒューマンゲート（人間承認ポイント）を設けることができ、完全自動から人間監視付き半自動まで柔軟に運用できます。

### 主な特徴

- **7フェーズの開発プロセス**: Phase 0（初期セットアップ）からPhase 6（PR作成）までの体系的な開発フロー
- **6つの専門カスタムエージェント**: メタデータ分析、要件定義、設計、実装、テスト、コードレビューの各領域に特化
- **メタデータ駆動**: Salesforce組織のメタデータを構造化・抽象化し、コンテキスト効率を70-80%改善
- **アーキテクチャドキュメント管理**: システムコンテキスト図・ADR・横断的方針により、メタデータカタログ（What）を Why / How で補完
- **4レイヤー知識分散**: AGENTS.md（L1）→ instructions/（L2）→ agents/（L3）→ skills/（L4）の最適配置でコンテキスト効率を最大化
- **品質ゲート**: 各フェーズにエントリー条件・完了条件を設定し、品質を担保
- **自律フィードバックループ**: テスト失敗時の自動修正・再テストサイクル（最大3回）
- **コンテキストエンジニアリング**: 自動コンパクション（95%到達時）、instructions/ の条件付き自動適用、Skills機構の遅延ロードでトークンを最適化
- **Copilot CLI 固有機能の活用**: `/fleet` による並列エージェント実行、`/delegate` によるバックグラウンド委任、Plan モードによる事前計画策定、`/resume` によるセッション再開

---

## ドキュメント構成と相互関係

本フレームワークは以下の5つのドキュメントで構成されています。

| # | ドキュメント | 概要 | 主な参照先 |
|---|------------|------|-----------|
| 01 | [全体アーキテクチャ設計](01_architecture.md) | 開発プロセスのフロー図、フェーズ定義、ディレクトリ構成、コンテキスト管理戦略を定義 | 全ドキュメントの基盤 |
| 02 | [カスタムエージェント定義](02_agent_definitions.md) | 6つのカスタムエージェントの詳細仕様（description、ツール権限、システムプロンプト） | 01のエージェント構成、03の実行手順 |
| 03 | [フェーズ別実行手順書](03_execution_playbook.md) | 各フェーズの具体的な実行手順、プロンプト例、エラーハンドリング | 01のフェーズ定義、02のエージェント仕様 |
| 04 | [設定ファイルテンプレート](04_configuration_templates.md) | AGENTS.md、copilot.json、Hooks、案件セットアップ、instructions/ テンプレート、Skills テンプレート集 | 01のディレクトリ構成、05の品質基準 |
| 05 | [品質保証・運用ガイド](05_quality_and_operations.md) | 品質ゲート設計、コスト管理、アンチパターン、トラブルシューティング、instructions/skills 評価サイクル、運用定着ガイド | 01のフェーズ定義、04の設定項目 |

### ドキュメント間の関係図

```
01_architecture.md（基盤設計）
├── 02_agent_definitions.md（エージェント詳細）
│   └── 03_execution_playbook.md（実行手順）
├── 04_configuration_templates.md（設定テンプレート）
│   └── 05_quality_and_operations.md（品質・運用）
└── 03, 04, 05 は相互に参照
```

---

## 開発プロセスの全体像

```
Phase 0          Phase 1        Phase 2       Phase 3       Phase 4        Phase 5         Phase 6
初期セットアップ → 要件定義     → 設計        → 実装        → テスト        → コードレビュー → PR作成
& メタデータ取得   [承認ゲート]    [承認ゲート]                  [承認ゲート]     [承認ゲート]
```

| フェーズ | 担当エージェント | 主な成果物 |
|---------|----------------|-----------|
| Phase 0: 初期セットアップ | `sf-metadata-analyst` | メタデータカタログ（JSON） |
| Phase 1: 要件定義 | `sf-requirements-analyst` | `docs/projects/{PID}/requirements/` |
| Phase 2: 設計 | `sf-designer`, `sf-metadata-analyst` | `docs/projects/{PID}/design/` |
| Phase 3: 実装 | `sf-implementer` | Apex/LWC/Flowファイル群 |
| Phase 4: テスト | `sf-tester` | テストクラス、`docs/projects/{PID}/test-results/` |
| Phase 5: コードレビュー | `sf-code-reviewer` | `docs/projects/{PID}/review/` |
| Phase 6: PR作成 | メインエージェント | GitHub Pull Request |

---

## ディレクトリ構成

```
project-root/
├── .github/
│   ├── agents/                          # カスタムエージェント定義（ロール・手順特化）
│   │   ├── sf-metadata-analyst.agent.md
│   │   ├── sf-requirements-analyst.agent.md
│   │   ├── sf-designer.agent.md
│   │   ├── sf-implementer.agent.md
│   │   ├── sf-tester.agent.md
│   │   └── sf-code-reviewer.agent.md
│   ├── instructions/                    # 条件付き自動適用ルール
│   │   ├── apex-coding.instructions.md  # *.cls, *.trigger 作業時
│   │   ├── lwc-coding.instructions.md   # lwc/ 配下作業時
│   │   ├── test-coding.instructions.md  # *Test.cls 作業時
│   │   ├── commit-rules.instructions.md # コミット操作時
│   │   └── review-rules.instructions.md # レビュー作業時
│   ├── skills/                          # 詳細ドメイン知識（遅延ロード）
│   │   ├── salesforce-governor-limits/  # 判断フロー + reference/ + scripts/
│   │   ├── salesforce-fls-security/     # 判断フロー + reference/ + scripts/
│   │   ├── salesforce-bulk-patterns/    # 判断フロー + reference/
│   │   ├── salesforce-lwc-patterns/     # 判断フロー + reference/
│   │   └── salesforce-test-patterns/    # 判断フロー + reference/
│   ├── hooks/                           # ツール実行前後のフック
│   │   ├── pre-commit-lint.json
│   │   └── deny-dangerous-commands.json
│   └── copilot-instructions.md          # プロジェクト全体の補足指示
├── copilot.json                         # ツール許可/拒否設定
├── AGENTS.md                            # プロジェクト全体の規約（自動読み込み）
├── force-app/
│   ├── .github/
│   │   └── copilot-instructions.md      # Salesforce開発固有ルール
│   └── main/default/
│       ├── classes/                     # Apex クラス
│       ├── triggers/                    # Apex トリガ
│       ├── lwc/                         # Lightning Web Components
│       ├── flows/                       # Flow定義
│       ├── objects/                     # オブジェクト定義
│       ├── permissionsets/             # 権限セット
│       └── layouts/                    # ページレイアウト
├── metadata-catalog/                   # メタデータカタログ（組織ベースライン・全案件共通）
│   ├── schema/                         # オブジェクトJSON、リレーションマップ
│   ├── catalog/                        # 辞書、自動化一覧、権限マトリクス
│   └── scripts/                        # カタログ生成・更新スクリプト
├── docs/
│   ├── architecture/                   # システムレベル（全案件共通）
│   │   ├── system-context.md           # システムコンテキスト図・連携マップ
│   │   ├── decisions/                  # ADR（Architecture Decision Records）
│   │   └── policies/                   # 横断的方針（セキュリティ・パフォーマンス等）
│   └── projects/                       # 案件別ドキュメント（案件数分増加）
│       ├── index.json                  # 全案件の一覧・ステータス
│       └── {PROJECT_ID}/
│           ├── project-config.json     # 案件設定・ステータス追跡
│           ├── requirements/           # 要件定義書
│           ├── design/                 # 設計書
│           ├── test-results/           # テスト結果レポート
│           └── review/                 # レビュー結果・PR本文
├── scripts/                            # 運用スクリプト
│   ├── setup-project.sh
│   ├── run-pipeline.sh
│   ├── update-phase.sh
│   └── list-projects.sh
├── sfdx-project.json
├── package.xml
└── .gitignore
```

---

## クイックスタート

### 前提条件

| ツール | バージョン | 用途 |
|--------|----------|------|
| **GitHub Copilot CLI** | GA版（2026年2月〜） | マルチエージェント実行基盤 |
| **Copilot サブスクリプション** | Pro / Pro+ / Business / Enterprise | Copilot CLI の利用に必要 |
| **Salesforce CLI (`sf`)** | v2（最新推奨） | メタデータ取得・デプロイ |
| **Git** | 2.x以降 | バージョン管理 |
| **Node.js** | 18.x以降 | prettier-plugin-apex（オプション） |
| **GitHub CLI (`gh`)** | 2.x以降 | PR作成（オプション、Copilot CLI内蔵MCP でも可能） |
| **jq** | 1.6以降 | 案件管理スクリプト用 |

### 最小手順で始める方法

#### Step 1: プロジェクトの準備

```bash
# Salesforceプロジェクトのルートに移動
cd /path/to/salesforce-project

# 本フレームワークのドキュメントを参照可能な場所に配置
```

#### Step 2: フレームワークの初期化（初回のみ）

`scripts/init-framework.sh` を実行すると、agents/、instructions/、skills/、copilot.json、AGENTS.md 等のフレームワーク共通ファイルが一括生成されます。

```bash
# フレームワーク初期化スクリプトを実行
bash scripts/init-framework.sh

# 生成されたプレースホルダファイル（[TODO]マーク付き）を完成させる
# - .github/agents/ 配下の一部エージェント定義 → 02_agent_definitions.md の個別定義から転記
# - .github/skills/ 配下の一部SKILL.md → 04_configuration_templates.md セクション7から転記
# - AGENTS.md のプロジェクト概要 → 案件情報を記入
```

> `init-framework.sh` が生成するファイルの詳細は `04_configuration_templates.md` セクション5「フレームワーク導入の2段階」を参照。

#### Step 3: Salesforce組織への接続確認

```bash
# 組織への認証
sf org login web --alias my-sandbox --instance-url https://login.salesforce.com

# 接続確認
sf org display --target-org my-sandbox
```

#### Step 4: フレームワークの実行開始

```bash
# Copilot CLI を起動
copilot

# Phase 0: メタデータの取得・構造化
# CLI内で以下を実行:
# /agent sf-metadata-analyst
# > 対象組織のメタデータを取得・構造化してください。対象組織: my-sandbox
```

以降は `03_execution_playbook.md` の各フェーズの手順に従って進めます。

### 案件セットアップスクリプトを使う場合（推奨）

`scripts/init-framework.sh`（初回のみ）と `scripts/setup-project.sh`（案件ごと）の2段階でセットアップします。

```bash
# 1. フレームワーク初期化（初回のみ）
bash scripts/init-framework.sh

# 2. プレースホルダファイルを完成させる（手動）

# 3. 新規案件のセットアップ（案件ごと）
./scripts/setup-project.sh PROJ-001 my-sandbox "取引先スコアリング機能開発"
```

---

## ヒューマンゲートの設定

案件設定ファイル（`docs/projects/{PROJECT_ID}/project-config.json`）の `humanGates` セクションで各承認ポイントを制御できます。

```json
"humanGates": {
  "gate_requirements": true,
  "gate_design": true,
  "gate_test": true,
  "gate_pr": true
}
```

メインエージェントが各フェーズ完了時にこの設定を読み取り、ゲートが有効な場合は成果物サマリを提示して人間の承認を待ちます。Copilot CLIのターン制対話の性質を活用し、承認要求メッセージでターンを終了することでゲートとして機能します。

初回導入時はすべて `true`（有効）で運用し、信頼性が確認できたフェーズから段階的に無効化することを推奨します。

---

## 品質基準の概要

| 項目 | 基準値 |
|------|--------|
| Apexコードカバレッジ（全体） | 75%以上（必須） |
| Apexコードカバレッジ（個別クラス） | 80%以上（目標） |
| コードレビュー P1（Critical）指摘 | 0件（必須） |
| コードレビュー P2（Major）指摘 | 全件対応済み（必須） |
| テスト自動修正リトライ上限 | 3回 |
| カスタムエージェント数 | 6個 |

詳細は `05_quality_and_operations.md` を参照してください。

---

## Copilot CLI 固有の活用ポイント

| 機能 | コマンド | 活用シナリオ |
|------|---------|-------------|
| **カスタムエージェント呼び出し** | `/agent sf-metadata-analyst` | 各フェーズでの専門エージェント呼び出し |
| **Plan モード** | `Shift+Tab` | 複数フェーズの実装計画を事前に策定 |
| **並列エージェント** | `/fleet` | Phase 2 での設計・メタデータ取得の並列実行 |
| **バックグラウンド委任** | `/delegate` または `&` プレフィクス | 長時間のメタデータ取得やテスト実行 |
| **セッション再開** | `/resume` | 中断したセッションの再開 |
| **モデル切替** | `/model` | タスクに応じた最適モデルの選択 |
| **差分確認** | `/diff` | セッション内変更のインライン表示 |
| **コードレビュー** | `/review` | 組み込みレビュー + カスタムレビューエージェント |
| **自動コンパクション** | (自動) | 95%到達時に自動圧縮 |

---

## 関連リソース

- [GitHub Copilot CLI 公式ドキュメント](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)
- [カスタムエージェント作成ガイド](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli)
- [Agent Skills 作成ガイド](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills)
- [Salesforce CLI リファレンス](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Apex 開発者ガイド](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)
- [Lightning Web Components ガイド](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
