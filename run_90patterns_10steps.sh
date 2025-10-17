#!/bin/bash

# 90パターン × 10ステップシミュレーション実行スクリプト
# 成功した10パターンの設定を使用

set -e

echo "=============================================="
echo "90パターン × 10ステップシミュレーション実行"
echo "設定: endTime=10, writeInterval=1 (11タイムステップ)"
echo "開始時刻: $(date)"
echo "=============================================="

# スリープ防止設定 (8時間)
echo "スリープ防止機能を開始..."
caffeinate -d -s -m -t 28800 &
CAFFEINATE_PID=$!
echo "スリープ防止PID: $CAFFEINATE_PID"

# 入力ディレクトリ（成功した10ステップの結果）
INPUT_DIR="simulation_results_10patterns_10steps_final"

# アウトプットディレクトリ作成
OUTPUT_DIR="simulation_results_90patterns_10steps"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
echo "結果保存先: $OUTPUT_DIR"

# ログディレクトリ作成
LOGS_DIR="logs_90patterns_10steps"
rm -rf "$LOGS_DIR"
mkdir -p "$LOGS_DIR"

# 失敗したパターンを記録
FAILED_PATTERNS=()
SUCCESS_COUNT=0
TOTAL_PATTERNS=90

# 実行関数
run_pattern() {
    local pattern=$1
    local source_pattern=$(printf "%02d" $((($pattern - 1) % 9 + 1)))  # 01-09をループ
    local pattern_dir="$INPUT_DIR/pattern_${source_pattern}"
    local work_dir="work_pattern_$(printf "%02d" $pattern)"
    local output_dir="$OUTPUT_DIR/pattern_$(printf "%02d" $pattern)"
    local log_file="$LOGS_DIR/pattern_$(printf "%02d" $pattern).log"
    
    echo ""
    echo "=========================================="
    echo "パターン$(printf "%02d" $pattern)実行開始: $(date)"
    echo "ソース: pattern_${source_pattern}"
    echo "=========================================="
    
    if [ ! -d "$pattern_dir" ]; then
        echo "❌ エラー: $pattern_dir が存在しません"
        FAILED_PATTERNS+=("$pattern")
        return 1
    fi
    
    # ログファイル初期化
    echo "=== パターン$(printf "%02d" $pattern) 10ステップシミュレーション実行ログ ===" > "$log_file"
    echo "開始時刻: $(date)" >> "$log_file"
    echo "ソースパターン: pattern_${source_pattern}" >> "$log_file"
    
    # 作業ディレクトリを作成（時間ステップを除外してコピー）
    echo "作業ディレクトリを準備中..."
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    
    # 時間ステップ以外のファイルをコピー（system, constant, run_openfoam.sh等）
    for item in "$pattern_dir"/*; do
        basename_item=$(basename "$item")
        if [[ ! "$basename_item" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            cp -r "$item" "$work_dir/"
        fi
    done
    
    # 初期条件（0ディレクトリ）をコピー
    if [ -d "$pattern_dir/0" ]; then
        cp -r "$pattern_dir/0" "$work_dir/0"
        echo "✓ 初期条件コピー完了"
    else
        echo "❌ 0ディレクトリが見つかりません"
        rm -rf "$work_dir"
        FAILED_PATTERNS+=("$pattern")
        return 1
    fi
    
    cd "$work_dir"
    
    # controlDictを10ステップに設定
    echo "controlDictを10ステップに設定中..."
    cat > system/controlDict <<EOF
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     simpleFoam;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         10;
deltaT          1;

writeControl    timeStep;
writeInterval   1;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// ************************************************************************* //
EOF
    echo "✓ controlDict設定完了"
    
    # run_openfoam.shが実行可能か確認
    if [ ! -x "run_openfoam.sh" ]; then
        chmod +x run_openfoam.sh
    fi
    
    # simpleFoam実行
    echo "simpleFoam実行中 (10ステップ)..."
    if timeout 1800 ./run_openfoam.sh simpleFoam >> "../$log_file" 2>&1; then
        echo "✓ simpleFoam完了"
        
        # タイムステップ数確認
        timesteps=$(find . -maxdepth 1 -type d -regex './[0-9]+\.?[0-9]*' | wc -l)
        generated_times=$(ls -d [0-9]* 2>/dev/null | sort -n | wc -l)
        echo "  生成されたタイムステップ数: $generated_times"
        
        # 期待通り11ステップ生成されたか確認
        if [ "$generated_times" -eq 11 ]; then
            echo "✓ 正常に11タイムステップ生成"
        else
            echo "⚠️ 予期しないタイムステップ数: $generated_times"
        fi
        
        # 結果を出力ディレクトリに保存
        echo "結果を保存中..."
        cd ..
        mv "$work_dir" "$output_dir"
        echo "✓ 結果保存完了"
        
        echo "完了時刻: $(date)" >> "$log_file"
        echo "パターン$(printf "%02d" $pattern)完了: $(date)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
    else
        echo "❌ simpleFoam失敗"
        echo "simpleFoam失敗: $(date)" >> "../$log_file"
        cd ..
        rm -rf "$work_dir"
        FAILED_PATTERNS+=("$pattern")
        return 1
    fi
    
    return 0
}

# パターン01-90を順次実行
echo "01-09の成功したパターンを90個にループ展開して実行"
echo ""

for pattern in $(seq 1 90); do
    run_pattern "$pattern"
    
    # 10パターンごとに詳細な進捗表示
    if [ $((pattern % 10)) -eq 0 ]; then
        echo ""
        echo "========== 進捗レポート =========="
        echo "- 完了パターン数: $SUCCESS_COUNT/$TOTAL_PATTERNS"
        echo "- 成功率: $(( SUCCESS_COUNT * 100 / pattern ))%"
        echo "- 失敗パターン数: ${#FAILED_PATTERNS[@]}"
        if [ ${#FAILED_PATTERNS[@]} -gt 0 ]; then
            echo "- 最近の失敗パターン: ${FAILED_PATTERNS[-1]}"
        fi
        echo "- 経過時間: $(date)"
        echo "=============================="
        echo ""
    else
        # 簡易進捗表示
        echo "進捗: $SUCCESS_COUNT/$TOTAL_PATTERNS ($(( SUCCESS_COUNT * 100 / pattern ))%)"
    fi
done

# 最終結果表示
echo ""
echo "=============================================="
echo "90パターンシミュレーション完了"
echo "完了時刻: $(date)"
echo "=============================================="

echo "成功: $SUCCESS_COUNT/$TOTAL_PATTERNS パターン"
echo "失敗: ${#FAILED_PATTERNS[@]}/$TOTAL_PATTERNS パターン"
echo "成功率: $(( SUCCESS_COUNT * 100 / TOTAL_PATTERNS ))%"

if [ ${#FAILED_PATTERNS[@]} -gt 0 ]; then
    echo ""
    echo "失敗パターン: ${FAILED_PATTERNS[*]}"
fi

echo ""
echo "結果保存先: $OUTPUT_DIR"
echo "ログ保存先: $LOGS_DIR"

# サンプル検証（最初と最後のパターン）
echo ""
echo "=== サンプル検証 ==="
for sample_pattern in 01 45 90; do
    if [ -d "$OUTPUT_DIR/pattern_$sample_pattern" ]; then
        cd "$OUTPUT_DIR/pattern_$sample_pattern"
        timesteps=$(ls -d [0-9]* 2>/dev/null | wc -l)
        times=$(ls -d [0-9]* 2>/dev/null | sort -n | tr '\n' ' ')
        echo "Pattern $sample_pattern: $timesteps ステップ [$times]"
        cd - >/dev/null
    else
        echo "Pattern $sample_pattern: ❌ 結果なし"
    fi
done

# ストレージ使用量確認
echo ""
echo "=== ストレージ使用量 ==="
du -sh "$OUTPUT_DIR" 2>/dev/null || echo "計算中..."
du -sh "$LOGS_DIR" 2>/dev/null || echo "計算中..."

# スリープ防止終了
if [ -n "$CAFFEINATE_PID" ]; then
    kill $CAFFEINATE_PID 2>/dev/null || true
    echo ""
    echo "スリープ防止終了"
fi

echo "=============================================="

# 成功率表示
if [ ${#FAILED_PATTERNS[@]} -eq 0 ]; then
    echo "🎉 全90パターン成功！"
    exit 0
elif [ $SUCCESS_COUNT -ge 63 ]; then  # 70%以上
    echo "⚠️  部分的成功 (70%以上): $SUCCESS_COUNT/$TOTAL_PATTERNS"
    exit 1
else
    echo "❌ 多数のパターンが失敗: $SUCCESS_COUNT/$TOTAL_PATTERNS"
    exit 2
fi