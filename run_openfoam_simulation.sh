#!/bin/bash
# OpenFOAMシミュレーション実行スクリプト

set -e  # エラー時に停止

echo "================================================"
echo "OpenFOAMシミュレーションを実行中..."
echo "================================================"

# ケースディレクトリに移動
CASE_DIR="debrisCase"
ORIGINAL_DIR=$(pwd)

if [ ! -d "$CASE_DIR" ]; then
    echo "✗ エラー: $CASE_DIR ディレクトリが見つかりません"
    exit 1
fi

cd "$CASE_DIR"

# STLファイルの確認
if [ ! -f "constant/triSurface/debris.stl" ]; then
    echo "✗ エラー: debris.stlファイルが見つかりません"
    echo "  先に apply_debris_to_openfoam.sh を実行してください"
    cd "$ORIGINAL_DIR"
    exit 1
fi

# シミュレーション実行
echo ""
echo "Step 1/5: blockMesh - 背景メッシュ生成..."
echo "----------------------------------------"
blockMesh > log.blockMesh 2>&1
if [ $? -eq 0 ]; then
    echo "✓ blockMesh 完了"
else
    echo "✗ blockMesh 失敗 (詳細: log.blockMesh)"
    cd "$ORIGINAL_DIR"
    exit 1
fi

echo ""
echo "Step 2/5: surfaceFeatureExtract - 表面特徴抽出..."
echo "----------------------------------------"
surfaceFeatureExtract > log.surfaceFeatureExtract 2>&1
if [ $? -eq 0 ]; then
    echo "✓ surfaceFeatureExtract 完了"
else
    echo "✗ surfaceFeatureExtract 失敗 (詳細: log.surfaceFeatureExtract)"
    cd "$ORIGINAL_DIR"
    exit 1
fi

echo ""
echo "Step 3/5: snappyHexMesh - 瓦礫周りメッシュ生成..."
echo "----------------------------------------"
snappyHexMesh -overwrite > log.snappyHexMesh 2>&1
if [ $? -eq 0 ]; then
    CELL_COUNT=$(grep -E "cells:" log.snappyHexMesh | tail -1 | awk '{print $2}')
    echo "✓ snappyHexMesh 完了 (セル数: $CELL_COUNT)"
else
    echo "✗ snappyHexMesh 失敗 (詳細: log.snappyHexMesh)"
    cd "$ORIGINAL_DIR"
    exit 1
fi

echo ""
echo "Step 4/5: simpleFoam - 流体・拡散シミュレーション..."
echo "----------------------------------------"
echo "  これには数分かかる場合があります..."

# 収束状況を監視しながら実行
simpleFoam > log.simpleFoam 2>&1 &
FOAM_PID=$!

# プログレス表示
while kill -0 $FOAM_PID 2>/dev/null; do
    if [ -f "log.simpleFoam" ]; then
        CURRENT_TIME=$(grep "^Time =" log.simpleFoam 2>/dev/null | tail -1 | awk '{print $3}' || echo "0")
        if [ ! -z "$CURRENT_TIME" ]; then
            echo -ne "\r  時間ステップ: $CURRENT_TIME / 1000"
        fi
    fi
    sleep 2
done
echo ""

wait $FOAM_PID
FOAM_EXIT=$?

if [ $FOAM_EXIT -eq 0 ]; then
    FINAL_TIME=$(grep "^Time =" log.simpleFoam | tail -1 | awk '{print $3}')
    echo "✓ simpleFoam 完了 (最終時刻: $FINAL_TIME)"
else
    echo "✗ simpleFoam 失敗 (詳細: log.simpleFoam)"
    cd "$ORIGINAL_DIR"
    exit 1
fi

echo ""
echo "Step 5/5: 後処理..."
echo "----------------------------------------"
# ParaView用ファイル作成
touch case.foam
echo "✓ case.foam ファイル作成完了"

# 結果の簡易統計
if [ -d "1000" ]; then
    echo ""
    echo "シミュレーション結果統計:"
    echo "------------------------"
    if [ -f "1000/s" ]; then
        MAX_CONC=$(grep -oE "[0-9]+\.[0-9]+e[+-][0-9]+" 1000/s 2>/dev/null | sort -g | tail -1 || echo "N/A")
        echo "  最大濃度: $MAX_CONC"
    fi
fi

cd "$ORIGINAL_DIR"

echo ""
echo "================================================"
echo "✓ OpenFOAMシミュレーションが正常に完了しました"
echo ""
echo "結果の可視化:"
echo "  1. ParaView: paraview $CASE_DIR/case.foam"
echo "  2. Python: python visualize_results.py"
echo "================================================"