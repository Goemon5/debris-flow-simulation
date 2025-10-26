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

# 監視用ファイル作成
touch logs/.monitor_start

echo "Environment setup completed"
echo "OpenFOAM version: $(simpleFoam -help 2>&1 | head -1)"
echo "MPI version: $(mpirun --version | head -1)"
echo "Working directory: $FOAM_RUN"

# 権限設定
chmod +x scripts/*.sh job_scripts/*.sh