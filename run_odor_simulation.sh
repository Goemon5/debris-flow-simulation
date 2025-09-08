#!/bin/bash

# =============================================================================
# OpenFOAM匂い拡散シミュレーション実行スクリプト（修正版）
# Docker環境で実行
# =============================================================================

# OpenFOAM環境設定
if [ -f /opt/openfoam11/etc/bashrc ]; then
    source /opt/openfoam11/etc/bashrc
fi

set -e  # エラー時に停止

# 設定
BASE_DIR="simulation_results_gnn"
OUTPUT_DIR="odor_simulation_results"
PATTERNS=${1:-$(seq 1 40)}  # デフォルトは全40パターン

# 3つの匂い源位置
ODOR_SOURCES=(
    "7.5 7.5 0.5"   # 源1: 瓦礫中心部（低い位置）
    "5.0 7.5 1.0"   # 源2: 瓦礫風上側（中間高さ）
    "7.5 5.0 1.5"   # 源3: 瓦礫側面部（高い位置）
)

SOURCE_NAMES=("center" "upwind" "side")

# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

echo "==========================================="
echo "匂い拡散シミュレーション開始"
echo "対象パターン: $PATTERNS"
echo "匂い源位置: ${#ODOR_SOURCES[@]}箇所"
echo "==========================================="

# スカラー輸送設定関数
setup_scalar_transport() {
    local source_coords=$1
    local x_pos=$(echo $source_coords | cut -d' ' -f1)
    local y_pos=$(echo $source_coords | cut -d' ' -f2)
    local z_pos=$(echo $source_coords | cut -d' ' -f3)
    
    echo "  → 匂い源座標設定: ($x_pos, $y_pos, $z_pos)"
    
    # 1. controlDict修正（scalarTransport追加）
    if ! grep -q "scalarTransport" system/controlDict; then
        sed -i.bak '/default.*incompressibleFluid/a\
    C               scalarTransport;' system/controlDict
        echo "    ✓ controlDict修正完了"
    fi
    
    # 2. controlDictのwriteControl修正（endTimeはOpenFOAM11では無効）
    if grep -q "writeControl.*endTime" system/controlDict; then
        sed -i 's/writeControl.*endTime/writeControl    timeStep/' system/controlDict
        sed -i 's/writeInterval.*1/writeInterval   5000/' system/controlDict
    fi
    
    # 3. functionsセクションの修正
    if grep -q "utilityFunctionObjects)" system/controlDict; then
        sed -i 's/(utilityFunctionObjects)/("libutilityFunctionObjects.so")/' system/controlDict
    fi
    
    # 4. scalarTransportProperties作成
    cat > constant/scalarTransportProperties << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      scalarTransportProperties;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

DT              2.0e-05;  // [m^2/s] 分子拡散係数
Sct             0.7;      // 乱流Schmidt数

// ************************************************************************* //
EOF
    echo "    ✓ scalarTransportProperties作成完了"
    
    # 5. 初期条件ファイル 0/C 作成
    cat > 0/C << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    object      C;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 0 0 0 0 0 0];

internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform 0;
    }
    outlet
    {
        type            zeroGradient;
    }
    ground
    {
        type            zeroGradient;
    }
    atmosphere
    {
        type            zeroGradient;
    }
    ".*"
    {
        type            zeroGradient;
    }
}

// ************************************************************************* //
EOF
    echo "    ✓ 初期条件ファイル 0/C 作成完了"
    
    # 6. fvModels（匂い源）設定
    cat > system/fvModels << EOF
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      fvModels;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

odorSource
{
    type            scalarCodedSource;
    selectionMode   all;
    field           C;

    name    odorSource;

    codeAddSup
    #{
        const vector sourcePos($x_pos, $y_pos, $z_pos);
        const scalar sourceRadius = 0.3;
        const scalar sourceStrength = 1.0;
        
        const volVectorField& cellCentres = mesh().C();
        scalarField& source = eqn.source();
        
        forAll(cellCentres, cellI)
        {
            scalar dist = mag(cellCentres[cellI] - sourcePos);
            if (dist < sourceRadius)
            {
                source[cellI] += sourceStrength * mesh().V()[cellI];
            }
        }
    #};
}

