#!/bin/bash

# OpenFOAM設定ファイルの厳密検証スクリプト
# 数値的設定エラーと境界条件の矛盾を詳細チェック

set -e

echo "=============================================="
echo "OpenFOAM設定ファイル 厳密検証"
echo "開始時刻: $(date)"
echo "=============================================="

VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()

add_error() {
    VALIDATION_ERRORS+=("❌ CONFIG ERROR: $1")
    echo "❌ CONFIG ERROR: $1"
}

add_warning() {
    VALIDATION_WARNINGS+=("⚠️  CONFIG WARNING: $1")
    echo "⚠️  CONFIG WARNING: $1"
}

add_pass() {
    echo "✅ CONFIG PASS: $1"
}

# テンプレートディレクトリ
TEMPLATE_DIR="final_debris_01"

# =============================================================================
# 1. blockMeshDict 厳密検証
# =============================================================================
echo ""
echo "=== 1. blockMeshDict 厳密検証 ==="

if [ -f "$TEMPLATE_DIR/system/blockMeshDict" ]; then
    
    # 座標値の数値チェック
    vertices_section=$(sed -n '/vertices/,/;/p' "$TEMPLATE_DIR/system/blockMeshDict")
    if echo "$vertices_section" | grep -qE '[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?'; then
        # 座標範囲チェック（異常に大きい/小さい値）
        coords=$(echo "$vertices_section" | grep -oE '[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?' | head -20)
        max_coord=$(echo "$coords" | sort -n | tail -1)
        min_coord=$(echo "$coords" | sort -n | head -1)
        
        if [ $(echo "$max_coord > 1000" | bc -l) -eq 1 ]; then
            add_warning "座標値が異常に大きい: max=$max_coord (>1000m)"
        elif [ $(echo "$max_coord < 0.01" | bc -l) -eq 1 ]; then
            add_warning "座標値が異常に小さい: max=$max_coord (<0.01m)"
        else
            add_pass "座標値の範囲が適正: min=$min_coord, max=$max_coord"
        fi
    else
        add_error "blockMeshDict で座標値が読み取れません"
    fi
    
    # セル分割数チェック
    blocks_section=$(sed -n '/blocks/,/);/p' "$TEMPLATE_DIR/system/blockMeshDict")
    if echo "$blocks_section" | grep -q "hex"; then
        cell_counts=$(echo "$blocks_section" | grep -oE '\([0-9 ]+\)' | head -1 | tr -d '()')
        cells_x=$(echo $cell_counts | awk '{print $1}')
        cells_y=$(echo $cell_counts | awk '{print $2}')
        cells_z=$(echo $cell_counts | awk '{print $3}')
        
        # セル数の妥当性チェック
        if [ "$cells_x" -lt 5 ] || [ "$cells_y" -lt 5 ] || [ "$cells_z" -lt 5 ]; then
            add_error "セル分割数が少なすぎ: ($cells_x $cells_y $cells_z) - 最低5以上推奨"
        elif [ "$cells_x" -gt 200 ] || [ "$cells_y" -gt 200 ] || [ "$cells_z" -gt 200 ]; then
            add_warning "セル分割数が多すぎ: ($cells_x $cells_y $cells_z) - 計算時間に注意"
        else
            total_cells=$((cells_x * cells_y * cells_z))
            add_pass "セル分割数が適正: ($cells_x $cells_y $cells_z) = $total_cells セル"
        fi
    else
        add_error "blockMeshDict で blocks 定義が見つかりません"
    fi
    
    # 境界パッチ名チェック
    boundary_section=$(sed -n '/boundary/,/);/p' "$TEMPLATE_DIR/system/blockMeshDict")
    required_patches=("inlet" "outlet" "ground" "atmosphere" "sides")
    for patch in "${required_patches[@]}"; do
        if echo "$boundary_section" | grep -q "$patch"; then
            add_pass "境界パッチ '$patch' が定義済み"
        else
            add_error "必須境界パッチ '$patch' が blockMeshDict に定義されていません"
        fi
    done
    
