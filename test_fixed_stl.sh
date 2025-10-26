#!/bin/bash
# 修正版STLファイルのテストスクリプト
PATTERN=01
STL_FILE="debris_pattern_${PATTERN}.stl"
WORK_DIR="test_fixed_stl_pattern_${PATTERN}"

echo "=== 修正版STLファイルのテスト ===｜"
echo "パターン: ${PATTERN}"
echo "STLファイル: ${STL_FILE}"

# 作業ディレクトリ準備
rm -rf "$WORK_DIR"
cp -r final_debris_01 "$WORK_DIR"
echo "✓ テンプレートコピー完了"

# 修正版STLファイルを配置
mkdir -p "$WORK_DIR/constant/triSurface"
cp "$STL_FILE" "$WORK_DIR/constant/triSurface/debris.stl"
echo "✓ 修正版STLファイル配置完了"

# STLファイル確認
echo "--- STLファイル情報 ---"
ls -la "$WORK_DIR/constant/triSurface/debris.stl"
head -5 "$STL_FILE"

# Docker実行（snappyHexMeshのみ）
echo "--- snappyHexMeshテスト実行 ---"
cd "$WORK_DIR"
timeout 120 docker run --rm -v "$(pwd):/work" -w /work openfoam-cfd:latest /bin/bash -c "
  blockMesh
  snappyHexMesh -overwrite
" > "../test_snappy_output.log" 2>&1

if [ $? -eq 0 ]; then
  echo "✓ snappyHexMesh成功"
  # intersection確認
  echo "--- intersection結果確認 ---"
  grep -A2 -B2 \"intersected edges\" "../test_snappy_output.log" | tail -10
else
  echo "❌ snappyHexMeshでエラー"
  tail -20 "../test_snappy_output.log"
fi
