#!/bin/bash

# =============================================================================
# 90ケース匂い拡散シミュレーション自動実行スクリプト
# 30パターン × 3匂い源位置 = 90ケース
# =============================================================================

set -e  # エラー時に停止

# OpenFOAM環境チェック
check_openfoam_environment() {
    echo "OpenFOAM環境チェック中..."
    
    # 必須コマンドリスト
    local required_commands=("blockMesh" "foamRun")
    local optional_commands=("snappyHexMesh" "topoSet" "setFields" "foamToVTK")
    
    local missing_required=0
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "エラー: 必須コマンド '$cmd' が見つかりません"
            missing_required=1
        else
            echo "✓ $cmd"
        fi
    done
    
    if [[ $missing_required -eq 1 ]]; then
        echo "エラー: OpenFOAM環境が正しく設定されていません"
        echo "以下を実行してOpenFOAM環境を読み込んでください:"
        echo "  source /path/to/OpenFOAM/etc/bashrc"
        exit 1
    fi
    
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "✓ $cmd (オプション)"
        else
            echo "⚠ $cmd (オプション) - 見つかりません"
        fi
    done
    
    echo "OpenFOAM環境チェック完了"
}

# 環境チェック実行（ドライランモード時はスキップ）
if [[ "$DRY_RUN" != "true" ]]; then
    check_openfoam_environment
fi

# 設定
BASE_DIR="simulation_results_gnn"
OUTPUT_DIR="odor_simulation_results"
PATTERNS_TOTAL=40  # 使用可能パターン数
PATTERNS_TO_USE=30  # 実際に使用する数
MAX_PARALLEL=4     # 最大並列実行数

# ドライランモード（テスト用）
DRY_RUN=${DRY_RUN:-false}
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 ドライランモード: 実際のシミュレーションは実行しません"
fi

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
echo "対象パターン: $PATTERNS_TO_USE"
echo "匂い源位置: ${#ODOR_SOURCES[@]}箇所"
echo "総ケース数: $((PATTERNS_TO_USE * ${#ODOR_SOURCES[@]}))"
echo "最大並列数: $MAX_PARALLEL"
echo "==========================================="

# 並列実行管理用
declare -a PIDS=()

# メイン処理関数
process_case() {
    local pattern_num=$1
    local source_idx=$2
    local source_pos=$3
    local source_name=$4
    
    local pattern_dir="pattern_$(printf "%02d" $pattern_num)"
    local source_case_name="${pattern_dir}_${source_name}"
    local base_case="$BASE_DIR/$pattern_dir/debrisCase_gnn"
    local target_case="$OUTPUT_DIR/$source_case_name"
    
    echo "[$(date '+%H:%M:%S')] 開始: $source_case_name"
    
    # ベースケースが存在しない場合はスキップ
    if [[ ! -d "$base_case" ]]; then
        echo "警告: $base_case が見つかりません。スキップします。"
        return 1
    fi
    
    # 1. ケースディレクトリをコピー
    if [[ -d "$target_case" ]]; then
        echo "既存ケース削除: $target_case"
        rm -rf "$target_case"
    fi
    
    cp -r "$base_case" "$target_case"
    cd "$target_case"
    
    # 2. スカラー輸送用設定ファイルの作成・修正
    setup_scalar_transport "$source_pos"
    
    # 3. シミュレーション実行
    echo "[$(date '+%H:%M:%S')] 実行開始: $source_case_name"
    
    # ログファイル作成
    local log_file="../../odor_sim_${source_case_name}.log"
    
    # OpenFOAM実行（バックグラウンド）
    {
        # メッシュが存在しない場合は生成
        if [[ ! -d "constant/polyMesh" ]]; then
            echo "メッシュ生成中..." >> "$log_file"
            if command -v blockMesh >/dev/null 2>&1; then
                blockMesh >> "$log_file" 2>&1
            else
                echo "エラー: blockMeshコマンドが見つかりません" >> "$log_file"
                return 1
            fi
            
            if command -v snappyHexMesh >/dev/null 2>&1; then
                snappyHexMesh -overwrite >> "$log_file" 2>&1
            else
                echo "エラー: snappyHexMeshコマンドが見つかりません" >> "$log_file"
                return 1
            fi
        fi
        
        # 初期条件設定（コマンド存在確認付き）
        if [[ -f "system/topoSetDict" ]] && command -v topoSet >/dev/null 2>&1; then
            echo "topoSet実行中..." >> "$log_file"
            topoSet >> "$log_file" 2>&1
        elif [[ -f "system/topoSetDict" ]]; then
            echo "警告: topoSetコマンドが見つかりません。スキップします。" >> "$log_file"
        fi
        
        if [[ -f "system/setFieldsDict" ]] && command -v setFields >/dev/null 2>&1; then
            echo "setFields実行中..." >> "$log_file"
            setFields >> "$log_file" 2>&1
        elif [[ -f "system/setFieldsDict" ]]; then
            echo "警告: setFieldsコマンドが見つかりません。スキップします。" >> "$log_file"
        fi
        
        # シミュレーション実行（2段階：流れ場→濃度場）
        if command -v foamRun >/dev/null 2>&1; then
            echo "段階1: 流れ場計算実行中..." >> "$log_file"
            foamRun -solver incompressibleFluid >> "$log_file" 2>&1
            
            echo "段階2: 濃度場計算実行中..." >> "$log_file"
            foamRun -solver scalarTransport >> "$log_file" 2>&1
        else
            echo "エラー: foamRunコマンドが見つかりません" >> "$log_file"
            return 1
        fi
        
        # 結果後処理
        if command -v foamToVTK >/dev/null 2>&1; then
            echo "foamToVTK実行中..." >> "$log_file"
            foamToVTK >> "$log_file" 2>&1
        else
            echo "警告: foamToVTKコマンドが見つかりません。後処理をスキップします。" >> "$log_file"
        fi
        
        echo "[$(date '+%H:%M:%S')] 完了: $source_case_name" >> "$log_file"
        
    } &
    
    cd - > /dev/null
    return 0
}

