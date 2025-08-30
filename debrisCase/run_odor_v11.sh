#!/bin/bash
# OpenFOAM v11用の匂い拡散シミュレーション

echo "========================================="
echo "匂い拡散シミュレーション (OpenFOAM v11)"
echo "========================================="

# 流れ場の最終結果をベースに使用
echo "Step 1: 流れ場データを準備..."
cp -r 1000 1001
cp 0/s 1001/

# controlDictを匂い拡散用に設定
echo "Step 2: controlDictを設定..."
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

solver          incompressibleFluid;

startFrom       startTime;
startTime       1001;
stopAt          endTime;
endTime         1500;
deltaT          0.1;
writeControl    timeStep;
writeInterval   50;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

functions
{
    scalarTransport
    {
        type            scalarTransport;
        libs            (solverFunctionObjects);
        
        field           s;
        D               2e-05;  // 分子拡散係数
        nCorr           0;
        resetOnStartUp  false;
        
        fvOptions
        {
            odorSource
            {
                type            scalarSemiImplicitSource;
                active          yes;
                
                scalarSemiImplicitSourceCoeffs
                {
                    selectionMode   cellSet;
                    cellSet         odorSourceCells;
                    volumeMode      specific;
                    
                    sources
                    {
                        s
                        {
                            explicit    0.1;  // 匂い生成率
                            implicit    0;
                        }
                    }
                }
            }
        }
    }
}

// ************************************************************************* //
EOF

# topoSetで匂い源領域を作成
echo "Step 3: 匂い源領域を作成..."
topoSet

# setFieldsで初期濃度を設定
echo "Step 4: 初期濃度を設定..."
setFields -time 1001

echo "Step 5: 匂い拡散計算を実行..."
echo "以下のコマンドを実行してください："
echo ""
echo "  foamRun -solver functions"
echo ""
echo "========================================="