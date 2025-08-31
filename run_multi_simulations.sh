#!/bin/bash
# ========================================
# 5つの瓦礫パターンで個別シミュレーション実行
# ========================================

set -e

echo "================================================================"
echo "     OpenFOAM 5パターン瓦礫シミュレーション"
echo "     各瓦礫で個別に5秒シミュレーション実行"
echo "================================================================"

CURRENT_DIR="$(pwd)"
START_TIME=$(date +%s)
RESULTS_DIR="${CURRENT_DIR}/simulation_results"

# 結果保存ディレクトリ作成
mkdir -p "$RESULTS_DIR"

# ========================================
# 1. 瓦礫STLファイル生成
# ========================================
echo ""
echo "=== STEP 1: 5つの瓦礫3Dモデル生成 ==="

# 既存のSTLファイルをバックアップ
if ls disaster_debris_*.stl 2>/dev/null; then
    mkdir -p stl_backup_$(date +%Y%m%d_%H%M%S)
    mv disaster_debris_*.stl stl_backup_$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
fi

# 瓦礫生成（5つのバリエーション）
for i in {1..5}; do
    echo "  - disaster_debris_0${i}.stl 生成中..."
    # OUTPUT_FILENAMEを動的に変更
    sed -i.bak "s/OUTPUT_FILENAME = .*/OUTPUT_FILENAME = 'disaster_debris_0${i}.stl'/" disaster_debris_generator.py
    
    # 乱数シードも変更して異なるパターンを生成
    sed -i.bak "s/random.seed([0-9]*)/random.seed(${i}000)/" disaster_debris_generator.py
    sed -i.bak "s/np.random.seed([0-9]*)/np.random.seed(${i}000)/" disaster_debris_generator.py
    
    python3 disaster_debris_generator.py
done

# 元のファイル名に戻す
sed -i.bak "s/OUTPUT_FILENAME = .*/OUTPUT_FILENAME = 'disaster_debris_01.stl'/" disaster_debris_generator.py
rm disaster_debris_generator.py.bak

echo "✓ 5つの瓦礫モデル生成完了"

# ========================================
# 2. OpenFOAM基本設定（5秒シミュレーション）
# ========================================
echo ""
echo "=== STEP 2: OpenFOAM基本設定 ==="

# controlDictを5秒設定で作成
cat > debrisCase/system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     foamRun;

solvers
{
    default         incompressibleFluid;
}

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         5;
deltaT          0.001;
writeControl    timeStep;
writeInterval   500;  // 1秒ごとに保存（500 * 0.001 = 0.5秒）
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// ************************************************************************* //
EOF

echo "✓ 基本設定完了（5秒、0.5秒ごと保存）"

# ========================================
# 3. 各瓦礫パターンでシミュレーション実行
# ========================================
echo ""
echo "=== STEP 3: 5パターンの個別シミュレーション実行 ==="
echo ""

# 全体の進捗管理
TOTAL_PATTERNS=5
COMPLETED_PATTERNS=0

# 各瓦礫パターンでループ
for PATTERN in {1..5}; do
    echo "================================================================"
    echo "  パターン ${PATTERN}/5: disaster_debris_0${PATTERN}.stl"
    echo "================================================================"
    
    PATTERN_START=$(date +%s)
    PATTERN_DIR="${RESULTS_DIR}/pattern_${PATTERN}"
    
    # パターン用ディレクトリ作成
    echo "結果保存先: ${PATTERN_DIR}"
    mkdir -p "$PATTERN_DIR"
    
    # debrisCaseを作業ディレクトリにコピー
    echo "作業ディレクトリ準備中..."
    rm -rf "${PATTERN_DIR}/debrisCase"
    cp -r debrisCase "${PATTERN_DIR}/"
    
    # 対象のSTLファイルをdebris.stlとしてコピー
    cp "disaster_debris_0${PATTERN}.stl" "${PATTERN_DIR}/debrisCase/constant/triSurface/debris.stl"
    echo "✓ STLファイル配置完了"
    
    cd "${PATTERN_DIR}/debrisCase"
    
    # 既存の結果をクリーンアップ
    rm -rf [1-9]* processor* log.* *.log 0.* 2>/dev/null || true
    
    # メッシュ生成
    echo ""
    echo "メッシュ生成中..."
    docker run --platform linux/amd64 --rm \
        -v "${PATTERN_DIR}/debrisCase:/workspace" \
        -w /workspace \
        --entrypoint="" \
        openfoam/openfoam11-paraview510:latest \
        /bin/bash -c 'source /opt/openfoam11/etc/bashrc && blockMesh && snappyHexMesh -overwrite' > mesh_generation.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ メッシュ生成完了"
        CELL_COUNT=$(grep "nCells:" constant/polyMesh/owner 2>/dev/null | sed 's/.*nCells:\([0-9]*\).*/\1/')
        if [ -n "$CELL_COUNT" ]; then
            echo "  メッシュセル数: $CELL_COUNT"
        fi
    else
        echo "✗ メッシュ生成失敗（パターン${PATTERN}）"
        echo "スキップして次のパターンへ..."
        cd "$CURRENT_DIR"
        continue
    fi
    
    # 初期条件ファイル作成
    echo "初期条件設定中..."
    if [ ! -f "0/U" ]; then
        cat > 0/U << 'EOFU'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       volVectorField;
    object      U;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 1 -1 0 0 0 0];