# スカラー輸送設定関数
setup_scalar_transport() {
    local source_coords=$1
    local x_pos=$(echo $source_coords | cut -d' ' -f1)
    local y_pos=$(echo $source_coords | cut -d' ' -f2)
    local z_pos=$(echo $source_coords | cut -d' ' -f3)
    
    # 1. controlDict完全置換（最終バランス型設定）
    # Final balanced configuration for stability and proper time evolution
    cat > system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Website:  https://openfoam.org                 |
|   \\  /    A nd           | Version:  11                                    |
|    \\/     M anipulation  |                                                 |
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
    C               scalarTransport;
}

// Final balanced configuration for stability
startFrom       latestTime;
startTime       0;
stopAt          endTime;
endTime         5;
deltaT          0.001;

// Fixed time step for stability
adjustTimeStep  no;
maxCo           0.5;

writeControl    timeStep;
writeInterval   500;    // 0.5秒間隔で保存
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// Critical: Save concentration field C at final time
functions
{
    writeFinalFields
    {
        type            writeObjects;
        libs            ("utilityFunctionObjects");
        objects         ("U" "p" "C");
        writeControl    endTime;
    }
    
    fieldMinMax1
    {
        type            fieldMinMax;
        libs            (fieldFunctionObjects);
        fields          (C);
        writeControl    writeTime;
        executeControl  timeStep;
        executeInterval 100;
        log             true;
    }
}

// ************************************************************************* //
EOF
    
    # 2. scalarTransportProperties作成
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

    # 3. 乱流モデルファイル作成（OpenFOAM v11互換性確保）
    cat > 0/nut << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Website:  https://openfoam.org                 |
|   \\  /    A nd           | Version:  11                                    |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    object      nut;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 2 -1 0 0 0 0];

internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            calculated;
        value           uniform 0;
    }
    outlet
    {
        type            calculated;
        value           uniform 0;
    }
    ground
    {
        type            nutkWallFunction;
        value           uniform 0;
    }
    atmosphere
    {
        type            calculated;
        value           uniform 0;
    }
    debris
    {
        type            nutkWallFunction;
        value           uniform 0;
    }
}
// ************************************************************************* //
EOF

    cat > 0/k << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Website:  https://openfoam.org                 |
|   \\  /    A nd           | Version:  11                                    |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    object      k;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 2 -2 0 0 0 0];

internalField   uniform 0.1;

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform 0.1;
    }
    outlet
    {
        type            zeroGradient;
    }
    ground
    {
        type            kqRWallFunction;
        value           uniform 0.1;
    }
    atmosphere
    {
        type            zeroGradient;
    }
    debris
    {
        type            kqRWallFunction;
        value           uniform 0.1;
    }
}
// ************************************************************************* //
EOF

    cat > 0/epsilon << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Website:  https://openfoam.org                 |
|   \\  /    A nd           | Version:  11                                    |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       volScalarField;
    object      epsilon;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 2 -3 0 0 0 0];

