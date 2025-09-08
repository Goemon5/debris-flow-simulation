#!/bin/bash

# =============================================================================
# Docker環境でOpenFOAMシミュレーションを確実に実行するスクリプト
# =============================================================================

echo "OpenFOAMシミュレーション実行準備"

# コンテナ再起動
docker rm -f stepa_project 2>/dev/null
docker run -dit --name stepa_project -v $(pwd):/work -w /work opencfd/openfoam-default:2406 /bin/bash

# スクリプト実行
docker exec stepa_project bash -c "
    source /usr/lib/openfoam/openfoam2406/etc/bashrc
    cd /work
    rm -rf test_odor_results
    ./test_single_odor_simulation.sh
"

echo "完了！ログファイルを確認してください："
echo "  tail -f test_pattern_01_center.log"
echo "  tail -f test_pattern_01_upwind.log"
echo "  tail -f test_pattern_01_side.log"