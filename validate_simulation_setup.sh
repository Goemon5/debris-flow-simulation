#!/bin/bash

# 厳格な設定エラー検証スクリプト
# 実行前に全ての設定をチェックして問題を事前検出

set -e

echo "=============================================="
echo "OpenFOAM シミュレーション設定 厳格検証"
echo "開始時刻: $(date)"
echo "=============================================="

# 検証結果記録
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()
VALIDATION_PASSED=0
VALIDATION_TOTAL=0

# 検証結果記録関数
add_error() {
    VALIDATION_ERRORS+=("❌ ERROR: $1")
    echo "❌ ERROR: $1"
}

add_warning() {
    VALIDATION_WARNINGS+=("⚠️  WARNING: $1")
    echo "⚠️  WARNING: $1"
}

add_pass() {
    echo "✅ PASS: $1"
    VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
}

increment_total() {
    VALIDATION_TOTAL=$((VALIDATION_TOTAL + 1))
}

# =============================================================================
# 1. システム環境検証
# =============================================================================
echo ""
echo "=== 1. システム環境検証 ==="

# Docker確認
increment_total
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        add_pass "Docker が利用可能"
    else
        add_error "Docker デーモンが起動していません"
    fi
else
    add_error "Docker がインストールされていません"
fi

# OpenFOAMイメージ確認
increment_total
if docker images | grep -q "openfoam/openfoam10-paraview510"; then
    add_pass "OpenFOAM Docker イメージが存在"
else
    add_error "OpenFOAM Docker イメージ 'openfoam/openfoam10-paraview510' が見つかりません"
fi

# メモリ確認
increment_total
available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$available_memory" -gt 4000 ]; then
    add_pass "利用可能メモリ: ${available_memory}MB (推奨: >4GB)"
elif [ "$available_memory" -gt 2000 ]; then
    add_warning "利用可能メモリ: ${available_memory}MB (推奨: >4GB, 最低: >2GB)"
else
    add_error "利用可能メモリ不足: ${available_memory}MB (最低: 2GB必要)"
fi

# ディスク容量確認
increment_total
available_disk=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$available_disk" -gt 20 ]; then
    add_pass "利用可能ディスク容量: ${available_disk}GB (推奨: >20GB)"
elif [ "$available_disk" -gt 10 ]; then
    add_warning "利用可能ディスク容量: ${available_disk}GB (推奨: >20GB, 最低: >10GB)"
else
    add_error "ディスク容量不足: ${available_disk}GB (最低: 10GB必要)"
fi

# =============================================================================
# 2. 必須ファイル・ディレクトリ検証
# =============================================================================
echo ""
echo "=== 2. 必須ファイル・ディレクトリ検証 ==="

# テンプレートディレクトリ確認
increment_total
TEMPLATE_DIR="final_debris_01"
if [ -d "$TEMPLATE_DIR" ]; then
    add_pass "テンプレートディレクトリ '$TEMPLATE_DIR' が存在"
    
    # テンプレート内の必須ファイル確認
    template_files=("system/blockMeshDict" "system/fvSchemes" "system/fvSolution" "0/U" "0/p" "constant/physicalProperties")
    for file in "${template_files[@]}"; do
        increment_total
        if [ -f "$TEMPLATE_DIR/$file" ]; then
            add_pass "テンプレートファイル '$file' が存在"
        else
            add_error "テンプレートファイル '$file' が見つかりません"
        fi
    done
else
    add_error "テンプレートディレクトリ '$TEMPLATE_DIR' が見つかりません"
fi

# STLファイル確認
increment_total
stl_count=$(ls debris_pattern_*.stl 2>/dev/null | wc -l)
if [ "$stl_count" -eq 90 ]; then
    add_pass "STLファイル: ${stl_count}個 (期待: 90個)"
else
    add_error "STLファイル数が不正: ${stl_count}個 (期待: 90個)"
fi

# =============================================================================
# 3. STLファイル詳細検証
# =============================================================================
echo ""
echo "=== 3. STLファイル詳細検証 ==="

