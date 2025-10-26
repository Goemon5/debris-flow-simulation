# JAISTスーパーコンピュータ用 simpleFoam実装仕様書

## 🖥️ JAIST スーパーコンピュータ環境概要

### システム仕様（想定）
- **OS**: Linux (CentOS/RHEL系)
- **ジョブ管理**: SLURM/PBS/LSF
- **並列処理**: OpenMPI/IntelMPI
- **ファイルシステム**: 高速並列I/O
- **OpenFOAM**: モジュールシステムで提供

### 利用可能リソース
- **ノード数**: 多数（数百〜数千ノード）
- **CPU**: 高性能CPUクラスタ
- **メモリ**: ノードあたり数十GB〜数百GB
- **ストレージ**: 高速並列ファイルシステム

---

## 🎯 スパコン最適化設計

### 実行戦略の変更

#### 従来計画（Docker環境）
- 同時実行数: 4プロセス
- 予想時間: 45時間
- リソース: ローカルマシン

#### スパコン環境での新戦略
- **大規模並列実行**: 90パターン同時実行可能
- **予想時間**: 2-6時間（大幅短縮）
- **MPI並列**: 各パターンで8-16コア使用
- **アレイジョブ**: 1つのジョブで全パターン管理

### アーキテクチャ設計

```
┌─────────────────────────────────────────┐
│           JAISTスーパーコンピュータ        │
├─────────────────────────────────────────┤
│  ジョブスケジューラ (SLURM/PBS)          │
├─────────────────────────────────────────┤
│  アレイジョブ: simpleFoam_array.job      │
│  ├─ Task 1: pattern_01 (8 cores)       │
│  ├─ Task 2: pattern_02 (8 cores)       │
│  ├─ ...                                │
│  └─ Task 90: pattern_90 (8 cores)      │
├─────────────────────────────────────────┤
│  共有ファイルシステム                     │
│  ├─ input_data/                        │
│  ├─ simpleFoam_results/                │
│  └─ logs/                              │
└─────────────────────────────────────────┘
```

---

## 🔧 実装仕様

### ディレクトリ構造

```
/home/username/simpleFoam_project/
├── scripts/
│   ├── setup_supercomputer.sh          # 初期環境設定
│   ├── convert_all_patterns.sh         # 全パターン一括変換
│   ├── submit_array_job.sh              # ジョブ投入スクリプト
│   ├── monitor_jobs.sh                  # ジョブ監視
│   └── collect_results.sh               # 結果収集
├── job_scripts/
│   ├── simpleFoam_array.job             # メインアレイジョブ
│   ├── single_pattern.sh                # 単一パターン実行
│   └── postprocess.job                  # 後処理ジョブ
├── templates/
│   ├── controlDict.template
│   ├── fvSolution_parallel.template     # 並列計算用
│   ├── fvSchemes.template
│   └── physicalProperties.template
├── input_data/                          # 元データ（90パターン）
├── simpleFoam_results/                  # 計算結果
└── logs/                               # 実行ログ
```

### 主要スクリプト

#### 1. setup_supercomputer.sh
```bash
#!/bin/bash
# JAIST スーパーコンピュータ環境設定

echo "=== JAIST Supercomputer Setup ==="

# OpenFOAMモジュールロード
module purge
module load openfoam/10.0  # バージョンは環境に合わせて調整
module load openmpi/4.1.0

# 環境変数設定
export FOAM_RUN=$HOME/simpleFoam_project
export OMP_NUM_THREADS=1  # OpenFOAM用

# ディレクトリ作成
mkdir -p $FOAM_RUN/{scripts,job_scripts,templates,input_data,simpleFoam_results,logs}

echo "Environment setup completed"
echo "OpenFOAM version: $(simpleFoam -help 2>&1 | head -1)"
```

