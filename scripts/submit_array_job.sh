#!/bin/bash
# ジョブ投入とモニタリング

echo "=== Submitting simpleFoam array job to JAIST Supercomputer ==="

# 環境確認
echo "Checking environment..."
if ! command -v sbatch &> /dev/null; then
    echo "ERROR: SLURM not found. Are you on the JAIST supercomputer?"
    echo "If using different job scheduler, modify job_scripts/simpleFoam_array.job accordingly"
    exit 1
fi

# モジュール確認
module list 2>&1 | grep -E "(openfoam|mpi)" || echo "WARNING: OpenFOAM/MPI modules may not be loaded"

# データ準備確認
echo "Checking converted data..."
if [ ! -d "simpleFoam_results" ]; then
    echo "ERROR: simpleFoam_results directory not found."
    echo "Run ./scripts/convert_all_patterns.sh first."
    exit 1
fi

PATTERN_COUNT=$(ls simpleFoam_results/ | grep -c pattern)
echo "Found $PATTERN_COUNT converted patterns"

if [ $PATTERN_COUNT -lt 90 ]; then
    echo "WARNING: Expected 90 patterns, found only $PATTERN_COUNT"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ログディレクトリ確認
mkdir -p logs

# ジョブファイル確認
if [ ! -f "job_scripts/simpleFoam_array.job" ]; then
    echo "ERROR: job_scripts/simpleFoam_array.job not found"
    exit 1
fi

# 現在のジョブ状況確認
echo ""
echo "Current job queue status:"
squeue -u $USER

# ジョブ投入
echo ""
echo "Submitting array job..."
JOB_OUTPUT=$(sbatch job_scripts/simpleFoam_array.job)
JOB_ID=$(echo "$JOB_OUTPUT" | awk '{print $4}')

if [ -z "$JOB_ID" ]; then
    echo "ERROR: Failed to submit job"
    echo "$JOB_OUTPUT"
    exit 1
fi

echo "Job submitted successfully!"
echo "Job ID: $JOB_ID"
echo "Array tasks: 1-90 (90 patterns)"

# 基本監視情報
echo ""
echo "=== Job Information ==="
echo "Job ID: $JOB_ID"
echo "Job name: simpleFoam_90patterns"
echo "Tasks: 90 (pattern_01 to pattern_90)"
echo "Expected runtime: 2-6 hours"
echo "Log files: logs/simpleFoam_${JOB_ID}_*.out"
echo "Error files: logs/simpleFoam_${JOB_ID}_*.err"

echo ""
echo "=== Monitoring Commands ==="
echo "Watch queue:       watch -n 30 'squeue -u $USER'"
echo "Monitor progress:  ./scripts/monitor_jobs.sh"
echo "Check specific log: tail -f logs/simpleFoam_${JOB_ID}_01.out"
echo "Cancel job:        scancel $JOB_ID"

echo ""
echo "=== Current Status ==="
squeue -u $USER

echo ""
echo "Job submitted! Monitor progress with the commands above."

# 簡易監視開始オプション
read -p "Start monitoring now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/monitor_jobs.sh
fi