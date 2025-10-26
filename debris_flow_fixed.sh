#!/bin/bash
# Fixed debris flow test with corrected controlDict

echo "=== Fixed Debris Flow Test with Pattern 01 ==="

TEST_DIR="debris_flow_fixed_01"
STL_FILE="debris_pattern_01.stl"

if [ ! -f "$STL_FILE" ]; then
    echo "ERROR: STL file $STL_FILE not found"
    exit 1
fi

rm -rf $TEST_DIR
mkdir -p $TEST_DIR
cd $TEST_DIR
mkdir -p 0 constant system

echo "Setting up case with corrected configuration..."

# Create corrected controlDict (copy from working case and modify)
cp ../clean_simpleFoam_test/system/controlDict system/
sed -i '' 's/endTime         500/endTime         5/' system/controlDict
sed -i '' 's/deltaT          1/deltaT          0.01/' system/controlDict
sed -i '' 's/writeInterval   50/writeInterval   250/' system/controlDict

# Create simple blockMeshDict
cp ../clean_simpleFoam_test/system/blockMeshDict system/

# Create snappyHexMeshDict (simplified)
cat > system/snappyHexMeshDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    object      snappyHexMeshDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

castellatedMesh true;
snap            true;
addLayers       false;

geometry
{
    debris.stl
    {
        type triSurfaceMesh;
        name debris;
    }
}

castellatedMeshControls
{
    maxLocalCells 200000;
    maxGlobalCells 500000;
    minRefinementCells 0;
    nCellsBetweenLevels 2;

    features ();

    refinementSurfaces
    {
        debris
        {
            level (1 1);
            patchInfo
            {
                type wall;
            }
        }
    }

    refinementRegions {}

    locationInMesh (0.1 0.1 0.1);
    allowFreeStandingZoneFaces true;
}

snapControls
{
    nSmoothPatch 3;
    tolerance 2.0;
    nSolveIter 30;
    nRelaxIter 5;
}

addLayersControls
{
    layers {}
    relativeSizes true;
    expansionRatio 1.0;
    finalLayerThickness 0.3;
    minThickness 0.1;
}

meshQualityControls
{
    maxNonOrtho 65;
    maxBoundarySkewness 20;
    maxInternalSkewness 4;
    maxConcave 80;
    minVol 1e-13;
    minTetTetRatio 0.1;
}

debug 0;
mergeTolerance 1e-6;
EOF

# Copy solver settings  
cp ../fixed_simpleFoam_settings/fvSchemes system/
cp ../fixed_simpleFoam_settings/fvSolution system/

# Create initial fields with debris boundary
cat > 0/U << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volVectorField;
    object      U;
}
dimensions      [0 1 -1 0 0 0 0];
internalField   uniform (0.1 0 0);
boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform (2 0 0);
    }
    outlet
    {
        type            inletOutlet;
        inletValue      uniform (0 0 0);
        value           uniform (2 0 0);
    }
    ground
    {
        type            fixedValue;
        value           uniform (0 0 0);
    }
    atmosphere
    {
        type            slip;
    }
    sides
    {
        type            fixedValue;
        value           uniform (0 0 0);
    }
    debris
    {
        type            fixedValue;
        value           uniform (0 0 0);
    }
}
EOF

cat > 0/p << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volScalarField;
    object      p;
}
dimensions      [0 2 -2 0 0 0 0];
internalField   uniform 0;
boundaryField
{
    inlet
    {
        type            zeroGradient;
    }
    outlet
    {
        type            fixedValue;
        value           uniform 0;
    }
    ground
    {
        type            zeroGradient;
    }
    atmosphere
    {
        type            zeroGradient;
    }
    sides
    {
        type            zeroGradient;
    }
    debris
    {
        type            zeroGradient;
    }
}
EOF

# Copy physical properties
cp ../clean_simpleFoam_test/constant/physicalProperties constant/
cp ../clean_simpleFoam_test/constant/momentumTransport constant/

# Copy STL file
cp "../$STL_FILE" constant/debris.stl

echo "Starting simulation..."
START_TIME=$(date +%s)

# Step 1: Background mesh
echo "1. Creating background mesh..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; blockMesh" > log.blockMesh 2>&1

if [ ! -f "constant/polyMesh/points" ]; then
    echo "ERROR: blockMesh failed"
    tail -10 log.blockMesh
    exit 1
fi
echo "✅ Background mesh OK"

# Step 2: Mesh with debris
echo "2. Adding debris to mesh..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; snappyHexMesh -overwrite" > log.snappyHexMesh 2>&1

# Check snappyHexMesh result
if ! grep -q "Finished meshing" log.snappyHexMesh; then
    echo "WARNING: snappyHexMesh may have issues"
    tail -20 log.snappyHexMesh
fi
echo "✅ Debris mesh attempted"

# Step 3: Check mesh
echo "3. Checking mesh quality..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; checkMesh" > log.checkMesh 2>&1

# Step 4: Run simulation
echo "4. Running simpleFoam (0-5 seconds)..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; simpleFoam" > log.simpleFoam 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== Results ==="
echo "Execution time: ${DURATION} seconds"

# Check results
if [ -d "5" ]; then
    echo "✅ Final time step (t=5s) reached"
    
    if [ -f "5/U" ]; then
        echo "✅ Velocity field generated"
        U_SAMPLE=$(head -30 5/U | grep "(" | head -3 | awk -F'[(),]' '{print "(" $2 "," $3 "," $4 ")"}')
        echo "Sample U values: $U_SAMPLE"
    fi
    
    if [ -f "5/p" ]; then
        echo "✅ Pressure field generated"  
        P_SAMPLE=$(head -30 5/p | grep -E "^-?[0-9]" | head -3 | paste -sd "," -)
        echo "Sample p values: $P_SAMPLE"
    fi
    
    # Check if debris affected the flow
    DEBRIS_BOUNDARY=$(grep -c "debris" 5/U 5/p 2>/dev/null || echo 0)
    if [ $DEBRIS_BOUNDARY -gt 0 ]; then
        echo "✅ Debris boundary detected in solution"
    else
        echo "⚠️  No debris boundary in final solution"
    fi
    
else
    echo "❌ Simulation did not reach t=5s"
    echo "Available time directories:"
    ls -d [0-9]* 2>/dev/null || echo "None"
    
    echo ""
    echo "Checking for errors:"
    if grep -q "ERROR" log.simpleFoam; then
        grep "ERROR" log.simpleFoam
    fi
fi

# Check convergence
echo ""
echo "Convergence info:"
tail -20 log.simpleFoam | grep -E "(ExecutionTime|Final residual)" | tail -5

echo ""
echo "Case directory: $(pwd)"
echo "Key files: 5/U, 5/p (if successful)"
echo "STL: constant/debris.stl"

cd ..
echo "Test complete!"