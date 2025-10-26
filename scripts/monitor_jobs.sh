#!/bin/bash
# リアルタイム監視スクリプト

echo "=== JAIST Supercomputer Job Monitor ==="
echo "Press Ctrl+C to exit monitoring"
echo ""

# 監視開始時刻記録
touch logs/.monitor_start

while true; do
    clear
    echo "$(date)"
    echo "================================================"
    
    # ジョブ状況
    echo "Current jobs in queue:"
    RUNNING_JOBS=$(squeue -u $USER -h | wc -l)
    if [ $RUNNING_JOBS -eq 0 ]; then
        echo "No jobs in queue"
    else
        squeue -u $USER
    fi
    
    echo ""
    echo "Job states summary:"
    squeue -u $USER -h | awk '{print $5}' | sort | uniq -c | awk '{printf "  %s: %d\n", $2, $1}'
    
    echo ""
    echo "Completed patterns:"
    # 最終時刻(100)のT場ファイルが存在するパターンをカウント
    COMPLETED=$(find simpleFoam_results/*/100/ -name "T" 2>/dev/null | wc -l)
    echo "$COMPLETED / 90"
    
    # 進捗バー表示
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
    
    # 最近完了したパターン
    echo ""
    echo "Recently completed patterns:"
    find simpleFoam_results/*/100/ -name "T" -newer logs/.monitor_start 2>/dev/null | \
        sed 's/.*pattern_\([0-9]*\).*/\1/' | sort -n | tail -5 | tr '\n' ' '
    echo ""
    
    # エラー確認
    echo ""
    echo "Recent errors (if any):"
    ERROR_COUNT=$(find logs/ -name "simpleFoam_*.err" -newer logs/.monitor_start -size +0 2>/dev/null | wc -l)
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "Found $ERROR_COUNT error files with content:"
        find logs/ -name "simpleFoam_*.err" -newer logs/.monitor_start -size +0 2>/dev/null | head -3 | \
            xargs -I {} basename {} | sed 's/simpleFoam_.*_\([0-9]*\)\.err/Pattern \1/'
    else
        echo "No errors detected"
    fi
    
    # 実行統計
    echo ""
    echo "Execution statistics:"
    TOTAL_RUNTIME=0
    PATTERN_COUNT=0
    
    # 実行完了したパターンの実行時間を推定
    for pattern_dir in simpleFoam_results/pattern_*/; do
        if [ -f "$pattern_dir/100/T" ]; then
            PATTERN_COUNT=$((PATTERN_COUNT + 1))
        fi
    done
    
    if [ $PATTERN_COUNT -gt 0 ]; then
        # 推定残り時間（非常に粗い見積もり）
        if [ $RUNNING_JOBS -gt 0 ] && [ $COMPLETED -lt 90 ]; then
            REMAINING=$((90 - COMPLETED))
            AVG_TIME_PER_PATTERN=10  # 分単位での推定
            EST_REMAINING_TIME=$((REMAINING * AVG_TIME_PER_PATTERN / RUNNING_JOBS))
            echo "Estimated remaining time: ~${EST_REMAINING_TIME} minutes"
        fi
    fi
    
    echo ""
    echo "Last updated: $(date)"
    echo "Next update in 30 seconds... (Ctrl+C to exit)"
    
    sleep 30
done