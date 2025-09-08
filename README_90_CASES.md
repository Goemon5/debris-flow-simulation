# 90-Case CFD Simulation System

本番用の自動化スクリプト `run_all_90_cases.sh` を使用して、30種類の瓦礫パターン × 3種類の匂い源 = 合計90ケースのCFDシミュレーションを並列実行します。

## 概要

`run_scent_with_openfoam10.sh` を基に開発された生産用スクリプトです。OpenFOAM 10のscalarTransportFoamソルバーを使用して、災害現場での匂い拡散シミュレーションを自動化実行します。

## システム構成

### 必要な入力データ
- **パターンディレクトリ**: `pattern_01/` ～ `pattern_30/` (30パターン)
- **各パターン内の流体場データ**: `pattern_XX/5/` ディレクトリの速度場(U)・圧力場(p)
- **各パターン内のメッシュデータ**: `pattern_XX/constant/polyMesh/`

### 匂い源配置
計算領域内に3つの戦略的位置を設定:

```bash
declare -A sources
sources[center]="(7.5 7.5 0.5)"   # Center position
sources[upwind]="(5.0 7.5 1.0)"   # Upwind position  
sources[side]="(7.5 5.0 1.5)"     # Side position
```

### 出力構造
```
simulation_results_90cases/
├── pattern_01_center/
│   ├── 0/     # 初期条件
│   ├── 0.5/   # 0.5秒時点
│   ├── 1/     # 1秒時点
│   ├── ...
│   └── 5/     # 最終時点 (U, p, T フィールド)
├── pattern_01_upwind/
├── pattern_01_side/
├── pattern_02_center/
└── ...

logs_90cases/
├── pattern_01_center.log
├── pattern_01_upwind.log
├── pattern_01_side.log
└── ...
```

## 実行前の準備

### 必要なディレクトリ構造

以下のディレクトリ構造が必要です：

```
stepB_project/
├── pattern_01/
│   ├── constant/
│   │   └── polyMesh/          # メッシュファイル
│   └── 5/                     # 流れ場計算結果
│       ├── U                  # 速度場
│       └── p                  # 圧力場
├── pattern_02/
│   ├── constant/polyMesh/
│   └── 5/
│       ├── U
│       └── p
├── ...
├── pattern_30/
│   ├── constant/polyMesh/
│   └── 5/
│       ├── U
│       └── p
└── run_all_90_cases.sh       # 実行スクリプト
```

### 前提条件
1. Docker環境が利用可能
2. OpenFOAM 10コンテナ (`openfoam/openfoam10-paraview510`)
3. パターンディレクトリ (`pattern_01` から `pattern_30` までが存在)
4. 各パターンで流れ場計算が完了済み

## 実行方法

### 基本実行

```bash
./run_all_90_cases.sh
```

### スクリプトの主要機能

#### 1. 並列実行数の変更
スクリプトの先頭で `MAX_JOBS` を変更：

```bash
# デフォルト値
MAX_JOBS=4

# システムリソースに応じて調整
MAX_JOBS=8  # 高性能システム用
MAX_JOBS=2  # 低リソースシステム用
```

#### 2. 匂い源位置の変更
スクリプト内の `sources` 配列を編集：

```bash
declare -A sources
sources[center]="(7.5 7.5 0.5)"   # 中央位置
sources[upwind]="(5.0 7.5 1.0)"   # 風上位置  
sources[side]="(7.5 5.0 1.5)"     # 側面位置
```

## 主要機能の詳細

### 1. ループ化
- 外側のループ: 30個の瓦礫パターンディレクトリ (`pattern_01` ～ `pattern_30`)
- 内側のループ: 3種類の匂い源 (center, upwind, side)
- 合計90ケースを順次処理

### 2. パラメータ化された匂い源設定
- スクリプト起動時に3つの匂い源位置を変数として定義
- 各シミュレーションで `system/fvOptions` と `system/topoSetDict` を動的生成
- 匂い源は半径30cmの球領域として設定

### 3. 体系的な出力管理
- 命名規則: `[パターン名]_[匂い源名]` (例: `pattern_01_center`)
- 結果ディレクトリ: `simulation_results_90cases/`
- ログディレクトリ: `logs_90cases/`

### 4. 並列実行機能
- デフォルト: 最大4つの同時実行
- ジョブ管理による効率的なリソース利用
- `wait -n` による完了待機制御

## 実行例

```bash
$ ./run_all_90_cases.sh

===============================================
Production CFD Simulation: 90 Cases
30 Debris Patterns × 3 Odor Sources
===============================================

Starting 90-case simulation workflow...
Configuration:
  - Patterns: pattern_01 to pattern_30 (30 patterns)
  - Source locations: center, upwind, side (3 locations)
  - Total cases: 90 simulations
  - Max parallel jobs: 4

[10:30:15] Progress: 1/90
Queuing: pattern_01, Source center
Started job PID 12345: pattern_01, Source center
Active jobs: 1/4
...
```

## 進捗監視

### 実行中の確認
```bash
# 完了ケース数の確認
ls simulation_results_90cases/*/5/T | wc -l

# 特定ケースのログ確認
tail -f logs_90cases/pattern_01_center.log

# 実行中プロセス確認
ps aux | grep scalarTransportFoam
```

## トラブルシューティング

### よくある問題

1. **パターンディレクトリが見つからない**
   ```
   Skipping pattern_XX (directory not found)
   ```
   → パターンディレクトリの存在を確認

2. **メッシュファイルがない**
   ```
   ERROR: Mesh not found in pattern_XX/constant/polyMesh
   ```
   → 各パターンでメッシュ生成が完了していることを確認

3. **流れ場データがない**
   ```
   ERROR: Field U not found in pattern_XX/5/U
   ```
   → 流れ場計算が完了していることを確認

### ログ確認
```bash
# 成功/失敗の統計
grep "SUCCESS:" logs_90cases/*.log | wc -l
grep "FAILED:" logs_90cases/*.log | wc -l

# エラーログの確認
grep -l "ERROR" logs_90cases/*.log
```

## システム要求と実行時間

### 推奨システム構成
- **CPU**: 4-8コア推奨
- **メモリ**: 8GB以上推奨  
- **ディスク**: 数十GB以上の空き容量
- **Docker**: OpenFOAM 10コンテナイメージ

### 実行時間の目安
- **1ケース**: 約5-10分
- **90ケース（4並列）**: 約2-4時間

## 出力データ

各ケースで以下の3つのフィールドが生成されます：
- **U**: 速度場 (ベクトルフィールド)
- **p**: 圧力場 (スカラーフィールド)  
- **T**: 濃度場 (スカラーフィールド) - GNNのメインターゲット

### データ形式
- **ファイル形式**: OpenFOAM形式 (ASCII)
- **時系列**: 0.5秒間隔で5秒まで
- **命名規則**: `pattern_XX_SOURCENAME`

---

**作成日**: $(date '+%Y-%m-%d')  
**バージョン**: 1.0  
**ベーススクリプト**: run_scent_with_openfoam10.sh  
**OpenFOAM**: Version 10