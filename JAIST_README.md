# JAISTスーパーコンピュータでのsimpleFoam実行手順

## 📋 実行手順概要

### 1. 環境準備
```bash
# 作業ディレクトリ移動
cd /Users/takeuchidaiki/research/stepB_project

# 実行権限付与
chmod +x scripts/*.sh job_scripts/*.job

# 環境設定（JAISTスパコンで実行）
./scripts/setup_supercomputer.sh
```

### 2. データ変換
```bash
# 全90パターンをsimpleFoam用に変換
./scripts/convert_all_patterns.sh
```

### 3. ジョブ投入
```bash
# アレイジョブ投入
./scripts/submit_array_job.sh
```

### 4. 監視
```bash
# リアルタイム監視
./scripts/monitor_jobs.sh
```

### 5. 結果確認
```bash
# 結果収集・検証
./scripts/collect_results.sh
```

## 🗂️ ファイル構成

```
project_root/
├── JAIST_supercomputer_implementation.md  # 詳細仕様書
├── JAIST_README.md                       # この実行手順書
├── scripts/
│   ├── setup_supercomputer.sh            # 環境設定
│   ├── convert_all_patterns.sh           # データ変換
│   ├── submit_array_job.sh               # ジョブ投入
│   ├── monitor_jobs.sh                   # 監視
│   └── collect_results.sh                # 結果収集
├── job_scripts/
│   └── simpleFoam_array.job              # SLURMアレイジョブ
├── templates/
│   ├── fvSolution_parallel.template      # 並列ソルバー設定
│   ├── fvSchemes.template                # 離散化スキーム
│   └── physicalProperties.template       # 物理特性
└── simpleFoam_results/                   # 計算結果（作成される）
```

## ⚡ 期待される性能

- **実行時間**: 2-6時間（全90パターン並列実行）
- **使用リソース**: 720 CPU時間（90パターン × 8コア × 平均1時間）
- **短縮効果**: 従来の45時間から最大95%短縮

## 🔧 JAISTスパコン特有の設定

### ジョブスケジューラ: SLURM
- アレイジョブで90パターン同時実行
- パターンあたり8コア並列計算
- 最大実行時間: 3時間

### 並列計算設定
- MPI: 8プロセス/パターン
- メモリ: 16GB/ノード
- ストレージ: 高速ローカル→共有への効率的データ転送

### 最適化要素
- 高速ローカルストレージ活用
- バイナリ出力による高速I/O
- GAMG/smoothSolverによる効率的求解

## 🚨 トラブルシューティング

### よくある問題

#### モジュールが見つからない
```bash
module avail openfoam  # 利用可能なOpenFOAMバージョン確認
module load openfoam/XX.X  # 適切なバージョンをロード
```

#### ジョブが投入できない
```bash
sinfo  # パーティション情報確認
squeue  # キュー状況確認
# job_scripts/simpleFoam_array.job の #SBATCH --partition= を調整
```

#### 計算が失敗する
```bash
# エラーログ確認
tail logs/simpleFoam_JOBID_01.err

# 個別パターンのデバッグ実行
cd simpleFoam_results/pattern_01
sbatch --nodes=1 --ntasks=1 --wrap="checkMesh"
```

## 📊 期待される結果

### 成功基準
- 85パターン以上完了 (94%以上)
- 完了パターンの95%以上で収束
- 全場（U, p, T）の適切な出力

### データ品質
- 速度場: 物理的に妥当な流れパターン
- 圧力場: 連続的な圧力分布
- 濃度場: 元のscalarTransportFoamとの整合性

## 🎯 次ステップ

計算完了後:
1. GNN学習データセットの構築
2. 従来結果との比較分析
3. 流体場予測モデルの開発

---

**重要**: JAISTスーパーコンピュータの具体的な仕様（パーティション名、モジュール名など）に合わせて設定を調整してください。