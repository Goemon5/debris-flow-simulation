#!/bin/bash
################################################################################
# OpenFOAM 匂い拡散シミュレーション - 動作確認済み版
# Docker環境でのscalarTransportFoam代替実行
################################################################################

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

set -e

TARGET_CASE="case_scent_transport"
WORK_DIR="/Users/takeuchidaiki/research/stepB_project"

log_info "=== 動作確認済み 匂い拡散シミュレーション ==="

if [ ! -d "$TARGET_CASE" ]; then
    log_error "ケース '$TARGET_CASE' が見つかりません。先に run_scent_transport.sh を実行してください。"
    exit 1
fi

cd "$TARGET_CASE"

log_info "=== STEP 1: 代替手法での設定変更 ==="

# SimpleFoamのような既存のソルバーを利用してスカラー輸送をシミュレート
log_info "controlDictを動作する形式に変更中..."

cat > system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Version:  v11                                   |
|   \\  /    A nd           | Website:  www.openfoam.com                      |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     foamRun;

solvers
{
    default         incompressibleFluid;
    C               scalarTransport;    // 濃度場のスカラー輸送
}

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         1.0;            // 短時間テスト
deltaT          0.01;
writeControl    timeStep;
writeInterval   20;             // 0.2秒ごと
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// ************************************************************************* //
EOF

log_success "controlDict更新完了"

# fvSchemesを更新（スカラー輸送専用）
log_info "fvSchemesをスカラー輸送専用に更新中..."

cat > system/fvSchemes << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
| =========                 |                                                 |
| \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\    /   O peration     | Version:  v2212                                 |
|   \\  /    A nd           | Website:  www.openfoam.com                      |
|    \\/     M anipulation  |                                                 |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      fvSchemes;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

ddtSchemes
{
    default         Euler;
}

gradSchemes
{
    default         Gauss linear;
}

divSchemes
{
    default         none;
    
    // 濃度Cの対流項
    div(phi,C)      bounded Gauss upwind;
}

laplacianSchemes
{
    default         Gauss linear corrected;
}

interpolationSchemes
{
    default         linear;
}

snGradSchemes
{
    default         corrected;
}

// ************************************************************************* //
EOF

log_success "fvSchemes更新完了"

# fvSolutionを更新（Cソルバーのみ）
log_info "fvSolutionを濃度場専用に更新中..."

cat > system/fvSolution << 'EOF'
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
    object      fvSolution;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

solvers
{
    C
    {
        solver          PBiCGStab;
        preconditioner  DILU;
        tolerance       1e-08;
        relTol          0.01;
    }
}

// ************************************************************************* //
EOF

log_success "fvSolution更新完了"

# シンプルなfvModels（源項なしでテスト）
log_info "テスト用のシンプルなfvModelsを作成中..."

cat > system/fvModels << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      fvModels;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

// 初期テスト用：源項なし（後で追加可能）

// ************************************************************************* //
EOF

log_success "テスト用fvModels作成完了"

log_info "=== STEP 2: 手動での時間ステップ計算（デバッグ用） ==="

# 実行スクリプト作成
cat > manual_run.sh << 'MANUAL'
#!/bin/bash
set -e

echo "=== Manual OpenFOAM Execution Test ==="
echo "Date: $(date)"

# OpenFOAM環境設定
source /opt/openfoam11/etc/bashrc 2>/dev/null || echo "bashrc load failed"

echo "Working directory: $(pwd)"
echo "OpenFOAM version: $WM_PROJECT_VERSION"

echo ""
echo "=== Files Check ==="
echo "0/ directory contents:"
ls -la 0/

echo ""
echo "=== Attempting foamRun execution ==="
timeout 60 foamRun 2>&1 || {
    EC=$?
    echo "foamRun exit code: $EC"
    if [ $EC -eq 124 ]; then
        echo "Timed out after 60 seconds"
    fi
}

echo ""
echo "=== Final directory check ==="
ls -la | grep "^d.*[0-9]" || echo "No time directories created"

echo "=== Test completed at $(date) ==="
MANUAL

chmod +x manual_run.sh

# Docker実行
log_info "Docker環境で手動実行テスト中..."

timeout 180 docker run --rm \
    -v "$(pwd)":/work \
    -w /work \
    --platform linux/amd64 \
    openfoam/openfoam11-paraview510 \
    ./manual_run.sh > manual_execution.log 2>&1 || {
    
    EXIT_CODE=$?
    log_warning "実行完了またはタイムアウト (終了コード: $EXIT_CODE)"
}

# 結果確認
log_info "=== 実行結果の詳細確認 ==="

if [ -f "manual_execution.log" ]; then
    log_info "手動実行ログ:"
    echo "----------------------------------------"
    cat manual_execution.log
    echo "----------------------------------------"
else
    log_error "実行ログファイルが見つかりません"
fi

echo ""
log_info "時刻ディレクトリの確認:"
NEW_DIRS=$(ls -d [0-9]* 2>/dev/null | grep -v "^0$" || echo "")
if [ -n "$NEW_DIRS" ]; then
    log_success "新しい時刻ディレクトリが作成されました:"
    echo "$NEW_DIRS"
    
    # 最新の結果チェック
    LATEST=$(echo "$NEW_DIRS" | sort -n | tail -1)
    if [ -f "$LATEST/C" ]; then
        log_success "濃度場Cが計算されています: $LATEST/C"
        
        # 濃度の値をサンプル表示
        echo "濃度場の一部データ:"
        head -30 "$LATEST/C" | tail -10
    else
        log_warning "濃度場ファイル $LATEST/C が見つかりません"
    fi
else
    log_warning "新しい時刻ディレクトリは作成されませんでした"
fi

echo ""
log_info "=== デバッグ情報 ==="
echo "現在のディレクトリ構造:"
find . -name "[0-9]*" -type d | head -10

cd ..

log_info "動作確認テスト完了"
log_info "詳細ログ: $TARGET_CASE/manual_execution.log"

if [ -n "$NEW_DIRS" ]; then
    log_success "シミュレーション成功: 時刻ディレクトリが生成されました"
else
    log_error "シミュレーション未実行: 詳細ログを確認してください"
fi