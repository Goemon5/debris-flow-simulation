#!/bin/bash
# 簡易版：初期濃度からの拡散のみ

echo "簡易匂い拡散（初期濃度からの拡散）"

# 最終流れ場をコピー
cp -r 1000 odorDiffusion
cp 0/s odorDiffusion/

# 匂い源の初期濃度を手動設定（簡易版）
cat > odorDiffusion/s << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volScalarField;
    location    "odorDiffusion";
    object      s;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 0 0 0 0 0 0];

// ほとんどのセルで0、特定の場所だけ1に設定
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

echo "準備完了！"
echo ""
echo "次のステップ："
echo "1. コンテナ内で topoSet を実行"
echo "2. setFields -time odorDiffusion を実行"
echo "3. 手動で特定セルの濃度を1に編集"
echo ""
echo "これは最も基本的な拡散計算です。"