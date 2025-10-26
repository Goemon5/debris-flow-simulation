#!/bin/bash

# ===============================================================================
# Pattern Template Setup Script
# Patterns 4以降用の効率的なセットアップスクリプト
# ===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 引数チェック
if [ $# -ne 2 ]; then
    echo -e "${RED}Usage: $0 <pattern_number> <stl_filename>${NC}"
    echo "Example: $0 04 debris_pattern_04_transformed.stl"
    exit 1
fi

PATTERN_NUM=$1
STL_FILE=$2
TARGET_DIR="pattern_${PATTERN_NUM}_test"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}Pattern ${PATTERN_NUM} Setup (Template Based)${NC}"
echo -e "${BLUE}===============================================${NC}"

# 作業ディレクトリ作成
echo -e "${YELLOW}Creating ${TARGET_DIR}...${NC}"
mkdir -p ${TARGET_DIR}
cd ${TARGET_DIR}

# 基本ディレクトリ構造作成
mkdir -p {0,constant/{geometry,polyMesh},system,logs}

# STLファイルコピー
echo -e "${YELLOW}Copying STL file...${NC}"
cp ../${STL_FILE} constant/geometry/debris.stl

# 実証済み設定ファイルをコピー (pattern_01_complete_testから)
echo -e "${YELLOW}Copying proven configuration files...${NC}"

# OpenFOAMスクリプト
cp ../pattern_01_complete_test/run_openfoam.sh .
cp ../pattern_01_complete_test/setup_flow_simulation.sh .
cp ../pattern_01_complete_test/setup_scent_simulation.sh .

# System設定 (実証済み)
cp ../pattern_01_complete_test/system/blockMeshDict system/
cp ../pattern_01_complete_test/system/snappyHexMeshDict system/  # eMesh参照なし版
cp ../pattern_01_complete_test/system/controlDict system/
cp ../pattern_01_complete_test/system/fvSchemes system/
cp ../pattern_01_complete_test/system/fvSolution system/

# Constant設定 (viscosityModel含む)
cp ../pattern_01_complete_test/constant/physicalProperties constant/

# 境界条件 (zeroGradient使用版)
cp ../pattern_01_complete_test/0/U 0/
cp ../pattern_01_complete_test/0/p 0/

echo -e "${GREEN}✓ Pattern ${PATTERN_NUM} setup completed${NC}"
echo -e "${GREEN}✓ All proven configurations copied${NC}"

echo ""
echo -e "${YELLOW}Ready to run workflow:${NC}"
echo "  1. ./run_openfoam.sh blockMesh"
echo "  2. ./run_openfoam.sh snappyHexMesh -overwrite"
echo "  3. ./setup_flow_simulation.sh"
echo "  4. ./run_openfoam.sh simpleFoam"

echo ""
echo -e "${GREEN}Configuration source: pattern_01_complete_test (proven stable)${NC}"