#### 2. simpleFoam_array.job
```bash
#!/bin/bash
#SBATCH --job-name=simpleFoam_90patterns
#SBATCH --array=1-90
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --mem=16GB
#SBATCH --output=logs/simpleFoam_%A_%a.out
#SBATCH --error=logs/simpleFoam_%A_%a.err

# 環境設定
module load openfoam/10.0
module load openmpi/4.1.0

# パターン番号（0埋め2桁）
PATTERN_ID=$(printf "%02d" $SLURM_ARRAY_TASK_ID)
CASE_DIR="simpleFoam_results/pattern_${PATTERN_ID}"
WORK_DIR="/tmp/pattern_${PATTERN_ID}_$$"

echo "Starting pattern $PATTERN_ID on node $(hostname)"
echo "Work directory: $WORK_DIR"

# 作業ディレクトリ設定（高速ローカルストレージ使用）
mkdir -p $WORK_DIR
cp -r $CASE_DIR/* $WORK_DIR/
cd $WORK_DIR

# 並列計算実行
echo "Running decomposePar..."
decomposePar -case . > decomposePar.log 2>&1

echo "Running simpleFoam in parallel..."
mpirun -np 8 simpleFoam -parallel > simpleFoam.log 2>&1

echo "Running reconstructPar..."
reconstructPar -case . > reconstructPar.log 2>&1

# 結果を共有ストレージにコピー
echo "Copying results back..."
rsync -av --exclude="processor*" $WORK_DIR/ $CASE_DIR/

# 一時ディレクトリ清掃
rm -rf $WORK_DIR

echo "Pattern $PATTERN_ID completed"
```

#### 3. convert_all_patterns.sh
```bash
#!/bin/bash
# 全90パターンの設定変換

SOURCE_DIR="simulation_results_90patterns"
TARGET_DIR="simpleFoam_results"

echo "Converting all 90 patterns for simpleFoam..."

for i in {01..90}; do
    echo "Converting pattern_$i..."
    
    # ディレクトリ作成
    mkdir -p ${TARGET_DIR}/pattern_$i
    
    # ファイルコピー
    cp -r ${SOURCE_DIR}/pattern_$i/* ${TARGET_DIR}/pattern_$i/
    
    cd ${TARGET_DIR}/pattern_$i
    
    # controlDict変更
    sed -i 's/scalarTransportFoam/simpleFoam/g' system/controlDict
    sed -i 's/deltaT          0.005/deltaT          0.01/g' system/controlDict
    sed -i 's/endTime         5/endTime         100/g' system/controlDict  # 定常計算
    
    # 並列計算用設定追加
    cat >> system/controlDict << EOF

// Parallel computation settings
writeFormat     binary;
runTimeModifiable false;
EOF
    
    # fvSolution更新（並列計算対応）
    cp ../../templates/fvSolution_parallel.template system/fvSolution
    
    # fvSchemes更新（定常計算用）
    cp ../../templates/fvSchemes.template system/fvSchemes
    
    # 物理特性更新
    cp ../../templates/physicalProperties.template constant/physicalProperties
    
    # 古い結果削除
    rm -rf [0-9]* processor* postProcessing/ log.*
    
    cd ../..
    echo "Pattern_$i conversion completed"
done

echo "All conversions completed!"
```

#### 4. テンプレートファイル

##### fvSolution_parallel.template
```openfoam
FoamFile { format ascii; class dictionary; location "system"; object fvSolution; }

solvers
{
    p
    {
        solver          GAMG;
        tolerance       1e-07;
        relTol          0.01;
        smoother        GaussSeidel;
        nPreSweeps      0;
        nPostSweeps     2;
        cacheAgglomeration on;
        agglomerator    faceAreaPair;
        nCellsInCoarsestLevel 100;
        mergeLevels     1;
    }
    
    U
    {
        solver          smoothSolver;
        smoother        GaussSeidel;
        tolerance       1e-06;
        relTol          0.01;
        nSweeps         1;
    }
    
    T
    {
        solver          GAMG;
        tolerance       1e-07;
        relTol          0.01;
        smoother        GaussSeidel;
        nPreSweeps      0;
        nPostSweeps     2;
        cacheAgglomeration on;
        agglomerator    faceAreaPair;
        nCellsInCoarsestLevel 100;
        mergeLevels     1;
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 0;
    consistent              yes;
    
    residualControl
    {
        p               1e-5;
        U               1e-5;
        T               1e-5;
    }
}

relaxationFactors
{
    equations
    {
        U               0.7;
        p               0.3;
        T               0.9;
    }
}
```

