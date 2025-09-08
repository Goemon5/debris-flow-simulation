#!/bin/bash

# =============================================================================
# Docker環境でOpenFOAMシミュレーションを実行するラッパースクリプト
# =============================================================================

set -e

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# コンテナ名とイメージ名
CONTAINER_NAME="stepa_project"
IMAGE_NAME="openfoam-cfd:latest"
WORK_DIR="/work"

echo -e "${BLUE}===========================================
OpenFOAM Docker シミュレーション実行スクリプト
===========================================${NC}"

# 1. Dockerが起動しているか確認
echo -e "\n${YELLOW}[1/5] Docker状態確認${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Dockerが起動していません。Dockerを起動してください。${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker起動確認済み${NC}"

# 2. 既存のコンテナを確認
echo -e "\n${YELLOW}[2/5] 既存コンテナ確認${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "既存のコンテナ ${CONTAINER_NAME} を削除中..."
    docker rm -f ${CONTAINER_NAME}
fi
echo -e "${GREEN}✓ コンテナ準備完了${NC}"

# 3. 新しいコンテナを起動
echo -e "\n${YELLOW}[3/5] OpenFOAMコンテナ起動${NC}"
echo "作業ディレクトリ: $(pwd)"
docker run -dit \
    --name ${CONTAINER_NAME} \
    -v $(pwd):${WORK_DIR} \
    -w ${WORK_DIR} \
    ${IMAGE_NAME} \
    /bin/bash

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ コンテナ起動成功${NC}"
else
    echo -e "${RED}❌ コンテナ起動失敗${NC}"
    exit 1
fi

# 4. シミュレーションの実行方法を選択
echo -e "\n${YELLOW}[4/5] 実行モード選択${NC}"
echo "1) テストシミュレーション (pattern_01のみ、3ケース)"
echo "2) 全パターンシミュレーション (全40パターン)"
echo "3) コンテナにログインしてマニュアル実行"
read -p "選択してください (1-3): " choice

case $choice in
    1)
        echo -e "\n${BLUE}テストシミュレーション開始...${NC}"
        echo "ログファイル: test_pattern_01_*.log"
        echo ""
        
        # シミュレーション実行
        docker exec -it ${CONTAINER_NAME} bash -c "
            source /opt/openfoam11/etc/bashrc
            cd ${WORK_DIR}
            ./test_single_odor_simulation.sh
        "
        
        # ログ表示
        echo -e "\n${YELLOW}[5/5] 実行ログ確認${NC}"
        echo "生成されたログファイル:"
        ls -la test_pattern_01_*.log 2>/dev/null || echo "ログファイルが見つかりません"
        ;;
        
    2)
        echo -e "\n${BLUE}全パターンシミュレーション開始...${NC}"
        echo "⚠️  この処理は時間がかかります (40パターン × 3位置 = 120ケース)"
        read -p "続行しますか？ (y/n): " confirm
        
        if [[ $confirm == "y" ]]; then
            docker exec -it ${CONTAINER_NAME} bash -c "
                source /opt/openfoam11/etc/bashrc
                cd ${WORK_DIR}
                ./run_all_odor_simulations.sh
            "
        else
            echo "キャンセルしました"
        fi
        ;;
        
    3)
        echo -e "\n${BLUE}コンテナにログインします...${NC}"
        echo "終了するには 'exit' と入力してください"
        echo ""
        docker exec -it ${CONTAINER_NAME} bash -c "
            source /opt/openfoam11/etc/bashrc
            cd ${WORK_DIR}
            echo '======================================'
            echo 'OpenFOAM環境にログインしました'
            echo '作業ディレクトリ: ${WORK_DIR}'
            echo ''
            echo '利用可能なコマンド:'
            echo '  blockMesh    : メッシュ生成'
            echo '  snappyHexMesh: 複雑形状メッシュ生成'
            echo '  simpleFoam   : 定常流れ解析'
            echo '  foamRun      : 汎用ソルバー実行'
            echo '  paraFoam     : 可視化（要X11）'
            echo ''
            echo 'シミュレーション実行:'
            echo '  ./test_single_odor_simulation.sh'
            echo '  ./run_all_odor_simulations.sh'
            echo '======================================'
            exec bash
        "
        ;;
        
    *)
        echo -e "${RED}無効な選択です${NC}"
        exit 1
        ;;
esac

# クリーンアップオプション
echo -e "\n${YELLOW}コンテナをクリーンアップしますか？${NC}"
read -p "コンテナを削除する場合は 'y' を入力: " cleanup

if [[ $cleanup == "y" ]]; then
    docker rm -f ${CONTAINER_NAME}
    echo -e "${GREEN}✓ コンテナを削除しました${NC}"
else
    echo -e "${BLUE}コンテナ ${CONTAINER_NAME} は実行中です${NC}"
    echo "後で削除する場合: docker rm -f ${CONTAINER_NAME}"
fi

echo -e "\n${GREEN}===========================================
処理完了
===========================================${NC}"