else
    add_error "blockMeshDict が見つかりません: $TEMPLATE_DIR/system/blockMeshDict"
fi

# =============================================================================
# 2. 境界条件の一貫性チェック
# =============================================================================
echo ""
echo "=== 2. 境界条件の一貫性チェック ==="

# 速度場境界条件の詳細チェック
if [ -f "$TEMPLATE_DIR/0/U" ]; then
    
    # inlet境界条件
    inlet_type=$(sed -n '/inlet/,/}/p' "$TEMPLATE_DIR/0/U" | grep "type" | awk '{print $2}' | tr -d ';')
    if [ "$inlet_type" = "fixedValue" ]; then
        inlet_value=$(sed -n '/inlet/,/}/p' "$TEMPLATE_DIR/0/U" | grep "value" | grep -o '([^)]*)' | tr -d '()')
        inlet_x=$(echo $inlet_value | awk '{print $1}')
        inlet_y=$(echo $inlet_value | awk '{print $2}')
        inlet_z=$(echo $inlet_value | awk '{print $3}')
        
        if [ $(echo "$inlet_x > 0" | bc -l) -eq 1 ] && [ $(echo "$inlet_y == 0" | bc -l) -eq 1 ] && [ $(echo "$inlet_z == 0" | bc -l) -eq 1 ]; then
            add_pass "inlet速度設定が適正: ($inlet_x $inlet_y $inlet_z)"
        else
            add_error "inlet速度設定が不適切: ($inlet_x $inlet_y $inlet_z) - x方向のみ正値であるべき"
        fi
        
        # 速度の大きさチェック
        if [ $(echo "$inlet_x > 10" | bc -l) -eq 1 ]; then
            add_warning "inlet速度が高すぎ: ${inlet_x}m/s (>10m/s) - 数値不安定の可能性"
        elif [ $(echo "$inlet_x < 0.01" | bc -l) -eq 1 ]; then
            add_warning "inlet速度が低すぎ: ${inlet_x}m/s (<0.01m/s) - 収束しない可能性"
        fi
    else
        add_error "inlet境界条件が fixedValue ではありません: $inlet_type"
    fi
    
    # outlet境界条件
    outlet_type=$(sed -n '/outlet/,/}/p' "$TEMPLATE_DIR/0/U" | grep "type" | awk '{print $2}' | tr -d ';')
    if [ "$outlet_type" != "zeroGradient" ]; then
        add_error "outlet境界条件は zeroGradient であるべき: 現在は $outlet_type"
    else
        add_pass "outlet境界条件が適正: $outlet_type"
    fi
    
    # 壁面境界条件チェック
    wall_patches=("ground" "debris")
    for patch in "${wall_patches[@]}"; do
        if grep -q "$patch" "$TEMPLATE_DIR/0/U"; then
            wall_type=$(sed -n "/$patch/,/}/p" "$TEMPLATE_DIR/0/U" | grep "type" | awk '{print $2}' | tr -d ';')
            if [ "$wall_type" = "noSlip" ] || [ "$wall_type" = "fixedValue" ]; then
                add_pass "壁面パッチ '$patch' の境界条件が適正: $wall_type"
            else
                add_error "壁面パッチ '$patch' の境界条件が不適切: $wall_type (noSlip推奨)"
            fi
        fi
    done
    
else
    add_error "速度場初期条件ファイルが見つかりません: $TEMPLATE_DIR/0/U"
fi