# 各STLファイルの基本チェック
error_stl_files=()
for i in $(seq -f "%02g" 1 5); do  # 最初の5個をサンプルチェック
    stl_file="debris_pattern_${i}.stl"
    increment_total
    
    if [ ! -f "$stl_file" ]; then
        add_error "STLファイル '$stl_file' が見つかりません"
        error_stl_files+=("$stl_file")
        continue
    fi
    
    # ファイルサイズチェック
    file_size=$(stat -f%z "$stl_file" 2>/dev/null || stat -c%s "$stl_file" 2>/dev/null || echo 0)
    if [ "$file_size" -lt 1000 ]; then
        add_error "STLファイル '$stl_file' のサイズが異常に小さい: ${file_size}bytes"
        error_stl_files+=("$stl_file")
        continue
    fi
    
    # STLファイルヘッダーチェック
    if ! head -1 "$stl_file" | grep -q "solid"; then
        add_error "STLファイル '$stl_file' のフォーマットが不正（solidヘッダーなし）"
        error_stl_files+=("$stl_file")
        continue
    fi
    
    add_pass "STLファイル '$stl_file' は正常 (${file_size}bytes)"
done

# =============================================================================
# 4. OpenFOAM設定ファイル検証
# =============================================================================
echo ""
echo "=== 4. OpenFOAM設定ファイル検証 ==="

# blockMeshDict検証
increment_total
if [ -f "$TEMPLATE_DIR/system/blockMeshDict" ]; then
    # 基本キーワード確認
    if grep -q "vertices" "$TEMPLATE_DIR/system/blockMeshDict" && \
       grep -q "blocks" "$TEMPLATE_DIR/system/blockMeshDict" && \
       grep -q "boundary" "$TEMPLATE_DIR/system/blockMeshDict"; then
        add_pass "blockMeshDict の基本構造が正常"
    else
        add_error "blockMeshDict の基本構造が不正（vertices/blocks/boundary）"
    fi
    
    # 数値範囲チェック
    if grep -q "convertToMeters" "$TEMPLATE_DIR/system/blockMeshDict"; then
        scale=$(grep "convertToMeters" "$TEMPLATE_DIR/system/blockMeshDict" | awk '{print $2}' | tr -d ';')
        if [ $(echo "$scale > 0" | bc -l) ]; then
            add_pass "blockMeshDict のスケール設定が正常: $scale"
        else
            add_error "blockMeshDict のスケール設定が異常: $scale"
        fi
    fi
else
    add_error "blockMeshDict が見つかりません"
fi

# controlDict検証（実行時に動的生成されるため基本チェックのみ）
increment_total
required_apps=("simpleFoam" "scalarTransportFoam")
for app in "${required_apps[@]}"; do
    if docker run --rm openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc && which $app" >/dev/null 2>&1; then
        add_pass "OpenFOAMソルバー '$app' が利用可能"
    else
        add_error "OpenFOAMソルバー '$app' が見つかりません"
    fi
done

# =============================================================================
# 5. 境界条件設定検証
# =============================================================================
echo ""
echo "=== 5. 境界条件設定検証 ==="

# 速度場初期条件チェック
increment_total
if [ -f "$TEMPLATE_DIR/0/U" ]; then
    if grep -q "inlet" "$TEMPLATE_DIR/0/U" && \
       grep -q "outlet" "$TEMPLATE_DIR/0/U" && \
       grep -q "fixedValue" "$TEMPLATE_DIR/0/U"; then
        
        # inlet速度値チェック
        inlet_velocity=$(grep -A 3 "inlet" "$TEMPLATE_DIR/0/U" | grep "value" | grep -o '([^)]*)' | tr -d '()')
        if echo "$inlet_velocity" | grep -q "0.2"; then
            add_pass "inlet境界条件が正常: $inlet_velocity"
        else
            add_warning "inlet速度が期待値と異なる: $inlet_velocity (期待: 0.2 0 0)"
        fi
    else
        add_error "速度場境界条件が不完全（inlet/outlet/fixedValue）"
    fi
