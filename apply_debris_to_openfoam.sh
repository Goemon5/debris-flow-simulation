#!/bin/bash
# STLファイルをOpenFOAM環境に適用するスクリプト

set -e  # エラー時に停止

echo "================================================"
echo "STLファイルをOpenFOAM環境に適用中..."
echo "================================================"

# デフォルトのSTLファイル名
STL_FILE="${1:-disaster_debris_01.stl}"

# ファイルの存在確認
if [ ! -f "$STL_FILE" ]; then
    echo "✗ エラー: $STL_FILE が見つかりません"
    exit 1
fi

# OpenFOAMケースディレクトリ
CASE_DIR="debrisCase"
TRISURFACE_DIR="$CASE_DIR/constant/triSurface"

# ディレクトリ作成（存在しない場合）
if [ ! -d "$TRISURFACE_DIR" ]; then
    echo "ディレクトリを作成: $TRISURFACE_DIR"
    mkdir -p "$TRISURFACE_DIR"
fi

# 既存のdebris.stlをバックアップ
if [ -f "$TRISURFACE_DIR/debris.stl" ]; then
    BACKUP_FILE="$TRISURFACE_DIR/debris_backup_$(date +%Y%m%d_%H%M%S).stl"
    echo "既存ファイルをバックアップ: $BACKUP_FILE"
    cp "$TRISURFACE_DIR/debris.stl" "$BACKUP_FILE"
fi

# STLファイルをコピー
echo "STLファイルをコピー中: $STL_FILE → $TRISURFACE_DIR/debris.stl"
cp "$STL_FILE" "$TRISURFACE_DIR/debris.stl"

# ファイルサイズを確認
FILE_SIZE=$(du -h "$TRISURFACE_DIR/debris.stl" | cut -f1)
echo "✓ STLファイル適用完了 (サイズ: $FILE_SIZE)"

# メッシュ関連ファイルのクリーンアップ（オプション）
if [ "$2" = "--clean-mesh" ]; then
    echo "既存メッシュをクリーンアップ中..."
    if [ -d "$CASE_DIR/constant/polyMesh" ]; then
        # blockMeshで生成される基本メッシュファイル以外を削除
        find "$CASE_DIR/constant/polyMesh" -type f ! -name "blockMeshDict" -delete 2>/dev/null || true
    fi
    # snappyHexMeshの出力ディレクトリを削除
    rm -rf "$CASE_DIR"/[0-9]* 2>/dev/null || true
    echo "✓ メッシュクリーンアップ完了"
fi

echo ""
echo "================================================"
echo "✓ OpenFOAM環境への適用が完了しました"
echo "  次のステップ: cd $CASE_DIR && ./run.sh"
echo "================================================"