# 圧力場境界条件チェック
if [ -f "$TEMPLATE_DIR/0/p" ]; then
    
    # outlet圧力設定（参照点として重要）
    outlet_p_type=$(sed -n '/outlet/,/}/p' "$TEMPLATE_DIR/0/p" | grep "type" | awk '{print $2}' | tr -d ';')
    if [ "$outlet_p_type" = "fixedValue" ]; then
        outlet_p_value=$(sed -n '/outlet/,/}/p' "$TEMPLATE_DIR/0/p" | grep "value" | awk '{print $3}' | tr -d ';')
        if [ "$outlet_p_value" = "0" ]; then
            add_pass "outlet圧力が適正に参照値0に設定"
        else
            add_warning "outlet圧力が0以外: $outlet_p_value (通常は0推奨)"
        fi
    else
        add_error "outlet圧力境界条件が fixedValue ではありません: $outlet_p_type"
    fi
    
    # inlet圧力設定
    inlet_p_type=$(sed -n '/inlet/,/}/p' "$TEMPLATE_DIR/0/p" | grep "type" | awk '{print $2}' | tr -d ';')
    if [ "$inlet_p_type" != "zeroGradient" ]; then
        add_error "inlet圧力境界条件は zeroGradient であるべき: 現在は $inlet_p_type"
    else
        add_pass "inlet圧力境界条件が適正: $inlet_p_type"
    fi
    
else
    add_error "圧力場初期条件ファイルが見つかりません: $TEMPLATE_DIR/0/p"
fi

# =============================================================================
# 3. 物性値・数値パラメータ検証
# =============================================================================
echo ""
echo "=== 3. 物性値・数値パラメータ検証 ==="

if [ -f "$TEMPLATE_DIR/constant/physicalProperties" ]; then
    
    # 動粘性係数チェック
    if grep -q "nu" "$TEMPLATE_DIR/constant/physicalProperties"; then
        nu_line=$(grep "nu" "$TEMPLATE_DIR/constant/physicalProperties")
        nu_value=$(echo "$nu_line" | awk '{print $3}' | tr -d ';')
        
        # 空気の動粘性係数範囲チェック（15℃～25℃）
        if [ $(echo "$nu_value >= 1.4e-5 && $nu_value <= 1.6e-5" | bc -l) -eq 1 ]; then
            add_pass "動粘性係数が空気の適正範囲: $nu_value m²/s"
        elif [ $(echo "$nu_value > 0 && $nu_value < 1e-3" | bc -l) -eq 1 ]; then
            add_warning "動粘性係数が範囲外だが物理的: $nu_value m²/s"
        else
            add_error "動粘性係数が非物理的: $nu_value m²/s"
        fi
        
        # 次元チェック
        nu_dimensions=$(echo "$nu_line" | grep -o '\[[^]]*\]')
        if [ "$nu_dimensions" = "[0 2 -1 0 0 0 0]" ]; then
            add_pass "動粘性係数の次元が正しい: $nu_dimensions"
        else
            add_error "動粘性係数の次元が間違い: $nu_dimensions (正: [0 2 -1 0 0 0 0])"
        fi
    else
        add_error "動粘性係数(nu)が physicalProperties に定義されていません"
    fi
    
else
    add_error "物性値ファイルが見つかりません: $TEMPLATE_DIR/constant/physicalProperties"
fi

# =============================================================================
# 4. 数値解法設定の安定性チェック
# =============================================================================
echo ""
echo "=== 4. 数値解法設定の安定性チェック ==="

if [ -f "$TEMPLATE_DIR/system/fvSchemes" ]; then
    
    # 対流項スキームチェック
    div_schemes=$(sed -n '/divSchemes/,/}/p' "$TEMPLATE_DIR/system/fvSchemes")
    
    if echo "$div_schemes" | grep -q "div(phi,U)"; then
        u_scheme=$(echo "$div_schemes" | grep "div(phi,U)" | awk '{print $2}' | tr -d ';')
        case "$u_scheme" in
            "bounded Gauss upwind"|"Gauss upwind"|"bounded Gauss linearUpwind")
                add_pass "速度場対流スキームが安定: $u_scheme"
                ;;
            "Gauss linear"|"bounded Gauss linear")
                add_warning "速度場対流スキームが高次だが安定性注意: $u_scheme"
                ;;
            *)
                add_error "速度場対流スキームが不適切: $u_scheme"
                ;;
        esac
    else
        add_error "div(phi,U) スキームが fvSchemes に定義されていません"
    fi
    
    # 拡散項スキームチェック
    laplacian_schemes=$(sed -n '/laplacianSchemes/,/}/p' "$TEMPLATE_DIR/system/fvSchemes")
    if echo "$laplacian_schemes" | grep -q "Gauss linear"; then
        add_pass "拡散項スキームが適正: Gauss linear"
    else
        add_warning "拡散項スキームを確認してください"
    fi
    
