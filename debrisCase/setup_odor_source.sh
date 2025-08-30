#!/bin/bash
# 一点の匂い源を設定するスクリプト

echo "========================================="
echo "匂い源（一点）の設定"
echo "========================================="

# Step 1: topoSetで匂い源となる球形領域を定義
echo "Step 1: 匂い源領域（球形）を定義..."
cat > system/topoSetDict << 'EOF'
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
    object      topoSetDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

actions
(
    {
        name    odorSourceCells;
        type    cellSet;
        action  new;
        source  sphereToCell;
        sourceInfo
        {
            centre  (2 -3 0.5);  // 匂い源の中心座標（瓦礫内部の一点）
            radius  0.3;         // 半径0.3mの小さな球形領域
        }
    }
);

// ************************************************************************* //
EOF

# topoSetを実行
topoSet

echo "Step 2: 匂い源領域のセル数を確認..."
checkMesh -allTopology -allGeometry 2>&1 | grep -A5 "cellSet odorSourceCells"

# Step 2: setFieldsDictで初期濃度を設定
echo "Step 3: 初期濃度場を設定..."
cat > system/setFieldsDict << 'EOF'
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
    object      setFieldsDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

defaultFieldValues
(
    volScalarFieldValue s 0  // 全領域で濃度0
);

regions
(
    cellToCell
    {
        set odorSourceCells;  // topoSetで定義した領域
        fieldValues
        (
            volScalarFieldValue s 1.0  // 匂い源で濃度1
        );
    }
);

// ************************************************************************* //
EOF

# Step 3: 最終流れ場をコピー
echo "Step 4: 流れ場データを準備..."
cp -r 1000 odorTransport
cp 0/s odorTransport/

# 匂い源を設定
cd odorTransport
setFields
cd ..

echo "Step 5: 匂い源の可視化用マーカーを作成..."
cat > odor_source_location.txt << 'EOF'
匂い源の位置情報
================
座標: (2, -3, 0.5) m
半径: 0.3 m
初期濃度: 1.0

この点から匂いが継続的に放出されます。
EOF

echo "========================================="
echo "設定完了！"
echo "========================================="
echo ""
echo "実行方法："
echo "1. 定常的な匂い放出（fvOptionsを使用）"
echo "   または"
echo "2. 初期濃度からの拡散（setFieldsのみ）"
echo ""
echo "コンテナ内で以下を実行："
echo "  cd odorTransport"
echo "  scalarTransportFoam"