internalField   uniform (0 0 0);

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform (0.5 0 0);
    }
    outlet
    {
        type            zeroGradient;
    }
    walls
    {
        type            noSlip;
    }
    ground
    {
        type            noSlip;
    }
    top
    {
        type            slip;
    }
    "debris.*"
    {
        type            noSlip;
    }
}
// ************************************************************************* //
EOFU
    fi
    
    if [ ! -f "0/p" ]; then
        cat > 0/p << 'EOFP'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    object      p;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 2 -2 0 0 0 0];
internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            zeroGradient;
    }
    outlet
    {
        type            fixedValue;
        value           uniform 0;
    }
    walls
    {
        type            zeroGradient;
    }
    ground
    {
        type            zeroGradient;
    }
    top
    {
        type            zeroGradient;
    }
    "debris.*"
    {
        type            zeroGradient;
    }
}
// ************************************************************************* //
EOFP
    fi
    
    # シミュレーション実行
    echo ""
    echo "シミュレーション実行中（パターン${PATTERN}）..."
    
    SIM_START=$(date +%s)
    
    # タイムアウト付きで実行（最大20分/パターン）
    timeout 1200 docker run --platform linux/amd64 --rm \
        -v "${PATTERN_DIR}/debrisCase:/workspace" \
        -w /workspace \
        --entrypoint="" \
        openfoam/openfoam11-paraview510:latest \
        /bin/bash -c 'source /opt/openfoam11/etc/bashrc && foamRun -solver incompressibleFluid' > simulation.log 2>&1 &
    
    PID=$!
    
    # プログレス表示
    echo -n "実行中 "
    LAST_TIME="0"
    while ps -p $PID > /dev/null 2>&1; do
        LATEST_TIME=$(ls -d [0-9]* 2>/dev/null | sort -n | tail -1)
        if [ -n "$LATEST_TIME" ] && [ "$LATEST_TIME" != "$LAST_TIME" ]; then
            echo -ne "\r実行中... 時刻: ${LATEST_TIME}/5.0秒 "
            LAST_TIME="$LATEST_TIME"
        fi
        sleep 2
    done
    
    wait $PID
    SIM_STATUS=$?
    
    SIM_END=$(date +%s)
    SIM_DURATION=$((SIM_END - SIM_START))
    
    echo ""
    if [ $SIM_STATUS -eq 0 ]; then
        echo "✓ シミュレーション完了（実行時間: ${SIM_DURATION}秒）"
        COMPLETED_PATTERNS=$((COMPLETED_PATTERNS + 1))
    elif [ $SIM_STATUS -eq 124 ]; then
        echo "✗ タイムアウト（20分）"
    else
        echo "✗ シミュレーション異常終了"
    fi
    
    # VTKファイル生成
    echo "VTKファイル生成中..."
    docker run --platform linux/amd64 --rm \
        -v "${PATTERN_DIR}/debrisCase:/workspace" \
        -w /workspace \
        --entrypoint="" \
        openfoam/openfoam11-paraview510:latest \
        /bin/bash -c 'source /opt/openfoam11/etc/bashrc && foamToVTK -latestTime' > vtk_generation.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ VTKファイル生成完了"
    fi
    
    # パターン完了時間
    PATTERN_END=$(date +%s)
    PATTERN_DURATION=$((PATTERN_END - PATTERN_START))
    
    echo ""
    echo "パターン${PATTERN} 完了（総時間: ${PATTERN_DURATION}秒）"
    echo ""
    
    cd "$CURRENT_DIR"
done

# ========================================
# 4. 結果サマリー生成
# ========================================
echo ""
echo "=== STEP 4: 結果サマリー生成 ==="

# サマリーファイル作成
SUMMARY_FILE="${RESULTS_DIR}/simulation_summary.txt"
cat > "$SUMMARY_FILE" << EOF
========================================
OpenFOAM 5パターン瓦礫シミュレーション結果
実行日時: $(date)
========================================

完了: ${COMPLETED_PATTERNS}/${TOTAL_PATTERNS} パターン

各パターンの結果:
EOF

