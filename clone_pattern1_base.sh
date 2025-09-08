#!/bin/bash

# パターン1をベースにして他のパターンを作成

echo "================================================================"
echo "  パターン1ベースでのパターン2-5作成"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"

PROJECT_DIR="/Users/takeuchidaiki/research/stepB_project"
cd "$PROJECT_DIR"

# 成功したパターン1をベースとして使用
BASE_DIR="$PROJECT_DIR/simulation_results/pattern_1/debrisCase"

for i in {2..5}; do
    echo "=== パターン$i 作成開始 ==="
    
    TARGET_DIR="$PROJECT_DIR/simulation_results/pattern_$i/debrisCase"
    
    # 既存ディレクトリを削除
    rm -rf "$TARGET_DIR"
    
    # パターン1をそのまま複製
    cp -r "$BASE_DIR" "$TARGET_DIR"
    
    echo "✓ パターン1の設定をコピー完了"
    
    # 時刻ディレクトリを0だけ残してクリーンアップ
    cd "$TARGET_DIR"
    find . -maxdepth 1 -type d -regex './[0-9.]+' ! -name '0' -exec rm -rf {} \; 2>/dev/null || true
    rm -rf VTK postProcessing processor* *.csv *.log case.foam 2>/dev/null || true
    
    # STLファイルを差し替え
    rm -f "constant/triSurface/"*.stl
    cp "$PROJECT_DIR/three_blocks_0${i}.stl" "constant/triSurface/"
    
    echo "✓ STLファイル差し替え完了: three_blocks_0${i}.stl"
    
    # controlDictをリセット（0秒から開始）
    sed -i.bak 's/startTime.*/startTime       0;/' system/controlDict
    sed -i.bak 's/endTime.*/endTime         5;/' system/controlDict
    
    # メッシュ再生成が必要なのでpolyMeshを削除
    rm -rf constant/polyMesh
    
    echo "✓ パターン$i 準備完了"
    
    cd "$PROJECT_DIR"
done

echo ""
echo "================================================================"
echo "  全パターンの準備完了"
echo "================================================================"

# 各パターンの設定確認
for i in {2..5}; do
    TARGET_DIR="$PROJECT_DIR/simulation_results/pattern_$i/debrisCase"
    STL_FILE=$(ls "$TARGET_DIR/constant/triSurface/"*.stl 2>/dev/null | head -1)
    echo "パターン$i: STL=$(basename "$STL_FILE"), メッシュ=$(ls -d "$TARGET_DIR/constant/polyMesh" 2>/dev/null && echo "存在" || echo "未生成")"
done