else
    add_error "数値スキームファイルが見つかりません: $TEMPLATE_DIR/system/fvSchemes"
fi

if [ -f "$TEMPLATE_DIR/system/fvSolution" ]; then
    
    # 圧力ソルバー設定チェック
    p_solver_section=$(sed -n '/p$/,/}/p' "$TEMPLATE_DIR/system/fvSolution")
    if echo "$p_solver_section" | grep -q "solver"; then
        p_solver=$(echo "$p_solver_section" | grep "solver" | awk '{print $2}' | tr -d ';')
        case "$p_solver" in
            "GAMG"|"PCG"|"ICCG")
                add_pass "圧力ソルバーが適正: $p_solver"
                ;;
            *)
                add_warning "圧力ソルバーを確認: $p_solver"
                ;;
        esac
        
        # 許容誤差チェック
        if echo "$p_solver_section" | grep -q "tolerance"; then
            p_tol=$(echo "$p_solver_section" | grep "tolerance" | awk '{print $2}' | tr -d ';')
            if [ $(echo "$p_tol >= 1e-8 && $p_tol <= 1e-4" | bc -l) -eq 1 ]; then
                add_pass "圧力許容誤差が適正: $p_tol"
            else
                add_warning "圧力許容誤差を確認: $p_tol (推奨: 1e-6)"
            fi
        fi
    else
        add_error "圧力ソルバー設定が fvSolution にありません"
    fi
    
    # SIMPLE設定チェック
    simple_section=$(sed -n '/SIMPLE/,/}/p' "$TEMPLATE_DIR/system/fvSolution")
    if echo "$simple_section" | grep -q "nNonOrthogonalCorrectors"; then
        non_ortho=$(echo "$simple_section" | grep "nNonOrthogonalCorrectors" | awk '{print $2}' | tr -d ';')
        if [ "$non_ortho" -ge 0 ] && [ "$non_ortho" -le 5 ]; then
            add_pass "非直交修正回数が適正: $non_ortho"
        else
            add_warning "非直交修正回数を確認: $non_ortho (推奨: 0-3)"
        fi
    fi
    
    # 緩和係数チェック
    if grep -q "relaxationFactors" "$TEMPLATE_DIR/system/fvSolution"; then
        relax_section=$(sed -n '/relaxationFactors/,/}/p' "$TEMPLATE_DIR/system/fvSolution")
        
        if echo "$relax_section" | grep -q "U"; then
            u_relax=$(echo "$relax_section" | grep "U" | awk '{print $2}' | tr -d ';')
            if [ $(echo "$u_relax > 0 && $u_relax <= 1" | bc -l) -eq 1 ]; then
                if [ $(echo "$u_relax >= 0.3 && $u_relax <= 0.8" | bc -l) -eq 1 ]; then
                    add_pass "速度緩和係数が適正: $u_relax"
                else
                    add_warning "速度緩和係数を確認: $u_relax (推奨: 0.3-0.8)"
                fi
            else
                add_error "速度緩和係数が異常: $u_relax (範囲: 0-1)"
            fi
        fi
        
        if echo "$relax_section" | grep -q "p"; then
            p_relax=$(echo "$relax_section" | grep "p" | awk '{print $2}' | tr -d ';')
            if [ $(echo "$p_relax > 0 && $p_relax <= 1" | bc -l) -eq 1 ]; then
                if [ $(echo "$p_relax >= 0.1 && $p_relax <= 0.5" | bc -l) -eq 1 ]; then
                    add_pass "圧力緩和係数が適正: $p_relax"
                else
                    add_warning "圧力緩和係数を確認: $p_relax (推奨: 0.1-0.3)"
                fi
            else
                add_error "圧力緩和係数が異常: $p_relax (範囲: 0-1)"
            fi
        fi
    else
        add_warning "緩和係数が設定されていません（収束性に影響の可能性）"
    fi
    