else
    add_error "速度場初期条件ファイル '0/U' が見つかりません"
fi

# 圧力場初期条件チェック
increment_total
if [ -f "$TEMPLATE_DIR/0/p" ]; then
    if grep -q "inlet" "$TEMPLATE_DIR/0/p" && \
       grep -q "outlet" "$TEMPLATE_DIR/0/p"; then
        add_pass "圧力場境界条件が設定済み"
    else
        add_error "圧力場境界条件が不完全"
    fi
else
    add_error "圧力場初期条件ファイル '0/p' が見つかりません"
fi

# =============================================================================
# 6. 物性値設定検証
# =============================================================================
echo ""
echo "=== 6. 物性値設定検証 ==="

increment_total
if [ -f "$TEMPLATE_DIR/constant/physicalProperties" ]; then
    # 動粘性係数チェック
    if grep -q "nu" "$TEMPLATE_DIR/constant/physicalProperties"; then
        nu_value=$(grep "nu" "$TEMPLATE_DIR/constant/physicalProperties" | awk '{print $3}' | tr -d ';')
        if [ $(echo "$nu_value > 0 && $nu_value < 1" | bc -l) ]; then
            add_pass "動粘性係数が適正範囲: $nu_value"
        else
            add_error "動粘性係数が異常: $nu_value (期待範囲: 1e-6 ~ 1e-4)"
        fi
    else
        add_error "動粘性係数(nu)が設定されていません"
    fi
else
    add_error "物性値ファイル 'constant/physicalProperties' が見つかりません"
fi

# =============================================================================
# 7. 数値解法設定検証
# =============================================================================
echo ""
echo "=== 7. 数値解法設定検証 ==="

# fvSchemes検証
increment_total
if [ -f "$TEMPLATE_DIR/system/fvSchemes" ]; then
    required_schemes=("ddtSchemes" "gradSchemes" "divSchemes" "laplacianSchemes")
    all_schemes_present=true
    
    for scheme in "${required_schemes[@]}"; do
        if ! grep -q "$scheme" "$TEMPLATE_DIR/system/fvSchemes"; then
            add_error "fvSchemesに '$scheme' が見つかりません"
            all_schemes_present=false
        fi
    done
    
    if $all_schemes_present; then
        add_pass "fvSchemes の基本構造が完全"
    fi
else
    add_error "数値スキームファイル 'system/fvSchemes' が見つかりません"
fi

# fvSolution検証
increment_total
if [ -f "$TEMPLATE_DIR/system/fvSolution" ]; then
    if grep -q "solvers" "$TEMPLATE_DIR/system/fvSolution" && \
       grep -q "SIMPLE" "$TEMPLATE_DIR/system/fvSolution"; then
        add_pass "fvSolution の基本構造が正常"
        
        # 収束判定値チェック
        if grep -A 10 "residualControl" "$TEMPLATE_DIR/system/fvSolution" | grep -q "1e-"; then
            add_pass "収束判定値が適切に設定済み"
        else
            add_warning "収束判定値が設定されていない可能性"
        fi
    else
        add_error "fvSolution の基本構造が不正"
    fi
else
    add_error "ソルバー設定ファイル 'system/fvSolution' が見つかりません"
fi

# =============================================================================
# 8. 実行スクリプト検証
# =============================================================================
echo ""
echo "=== 8. 実行スクリプト検証 ==="

increment_total
MAIN_SCRIPT="run_90patterns_odor_simulation.sh"
if [ -f "$MAIN_SCRIPT" ]; then
    if [ -x "$MAIN_SCRIPT" ]; then
        add_pass "メインスクリプト '$MAIN_SCRIPT' が実行可能"
        
        # スクリプト内の重要な設定値チェック
        if grep -q "TEMPLATE_DIR=" "$MAIN_SCRIPT"; then
            template_dir_in_script=$(grep "TEMPLATE_DIR=" "$MAIN_SCRIPT" | head -1 | cut -d'"' -f2)
            if [ "$template_dir_in_script" = "$TEMPLATE_DIR" ]; then
                add_pass "スクリプト内のテンプレートディレクトリ設定が一致"
            else
                add_error "スクリプト内のテンプレートディレクトリが不一致: '$template_dir_in_script' vs '$TEMPLATE_DIR'"
            fi
        fi
    else
        add_error "メインスクリプト '$MAIN_SCRIPT' が実行可能ではありません (chmod +x が必要)"
    fi
