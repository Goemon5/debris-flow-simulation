#!/bin/bash
# 匂い拡散シミュレーション実行スクリプト

echo "========================================="
echo "匂い拡散シミュレーション"
echo "========================================="

# 流れ場の最終結果を初期条件にコピー
echo "Step 1: 流れ場の最終結果を初期条件に設定..."
cp -r 1000 1001
cp 0/s 1001/

# 匂い源を瓦礫内部に設定
echo "Step 2: 匂い源領域を設定..."
cat > system/setFieldsDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      setFieldsDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

defaultFieldValues
(
    volScalarFieldValue s 0
);

regions
(
    // 瓦礫内部の特定領域に匂い源を設定
    sphereToCell
    {
        centre (0 0 1);  // 瓦礫の中心付近
        radius 2.0;      // 半径2mの球形領域
        fieldValues
        (
            volScalarFieldValue s 1.0
        );
    }
);

// ************************************************************************* //
EOF

# setFieldsで匂い源を設定
setFields -time 1001

# スカラー輸送の実行設定
echo "Step 3: スカラー輸送ソルバーの設定..."
cat > system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     scalarTransportFoam;

startFrom       startTime;
startTime       1001;
stopAt          endTime;
endTime         2000;
deltaT          1;
writeControl    timeStep;
writeInterval   100;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

functions
{
    #includeFunc residuals
}

// ************************************************************************* //
EOF

# scalarTransportFoamの実行
echo "Step 4: 匂い拡散計算を実行..."
scalarTransportFoam

echo "Step 5: 結果の確認..."
ls -la 2000/s 2>/dev/null && echo "匂い拡散計算完了！"

echo "========================================="
echo "完了！ParaViewで結果を確認してください"
echo "========================================="