// ************************************************************************* //
EOF
    echo "    ✓ fvModels（匂い源）設定完了"
    
    # 7. fvSchemes修正
    if ! grep -q "div(phi,C)" system/fvSchemes; then
        sed -i.bak '/divSchemes/,/^}/s/}/    div(phi,C)      Gauss linearUpwind grad(C);\n}/' system/fvSchemes
        echo "    ✓ fvSchemes修正完了"
    fi
    
    # 8. fvSolution修正
    if ! grep -q '"C"' system/fvSolution; then
        sed -i.bak '/solvers/,/^}/s/}/    "C"\n    {\n        solver          PBiCGStab;\n        preconditioner  DILU;\n        tolerance       1e-06;\n        relTol          0;\n    }\n}/' system/fvSolution
        
        # SIMPLE制御に追加
        sed -i.bak '/residualControl/,/}/s/}/        C               0.0001;\n    }/' system/fvSolution
        echo "    ✓ fvSolution修正完了"
    fi
    
    echo "  → 全設定ファイル準備完了"
}

# 各パターンを処理
for pattern_num in $PATTERNS; do
    pattern_name=$(printf "pattern_%02d" $pattern_num)
    base_case="$BASE_DIR/$pattern_name/debrisCase_gnn"
    
    # ベースケースの存在確認
    if [[ ! -d "$base_case" ]]; then
        echo "⚠️  スキップ: $base_case が見つかりません"
        continue
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "パターン $pattern_num 処理開始"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 各匂い源位置で実行
    for source_idx in "${!ODOR_SOURCES[@]}"; do
        source_pos="${ODOR_SOURCES[$source_idx]}"
        source_name="${SOURCE_NAMES[$source_idx]}"
        source_case_name="${pattern_name}_${source_name}"
        target_case="$OUTPUT_DIR/$source_case_name"
        
        echo ""
        echo "-------------------------------------------"
        echo "[$((source_idx + 1))/3] 処理中: $source_case_name"
        echo "匂い源: $source_name ($source_pos)"
        echo "-------------------------------------------"
        
        # ケースディレクトリ準備
        if [[ -d "$target_case" ]]; then
            echo "既存ケース削除中..."
            rm -rf "$target_case"
        fi
        
        echo "ベースケースをコピー中..."
        cp -r "$base_case" "$target_case"
        
        # 乱流モデル用初期条件ファイルをコピー
        echo "  → 乱流モデル用ファイルをコピー中..."
        if [[ -f "debrisCase/0/nut" ]]; then
            cp debrisCase/0/nut "$target_case/0/"
            cp debrisCase/0/k "$target_case/0/"
            cp debrisCase/0/epsilon "$target_case/0/"
        fi
        
        cd "$target_case"
        
        # スカラー輸送設定
        echo "スカラー輸送設定中..."
        setup_scalar_transport "$source_pos"
        
        # シミュレーション実行
        echo ""
        echo "🚀 シミュレーション実行開始"
        echo "ログファイル: ../../odor_sim_${source_case_name}.log"
        
        local_log="../../odor_sim_${source_case_name}.log"
        
        # メッシュ確認・生成
        if [[ ! -d "constant/polyMesh" || $(ls constant/polyMesh/ | wc -l) -lt 10 ]]; then
            echo "  → メッシュ生成中..."
            blockMesh > "$local_log" 2>&1
            snappyHexMesh -overwrite >> "$local_log" 2>&1
            echo "    ✓ メッシュ生成完了"
        else
            echo "  → 既存メッシュを使用"
        fi
        
        # 初期条件設定
        if [[ -f "system/topoSetDict" ]]; then
            echo "  → topoSet実行中..."
            topoSet >> "$local_log" 2>&1
        fi
        if [[ -f "system/setFieldsDict" ]]; then
            echo "  → setFields実行中..."
            setFields >> "$local_log" 2>&1
        fi
        
        # メインシミュレーション
        echo "  → foamRun実行中..."
        start_time=$(date +%s)
        
        if timeout 120 foamRun -solver incompressibleFluid >> "$local_log" 2>&1; then
            end_time=$(date +%s)
            elapsed=$((end_time - start_time))
            echo "    ✅ シミュレーション完了 (${elapsed}秒)"
            
            # VTKファイル生成（可視化用）
            echo "  → VTKファイル生成中..."
            foamToVTK >> "$local_log" 2>&1
            echo "    ✓ VTK生成完了"
        else
            echo "    ❌ シミュレーション失敗またはタイムアウト"
            echo "    ログを確認してください: $local_log"
        fi
        
        echo "ケース処理完了: $source_case_name"
        cd ../..
    done
    
    echo ""
    echo "パターン $pattern_num 完了"
done

echo ""
echo "==========================================="
echo "🎉 全シミュレーション処理完了"
echo "結果保存先: $OUTPUT_DIR/"
echo "ログファイル: odor_sim_*.log"
echo ""
echo "結果確認:"
echo "  - ls $OUTPUT_DIR/"
echo "  - 可視化: ParaView等でVTKファイルを開く"
echo "==========================================="