#!/bin/bash
# 瓦礫パターン1の生成からシミュレーションまで一括実行スクリプト

set -e  # エラー時に停止

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}     瓦礫パターン1 統合シミュレーション実行スクリプト${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# タイムスタンプ
START_TIME=$(date +%s)
echo "開始時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ========================================
# Phase 1: 瓦礫生成
# ========================================
echo -e "${YELLOW}[Phase 1/4] 瓦礫パターン1を生成${NC}"
echo "----------------------------------------"

python3 generate_debris_pattern1.py
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 瓦礫生成に失敗しました${NC}"
    exit 1
fi

# 生成されたファイルの確認
if [ ! -f "disaster_debris_01.stl" ]; then
    echo -e "${RED}✗ STLファイルが生成されませんでした${NC}"
    exit 1
fi

FILE_SIZE=$(du -h disaster_debris_01.stl | cut -f1)
echo -e "${GREEN}✓ 瓦礫生成完了${NC} (disaster_debris_01.stl: $FILE_SIZE)"
echo ""

# ========================================
# Phase 2: OpenFOAM環境への適用
# ========================================
echo -e "${YELLOW}[Phase 2/4] OpenFOAM環境にSTLファイルを適用${NC}"
echo "----------------------------------------"

# 実行権限を付与
chmod +x apply_debris_to_openfoam.sh

# メッシュをクリーンアップしてSTLを適用
./apply_debris_to_openfoam.sh disaster_debris_01.stl --clean-mesh
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ STLファイルの適用に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ STLファイル適用完了${NC}"
echo ""

# ========================================
# Phase 3: OpenFOAMシミュレーション実行
# ========================================
echo -e "${YELLOW}[Phase 3/4] OpenFOAMシミュレーション実行${NC}"
echo "----------------------------------------"

# 実行権限を付与
chmod +x run_openfoam_simulation.sh

./run_openfoam_simulation.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ シミュレーション実行に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ シミュレーション完了${NC}"
echo ""

# ========================================
# Phase 4: 結果の可視化（オプション）
# ========================================
echo -e "${YELLOW}[Phase 4/4] 結果の確認${NC}"
echo "----------------------------------------"

# 結果ファイルの存在確認
if [ -d "debrisCase/1000" ]; then
    echo -e "${GREEN}✓ シミュレーション結果が正常に生成されました${NC}"
    
    # 結果ファイルのリスト
    echo ""
    echo "生成された主要ファイル:"
    echo "  - debrisCase/case.foam (ParaView用)"
    echo "  - debrisCase/1000/U (速度場)"
    echo "  - debrisCase/1000/p (圧力場)"
    echo "  - debrisCase/1000/s (スカラー濃度場)"
    
    # Pythonによる可視化（オプション）
    if [ -f "visualize_results.py" ]; then
        echo ""
        read -p "結果を可視化しますか？ [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            python3 visualize_results.py
        fi
    fi
else
    echo -e "${YELLOW}⚠ シミュレーション結果ディレクトリが見つかりません${NC}"
fi

# ========================================
# 完了
# ========================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}✓ すべての処理が正常に完了しました${NC}"
echo ""
echo "実行時間: ${ELAPSED_MIN}分${ELAPSED_SEC}秒"
echo "完了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "  1. ParaViewで結果を確認:"
echo "     paraview debrisCase/case.foam"
echo ""
echo "  2. Pythonで結果を可視化:"
echo "     python3 visualize_results.py"
echo ""
echo "  3. Webビューアで確認:"
echo "     python3 start_viewer.py"
echo -e "${BLUE}================================================================${NC}"