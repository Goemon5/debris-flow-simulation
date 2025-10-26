#!/bin/bash
# 全90パターンの設定変換

SOURCE_DIR="simulation_results_90patterns"
TARGET_DIR="simpleFoam_results"

echo "Converting all 90 patterns for simpleFoam..."
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"

# ターゲットディレクトリ作成
mkdir -p $TARGET_DIR

for i in {01..90}; do
    echo "Converting pattern_$i..."
    
    # ソースディレクトリ確認
    if [ ! -d "${SOURCE_DIR}/pattern_$i" ]; then
        echo "Warning: ${SOURCE_DIR}/pattern_$i not found, skipping..."
        continue
    fi
    
    # ディレクトリ作成
    mkdir -p ${TARGET_DIR}/pattern_$i
    
    # ファイルコピー
    cp -r ${SOURCE_DIR}/pattern_$i/* ${TARGET_DIR}/pattern_$i/
    
    cd ${TARGET_DIR}/pattern_$i
    
    # controlDict変更
    sed -i 's/scalarTransportFoam/simpleFoam/g' system/controlDict
    sed -i 's/deltaT          0.005/deltaT          0.01/g' system/controlDict
    sed -i 's/endTime         5/endTime         100/g' system/controlDict  # 定常計算用
    
    # 並列計算用設定追加
    cat >> system/controlDict << 'EOF'

// Parallel computation settings
writeFormat     binary;
runTimeModifiable false;
EOF
    
    # fvSolution更新（並列計算対応）
    cp ../../templates/fvSolution_parallel.template system/fvSolution
    
    # fvSchemes更新（定常計算用）
    cp ../../templates/fvSchemes.template system/fvSchemes
    
    # 物理特性更新
    cp ../../templates/physicalProperties.template constant/physicalProperties
    
    # 並列計算用decomposeParDict作成
    cat > system/decomposeParDict << 'EOF'
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      decomposeParDict;
}

numberOfSubdomains 8;

method          scotch;

scotchCoeffs
{
    processorWeights
    (
        1
        1
        1
        1
        1
        1
        1
        1
    );
}
EOF
    
    # 古い結果削除
    rm -rf [0-9]* processor* postProcessing/ log.* *.log
    
    cd ../..
    echo "Pattern_$i conversion completed"
done

echo ""
echo "Conversion summary:"
echo "Total patterns found: $(ls ${SOURCE_DIR}/ | grep pattern | wc -l)"
echo "Total patterns converted: $(ls ${TARGET_DIR}/ | grep pattern | wc -l)"
echo "All conversions completed!"