else
    add_error "メインスクリプト '$MAIN_SCRIPT' が見つかりません"
fi

# =============================================================================
# 9. 高度な設定検証（潜在的問題の検出）
# =============================================================================
echo ""
echo "=== 9. 高度な設定検証 ==="

# Courant数設定チェック
increment_total
if [ -f "$TEMPLATE_DIR/system/controlDict" ]; then
    if grep -q "deltaT" "$TEMPLATE_DIR/system/controlDict"; then
        deltaT=$(grep "deltaT" "$TEMPLATE_DIR/system/controlDict" | awk '{print $2}' | tr -d ';')
        if [ $(echo "$deltaT > 0 && $deltaT <= 1" | bc -l) ]; then
            add_pass "時間刻み設定が適正: $deltaT"
        else
            add_warning "時間刻み設定を確認: $deltaT (推奨: <= 1.0)"
        fi
    fi
fi

# メッシュサイズ予想チェック
increment_total
if [ -f "$TEMPLATE_DIR/system/blockMeshDict" ]; then
    # セル数の概算
    cells_x=$(grep -A 20 "blocks" "$TEMPLATE_DIR/system/blockMeshDict" | grep "hex" | awk '{print $9}')
    cells_y=$(grep -A 20 "blocks" "$TEMPLATE_DIR/system/blockMeshDict" | grep "hex" | awk '{print $10}')
    cells_z=$(grep -A 20 "blocks" "$TEMPLATE_DIR/system/blockMeshDict" | grep "hex" | awk '{print $11}')
    
    if [ -n "$cells_x" ] && [ -n "$cells_y" ] && [ -n "$cells_z" ]; then
        total_cells=$((cells_x * cells_y * cells_z))
        if [ "$total_cells" -gt 1000000 ]; then
            add_warning "メッシュサイズが大きい: 約${total_cells}セル (計算時間に注意)"
        elif [ "$total_cells" -lt 10000 ]; then
            add_warning "メッシュサイズが小さすぎる: 約${total_cells}セル (精度に注意)"
        else
            add_pass "メッシュサイズが適正: 約${total_cells}セル"
        fi
    fi
fi

# =============================================================================
# 検証結果まとめ
# =============================================================================
echo ""
echo "=============================================="
echo "検証結果まとめ"
echo "=============================================="

echo "✅ 成功: $VALIDATION_PASSED/$VALIDATION_TOTAL 項目"
echo "❌ エラー: ${#VALIDATION_ERRORS[@]} 項目"
echo "⚠️  警告: ${#VALIDATION_WARNINGS[@]} 項目"

if [ ${#VALIDATION_ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "=== 🚨 致命的エラー（実行前に修正必須） ==="
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo "$error"
    done
fi

if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "=== ⚠️  警告（推奨修正項目） ==="
    for warning in "${VALIDATION_WARNINGS[@]}"; do
        echo "$warning"
    done
fi

echo ""
echo "検証完了時刻: $(date)"

# 終了コード決定
if [ ${#VALIDATION_ERRORS[@]} -eq 0 ]; then
    if [ ${#VALIDATION_WARNINGS[@]} -eq 0 ]; then
        echo ""
        echo "🎉 全ての検証をパス！シミュレーション実行準備完了"
        exit 0
    else
        echo ""
        echo "⚠️  警告がありますが実行可能です"
        exit 1
    fi
else
    echo ""
    echo "❌ 致命的エラーがあります。修正後に再実行してください"
    exit 2
fi