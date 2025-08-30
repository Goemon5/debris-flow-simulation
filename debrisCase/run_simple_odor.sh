#!/bin/bash
# 簡単な匂い拡散シミュレーション（OpenFOAM v11用）

echo "========================================="
echo "匂い拡散シミュレーション（簡易版）"
echo "========================================="

# fvOptionsを一時的に無効化（初期濃度のみで拡散）
echo "Step 1: fvOptionsを無効化..."
mv system/fvOptions system/fvOptions.bak 2>/dev/null

# 流れ場データを準備
echo "Step 2: 流れ場データを準備..."
rm -rf 1001
cp -r 1000 1001
cp 0/s 1001/

# topoSetで匂い源領域を定義
echo "Step 3: 匂い源領域を作成..."
topoSet

# setFieldsで初期濃度を設定
echo "Step 4: 初期濃度を設定..."
setFields -time 1001

# controlDictをシンプルに設定
echo "Step 5: controlDictを設定..."
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

application     foamRun;

solvers
{
    default         incompressibleFluid;
}

startFrom       startTime;
startTime       1001;
stopAt          endTime;
endTime         1010;
deltaT          0.01;
writeControl    timeStep;
writeInterval   100;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// ************************************************************************* //
EOF

echo "Step 6: 流体解析を実行（スカラー輸送含む）..."
echo "実行コマンド: foamRun -solver incompressibleFluid"
echo ""
echo "注意: これは初期濃度からの拡散のみです。"
echo "      継続的な匂い源ではありません。"
echo "========================================="