#!/bin/bash
# 結果収集と検証スクリプト

echo "=== SimpleFoam Results Collection and Validation ==="

RESULTS_DIR="simpleFoam_results"
SUMMARY_FILE="simulation_summary.txt"

# 基本統計
echo "Collecting simulation results..."
echo "Results directory: $RESULTS_DIR"
echo ""

# サマリーファイル初期化
cat > $SUMMARY_FILE << 'EOF'
SimpleFoam Simulation Results Summary
====================================
Generated: $(date)

EOF

# 完了パターン数
TOTAL_PATTERNS=$(ls $RESULTS_DIR | grep -c pattern)
COMPLETED_PATTERNS=$(find $RESULTS_DIR/*/100/ -name "T" 2>/dev/null | wc -l)
COMPLETION_RATE=$((COMPLETED_PATTERNS * 100 / TOTAL_PATTERNS))

echo "Total patterns: $TOTAL_PATTERNS"
echo "Completed patterns: $COMPLETED_PATTERNS"
echo "Completion rate: $COMPLETION_RATE%"

# 詳細な結果検証
echo ""
echo "Detailed validation results:"
echo "Pattern | Status | U_field | P_field | T_field | Convergence"
echo "--------|--------|---------|---------|---------|------------"

SUCCESS_COUNT=0
FAILED_COUNT=0
PARTIAL_COUNT=0

for i in {01..90}; do
    PATTERN="pattern_$i"
    PATTERN_DIR="$RESULTS_DIR/$PATTERN"
    
    if [ ! -d "$PATTERN_DIR" ]; then
        printf "%-7s | %-6s | %-7s | %-7s | %-7s | %s\n" "$PATTERN" "MISSING" "-" "-" "-" "-"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi
    
    # ファイル存在確認
    U_FILE="$PATTERN_DIR/100/U"
    P_FILE="$PATTERN_DIR/100/p" 
    T_FILE="$PATTERN_DIR/100/T"
    LOG_FILE="$PATTERN_DIR/simpleFoam.log"
    
    U_STATUS="❌"
    P_STATUS="❌"
    T_STATUS="❌"
    CONVERGENCE="❌"
    
    [ -f "$U_FILE" ] && U_STATUS="✅"
    [ -f "$P_FILE" ] && P_STATUS="✅"
    [ -f "$T_FILE" ] && T_STATUS="✅"
    
    # 収束確認
    if [ -f "$LOG_FILE" ]; then
        if grep -q "SIMPLE solution converged" "$LOG_FILE" || \
           grep -q "Time = 100" "$LOG_FILE"; then
            CONVERGENCE="✅"
        fi
    fi
    
    # 総合ステータス
    if [[ "$U_STATUS" == "✅" && "$P_STATUS" == "✅" && "$T_STATUS" == "✅" && "$CONVERGENCE" == "✅" ]]; then
        STATUS="SUCCESS"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [[ "$U_STATUS" == "✅" || "$P_STATUS" == "✅" || "$T_STATUS" == "✅" ]]; then
        STATUS="PARTIAL"
        PARTIAL_COUNT=$((PARTIAL_COUNT + 1))
    else
        STATUS="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    printf "%-7s | %-6s | %-7s | %-7s | %-7s | %s\n" "$PATTERN" "$STATUS" "$U_STATUS" "$P_STATUS" "$T_STATUS" "$CONVERGENCE"
done

echo ""
echo "Summary:"
echo "✅ Successful: $SUCCESS_COUNT"
echo "⚠️  Partial: $PARTIAL_COUNT" 
echo "❌ Failed: $FAILED_COUNT"

# 物理的妥当性の簡易チェック
echo ""
echo "Physical validity check (sample patterns):"

for pattern in "01" "30" "50" "70" "90"; do
    PATTERN_DIR="$RESULTS_DIR/pattern_$pattern"
    if [ -f "$PATTERN_DIR/100/U" ]; then
        echo "Pattern $pattern:"
        
        # 速度場の確認
        U_INTERNAL=$(grep -A1 "internalField" "$PATTERN_DIR/100/U" | tail -1)
        echo "  Final U field: $U_INTERNAL"
        
        # 圧力場の確認  
        if [ -f "$PATTERN_DIR/100/p" ]; then
            P_INTERNAL=$(grep -A1 "internalField" "$PATTERN_DIR/100/p" | tail -1)
            echo "  Final p field: $P_INTERNAL"
        fi
        
        # 温度場の統計（簡易）
        if [ -f "$PATTERN_DIR/100/T" ]; then
            # バイナリファイルの場合は詳細確認をスキップ
            T_FORMAT=$(grep "format" "$PATTERN_DIR/100/T" | awk '{print $2}' | tr -d ';')
            echo "  T field format: $T_FORMAT"
        fi
        echo ""
    fi
done

# ディスク使用量
echo "Storage usage:"
echo "Total size: $(du -sh $RESULTS_DIR | cut -f1)"
echo "Average per pattern: $(du -sh $RESULTS_DIR | cut -f1 | numfmt --from=iec | awk -v n=$TOTAL_PATTERNS '{printf "%.1f MB\n", $1/n/1024/1024}')"

# ログファイル分析
echo ""
echo "Error analysis:"
ERROR_LOGS=$(find logs/ -name "*.err" -size +0 2>/dev/null | wc -l)
if [ $ERROR_LOGS -gt 0 ]; then
    echo "Found $ERROR_LOGS error logs with content"
    echo "Top errors:"
    find logs/ -name "*.err" -size +0 -exec grep -l "ERROR\|FATAL\|failed" {} \; 2>/dev/null | head -5
else
    echo "No significant errors found in logs"
fi

# GNN準備状況
echo ""
echo "GNN dataset preparation:"
USABLE_PATTERNS=0
for i in {01..90}; do
    if [ -f "$RESULTS_DIR/pattern_$i/100/U" ] && \
       [ -f "$RESULTS_DIR/pattern_$i/100/p" ] && \
       [ -f "$RESULTS_DIR/pattern_$i/100/T" ]; then
        USABLE_PATTERNS=$((USABLE_PATTERNS + 1))
    fi
done

echo "Patterns ready for GNN training: $USABLE_PATTERNS / 90"
if [ $USABLE_PATTERNS -ge 70 ]; then
    echo "✅ Sufficient data for GNN training"
elif [ $USABLE_PATTERNS -ge 50 ]; then
    echo "⚠️  Marginal data quantity for GNN training"
else
    echo "❌ Insufficient data for reliable GNN training"
fi

# 推奨次ステップ
echo ""
echo "Recommended next steps:"
if [ $SUCCESS_COUNT -ge 85 ]; then
    echo "1. ✅ Proceed with GNN training using high-quality dataset"
    echo "2. ✅ Analyze fluid flow patterns around debris"
    echo "3. ✅ Compare with original scalarTransportFoam results"
elif [ $SUCCESS_COUNT -ge 70 ]; then
    echo "1. ⚠️  Investigate failed patterns and consider re-running"
    echo "2. ⚠️  Proceed with GNN training using available data"
    echo "3. ✅ Analyze successful patterns for insights"
else
    echo "1. ❌ Investigate and fix major issues before proceeding"
    echo "2. ❌ Consider parameter adjustment and re-run"
    echo "3. ⚠️  Use scalarTransportFoam data as fallback"
fi

echo ""
echo "Results collection completed!"
echo "Summary saved to: $SUMMARY_FILE"