#### 5. submit_array_job.sh
```bash
#!/bin/bash
# ジョブ投入とモニタリング

echo "=== Submitting simpleFoam array job to JAIST Supercomputer ==="

# 事前チェック
echo "Checking environment..."
module list
which mpirun
which simpleFoam

# データ準備確認
if [ ! -d "simpleFoam_results/pattern_01" ]; then
    echo "Error: Converted data not found. Run convert_all_patterns.sh first."
    exit 1
fi

echo "Found $(ls simpleFoam_results/ | wc -l) converted patterns"

# ジョブ投入
echo "Submitting array job..."
JOB_ID=$(sbatch job_scripts/simpleFoam_array.job | awk '{print $4}')

echo "Job submitted with ID: $JOB_ID"
echo "Monitor with: squeue -u $USER"
echo "Cancel with: scancel $JOB_ID"

# 基本監視情報
echo ""
echo "=== Job Status ==="
squeue -u $USER

echo ""
echo "=== Quick Monitor Commands ==="
echo "Watch queue:     watch -n 30 'squeue -u $USER'"
echo "Check logs:      tail -f logs/simpleFoam_${JOB_ID}_*.out"
echo "Count completed: ls simpleFoam_results/*/100/ 2>/dev/null | wc -l"
```

#### 6. monitor_jobs.sh
```bash
#!/bin/bash
# リアルタイム監視スクリプト

echo "=== JAIST Supercomputer Job Monitor ==="

while true; do
    clear
    echo "$(date)"
    echo "=========================="
    
    # ジョブ状況
    echo "Running jobs:"
    squeue -u $USER
    
    echo ""
    echo "Completed patterns:"
    COMPLETED=$(find simpleFoam_results/*/100/ -name "T" 2>/dev/null | wc -l)
    echo "$COMPLETED / 90"
    
    # 進捗バー
    PROGRESS=$((COMPLETED * 100 / 90))
    printf "Progress: ["
    for ((i=0; i<50; i++)); do
        if [ $i -lt $((PROGRESS/2)) ]; then
            printf "="
        else
            printf " "
        fi
    done
    printf "] %d%%\n" $PROGRESS
    
    echo ""
    echo "Recent errors:"
    find logs/ -name "*.err" -newer logs/.monitor_start 2>/dev/null | head -3
    
    sleep 30
done
```

---

## ⚡ 性能最適化

### MPI並列設定
- **コア数**: パターンあたり8コア（メッシュサイズに応じて調整）
- **メモリ**: ノードあたり16GB
- **通信**: InfiniBandによる高速通信

### I/O最適化
- **ローカル作業**: 各ノードの高速ローカルストレージ使用
- **バイナリ出力**: 書き込み時間短縮
- **結果圧縮**: ストレージ効率化

### ジョブ最適化
- **アレイジョブ**: 90パターン並列実行
- **チェックポイント**: 中断からの再開可能
- **リソース最適化**: 必要最小限のリソース要求

---

## 📊 予想性能

### 時間短縮効果
- **従来予想**: 45時間（ローカル環境）
- **スパコン環境**: 2-6時間
- **短縮率**: 87-95%

### リソース効率
- **CPU時間**: 90パターン × 8コア × 3時間 = 2,160 CPU時間
- **実時間**: 約3時間（並列実行）
- **効率**: 720倍の並列化

---

## 🚀 実行手順

### 1. 環境準備
```bash
chmod +x scripts/*.sh job_scripts/*.sh
./scripts/setup_supercomputer.sh
```

### 2. データ変換
```bash
./scripts/convert_all_patterns.sh
```

### 3. ジョブ投入
```bash
./scripts/submit_array_job.sh
```

### 4. 監視
```bash
./scripts/monitor_jobs.sh
```

### 5. 結果確認
```bash
./scripts/collect_results.sh
```

この実装により、JAISTスーパーコンピュータの能力を最大限活用し、大幅な時間短縮を実現できます。

---

**作成日**: 2025-10-13  
**対象**: JAISTスーパーコンピュータ環境  
**予想実行時間**: 2-6時間  
**最大並列度**: 90パターン同時実行