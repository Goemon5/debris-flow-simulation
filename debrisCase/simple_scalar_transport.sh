#!/bin/bash
# 簡易版：匂い拡散シミュレーション

echo "匂い拡散シミュレーション（簡易版）"

# 最終時刻の流れ場を使用
cp -r 1000 scalarTransport
cp 0/s scalarTransport/

# 匂い源を設定（初期濃度分布）
cat > scalarTransport/s << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volScalarField;
    location    "scalarTransport";
    object      s;
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
        type            fixedValue;
        value           uniform 1.0;  // 瓦礫表面から匂い放出
    }
}

// ************************************************************************* //
EOF

echo "設定完了！"
echo "コンテナ内で以下を実行してください："
echo "  scalarTransportFoam -time 1000"