internalField   uniform 0.01;

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform 0.01;
    }
    outlet
    {
        type            zeroGradient;
    }
    ground
    {
        type            epsilonWallFunction;
        value           uniform 0.01;
    }
    atmosphere
    {
        type            zeroGradient;
    }
    debris
    {
        type            epsilonWallFunction;
        value           uniform 0.01;
    }
}
// ************************************************************************* //
EOF

    # 4. 0/C初期条件作成
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
    debris
    {
        type            zeroGradient;
    }
}
// ************************************************************************* //
EOF

    # 4. fvModels修正（匂い源座標設定）
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
    type            scalarSemiImplicitSource;
    active          yes;
    
    scalarSemiImplicitSourceCoeffs
    {
        selectionMode   sphereToCell;
        origin          ($x_pos $y_pos $z_pos);
        radius          0.3;
        
        sources
        {
            C       (1.0 0.0);
        }
    }
}
// ************************************************************************* //
EOF

    # 5. fvSchemes修正（div(phi,C)追加）
    if ! grep -q "div(phi,C)" system/fvSchemes; then
        sed -i.bak '/div(phi,/a\
    div(phi,C)      bounded Gauss limitedLinear 1;' system/fvSchemes
    fi
    
    # 6. fvSolution完全置換（最終バランス型収束設定）
    # Final balanced convergence configuration to prevent early convergence and numerical divergence
    cat > system/fvSolution << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Website:  https://openfoam.org                 |
|   \\  /    A nd           | Version:  11                                    |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      fvSolution;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

solvers
{
    p
    {
        solver          GAMG;
        tolerance       1e-06;
        relTol          0.01;
        smoother        GaussSeidel;
        cacheAgglomeration true;
        nCellsInCoarsestLevel 10;
        agglomerator    faceAreaPair;
        mergeLevels     1;
    }

    U
    {
        solver          smoothSolver;
        smoother        GaussSeidel;
        tolerance       1e-06;
        relTol          0.01;
        nSweeps         1;
    }

    "(k|epsilon|nut)"
    {
        solver          smoothSolver;
        smoother        GaussSeidel;
        tolerance       1e-06;
        relTol          0.01;
        nSweeps         1;
    }
    
    // Final balanced configuration for concentration field
    C
    {
        solver          smoothSolver;
        smoother        symGaussSeidel;
        tolerance       1e-06;
        relTol          0.1;        // 相対許容値を緩く - prevents divergence
        minIter         1;          // 最小反復数を抑制 - prevents over-iteration
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 0;
    consistent      yes;

    // Final balanced residual control - prevents early convergence
    residualControl
    {
        p               1e-4;       // 元の設定に戻す - stable values
        U               1e-4;
        "(k|epsilon|nut)" 1e-4;
        C               1e-4;       // 安定した収束判定
    }
}

relaxationFactors
{
    equations
    {
        U               0.7;
        p               0.3;
        k               0.7;
        epsilon         0.7;
    }
}

// ************************************************************************* //
EOF
}

# 並列実行管理関数
wait_for_slot() {
    while [[ ${#PIDS[@]} -ge $MAX_PARALLEL ]]; do
        for i in "${!PIDS[@]}"; do
            if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
                unset "PIDS[$i]"
            fi
        done
        PIDS=("${PIDS[@]}")  # 配列再構築
        sleep 2
    done
}

# メインループ
total_jobs=0
completed_jobs=0

for ((pattern=1; pattern<=PATTERNS_TO_USE; pattern++)); do
    for source_idx in "${!ODOR_SOURCES[@]}"; do
        source_pos="${ODOR_SOURCES[$source_idx]}"
        source_name="${SOURCE_NAMES[$source_idx]}"
        
        # 並列実行スロット待機
        wait_for_slot
        
        # バックグラウンド実行
        process_case "$pattern" "$source_idx" "$source_pos" "$source_name" &
        PIDS+=($!)
        
        ((total_jobs++))
        echo "投入済み: $total_jobs / $((PATTERNS_TO_USE * ${#ODOR_SOURCES[@]}))"
        
        sleep 1  # システム負荷軽減
    done
done

# 全ジョブ完了待機
echo "全ジョブ投入完了。実行完了を待機中..."
for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
        wait "$pid"
    fi
done

echo "==========================================="
echo "全90ケースのシミュレーション完了"
echo "結果保存先: $OUTPUT_DIR/"
echo "ログファイル: odor_sim_*.log"
echo "==========================================="

# 結果サマリー作成
echo "シミュレーション結果サマリー:" > simulation_summary.txt
echo "実行日時: $(date)" >> simulation_summary.txt
echo "総ケース数: $total_jobs" >> simulation_summary.txt
echo "成功ケース: $(find "$OUTPUT_DIR" -name "*.vtk" | wc -l)" >> simulation_summary.txt
echo "詳細は各ログファイルを確認してください。" >> simulation_summary.txt