for PATTERN in {1..5}; do
    echo "" >> "$SUMMARY_FILE"
    echo "パターン${PATTERN}: disaster_debris_0${PATTERN}.stl" >> "$SUMMARY_FILE"
    if [ -d "${RESULTS_DIR}/pattern_${PATTERN}/debrisCase" ]; then
        # 最終時刻確認
        FINAL_TIME=$(ls -d "${RESULTS_DIR}/pattern_${PATTERN}/debrisCase"/[0-9]* 2>/dev/null | sort -n | tail -1 | xargs basename)
        if [ -n "$FINAL_TIME" ]; then
            echo "  - 最終時刻: ${FINAL_TIME}秒" >> "$SUMMARY_FILE"
            echo "  - 結果: ${RESULTS_DIR}/pattern_${PATTERN}/debrisCase/" >> "$SUMMARY_FILE"
        else
            echo "  - 結果: 実行失敗" >> "$SUMMARY_FILE"
        fi
    else
        echo "  - 結果: 未実行" >> "$SUMMARY_FILE"
    fi
done

echo "✓ サマリー作成完了: $SUMMARY_FILE"
cat "$SUMMARY_FILE"

# ========================================
# 5. Web可視化の準備
# ========================================
echo ""
echo "=== STEP 5: Web可視化の準備 ==="

# 結果比較用HTMLファイル生成
COMPARISON_HTML="${RESULTS_DIR}/comparison_viewer.html"
cat > "$COMPARISON_HTML" << 'EOFHTML'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>5パターン瓦礫シミュレーション結果比較</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #f0f0f0;
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        .pattern-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .pattern-card {
            background: white;
            border-radius: 8px;
            padding: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .pattern-card h3 {
            margin-top: 0;
            color: #4CAF50;
        }
        .view-button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin-top: 10px;
        }
        .view-button:hover {
            background: #45a049;
        }
        .status-success {
            color: green;
        }
        .status-failed {
            color: red;
        }
    </style>
</head>
<body>
    <h1>5パターン瓦礫シミュレーション結果比較</h1>
    
    <div class="pattern-grid">
EOFHTML

# 各パターンのカード追加
for PATTERN in {1..5}; do
    echo "        <div class=\"pattern-card\">" >> "$COMPARISON_HTML"
    echo "            <h3>パターン ${PATTERN}</h3>" >> "$COMPARISON_HTML"
    echo "            <p><strong>STLファイル:</strong> disaster_debris_0${PATTERN}.stl</p>" >> "$COMPARISON_HTML"
    
    if [ -d "${RESULTS_DIR}/pattern_${PATTERN}/debrisCase/VTK" ]; then
        echo "            <p class=\"status-success\">✓ シミュレーション完了</p>" >> "$COMPARISON_HTML"
        echo "            <button class=\"view-button\" onclick=\"window.open('file://${RESULTS_DIR}/pattern_${PATTERN}/debrisCase/VTK')\">VTKファイルを開く</button>" >> "$COMPARISON_HTML"
    else
        echo "            <p class=\"status-failed\">✗ 結果なし</p>" >> "$COMPARISON_HTML"
    fi
    
    echo "        </div>" >> "$COMPARISON_HTML"
done

cat >> "$COMPARISON_HTML" << 'EOFHTML'
    </div>
    
    <div style="margin-top: 40px; padding: 20px; background: white; border-radius: 8px;">
        <h2>可視化方法</h2>
        <ol>
            <li>メインのWebビューア（openfoam_web_viewer.html）を開く</li>
            <li>各パターンのVTKファイルをドラッグ&ドロップ</li>
            <li>流速（U）や圧力（p）を選択して表示</li>
            <li>複数のブラウザタブで異なるパターンを比較</li>
        </ol>
    </div>
</body>
</html>
EOFHTML

echo "✓ 比較ビューア作成完了: $COMPARISON_HTML"

# メインのWebビューアを開く
WEB_VIEWER="/Users/takeuchidaiki/research/stepB_project/openfoam_web_viewer.html"
if [ -f "$WEB_VIEWER" ]; then
    echo ""
    echo "Webビューアを開いています..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$WEB_VIEWER"
        open "$COMPARISON_HTML"
        echo "✓ ビューアを開きました"
    fi
fi

# ========================================
# 完了サマリー
# ========================================
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "================================================================"
echo "     完了サマリー"
echo "================================================================"
echo "✓ 実行パターン: ${COMPLETED_PATTERNS}/${TOTAL_PATTERNS} 完了"
echo "✓ 総実行時間: ${TOTAL_DURATION}秒（$(($TOTAL_DURATION / 60))分）"
echo ""
echo "結果ファイル:"
echo "  - 各パターン結果: ${RESULTS_DIR}/pattern_[1-5]/"
echo "  - サマリー: ${SUMMARY_FILE}"
echo "  - 比較ビューア: ${COMPARISON_HTML}"
echo ""
echo "次のステップ:"
echo "  1. 比較ビューアで各パターンの概要確認"
echo "  2. Webビューアで詳細な3D可視化"
echo "  3. ParaViewでより高度な解析"
echo "================================================================"