else
    add_error "ソルバー設定ファイルが見つかりません: $TEMPLATE_DIR/system/fvSolution"
fi

# =============================================================================
# 5. controlDict の時間設定検証
# =============================================================================
echo ""
echo "=== 5. controlDict の時間設定検証 ==="

if [ -f "$TEMPLATE_DIR/system/controlDict" ]; then
    
    # 時間刻み設定
    if grep -q "deltaT" "$TEMPLATE_DIR/system/controlDict"; then
        deltaT=$(grep "deltaT" "$TEMPLATE_DIR/system/controlDict" | awk '{print $2}' | tr -d ';')
        endTime=$(grep "endTime" "$TEMPLATE_DIR/system/controlDict" | awk '{print $2}' | tr -d ';')
        
        # Courant数の概算（非常に粗い推定）
        if [ -n "$deltaT" ] && [ -n "$endTime" ]; then
            total_steps=$(echo "scale=0; $endTime / $deltaT" | bc)
            if [ "$total_steps" -gt 100000 ]; then
                add_warning "計算ステップ数が多すぎ: $total_steps ステップ (時間に注意)"
            elif [ "$total_steps" -lt 10 ]; then
                add_warning "計算ステップ数が少なすぎ: $total_steps ステップ (精度に注意)"
            else
                add_pass "計算ステップ数が適正: $total_steps ステップ"
            fi
        fi
        
        # 時間刻みの妥当性
        if [ $(echo "$deltaT > 0.1" | bc -l) -eq 1 ]; then
            add_warning "時間刻みが大きすぎ: $deltaT s (数値不安定の可能性)"
        elif [ $(echo "$deltaT < 1e-6" | bc -l) -eq 1 ]; then
            add_warning "時間刻みが小さすぎ: $deltaT s (計算時間過大)"
        else
            add_pass "時間刻み設定が適正: $deltaT s"
        fi
    else
        add_error "deltaT が controlDict に定義されていません"
    fi
    
    # 出力設定チェック
    if grep -q "writeControl" "$TEMPLATE_DIR/system/controlDict"; then
        write_control=$(grep "writeControl" "$TEMPLATE_DIR/system/controlDict" | awk '{print $2}' | tr -d ';')
        if [ "$write_control" = "timeStep" ] || [ "$write_control" = "runTime" ]; then
            add_pass "出力制御設定が適正: $write_control"
        else
            add_warning "出力制御設定を確認: $write_control"
        fi
    fi
    
else
    add_error "制御設定ファイルが見つかりません: $TEMPLATE_DIR/system/controlDict"
fi

# =============================================================================
# 検証結果まとめ
# =============================================================================
echo ""
echo "=============================================="
echo "OpenFOAM設定検証結果まとめ"
echo "=============================================="

echo "❌ 設定エラー: ${#VALIDATION_ERRORS[@]} 項目"
echo "⚠️  設定警告: ${#VALIDATION_WARNINGS[@]} 項目"

if [ ${#VALIDATION_ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "=== 🚨 致命的設定エラー ==="
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo "$error"
    done
fi

if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "=== ⚠️  設定警告 ==="
    for warning in "${VALIDATION_WARNINGS[@]}"; do
        echo "$warning"
    done
fi

echo ""
echo "検証完了時刻: $(date)"

# 終了コード
if [ ${#VALIDATION_ERRORS[@]} -eq 0 ]; then
    echo ""
    echo "✅ OpenFOAM設定検証完了！数値的設定エラーなし"
    exit 0
else
    echo ""
    echo "❌ OpenFOAM設定にエラーがあります。修正してください"
    exit 1
fi