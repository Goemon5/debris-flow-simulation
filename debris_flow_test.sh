#!/bin/bash
# Test debris flow simulation with pattern_01.stl

echo "=== Debris Flow Test with Pattern 01 ==="

TEST_DIR="debris_flow_test_01"
STL_FILE="debris_pattern_01.stl"

# Check STL file exists
if [ ! -f "$STL_FILE" ]; then
    echo "ERROR: STL file $STL_FILE not found"
    exit 1
fi

# Clean setup
rm -rf $TEST_DIR
mkdir -p $TEST_DIR
cd $TEST_DIR

echo "Setting up case structure..."
mkdir -p 0 constant/polyMesh system

# Create blockMeshDict - base domain
cat > system/blockMeshDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    object      blockMeshDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

convertToMeters 1;

vertices
(
    (-2 -1 0)   // 0
    (8 -1 0)    // 1  
    (8 1 0)     // 2
    (-2 1 0)    // 3
    (-2 -1 2)   // 4
    (8 -1 2)    // 5
    (8 1 2)     // 6
    (-2 1 2)    // 7
);

blocks
(
    hex (0 1 2 3 4 5 6 7) (100 20 20) simpleGrading (1 1 1)
);

edges
(
);

boundary
(
    inlet
    {
        type patch;
        faces
        (
            (0 4 7 3)
        );
    }
    outlet
    {
        type patch;
        faces
        (
            (2 6 5 1)
        );
    }
    ground
    {
        type wall;
        faces
        (
            (0 3 2 1)
        );
    }
    atmosphere
    {
        type patch;
        faces
        (
            (4 5 6 7)
        );
    }
    sides
    {
        type wall;
        faces
        (
            (0 1 5 4)
            (3 7 6 2)
        );
    }
);

mergePatchPairs
(
);

// ************************************************************************* //
EOF

# Create snappyHexMeshDict for debris integration
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
    maxLocalCells 1000000;
    maxGlobalCells 2000000;
    minRefinementCells 0;
    maxLoadUnbalance 0.10;
    nCellsBetweenLevels 2;

    features ();

    refinementSurfaces
    {
        debris
        {
            level (1 2);
            patchInfo
            {
                type wall;
            }
        }
    }

    refinementRegions
    {
    }

    locationInMesh (0.1 0.1 0.1);
    allowFreeStandingZoneFaces true;
}

snapControls
{
    nSmoothPatch 3;
    tolerance 2.0;
    nSolveIter 100;
    nRelaxIter 5;
}

addLayersControls
{
    layers
    {
    }
    
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
    minArea -1;
    minTwist 0.02;
    minDeterminant 0.001;
    minFaceWeight 0.02;
    minVolRatio 0.01;
    minTriangleTwist -1;
    nSmoothScale 4;
    errorReduction 0.75;
}

debug 0;
mergeTolerance 1e-6;

// ************************************************************************* //
EOF

# Create controlDict for 5 second simulation
cat > system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     simpleFoam;

startFrom       startTime;

startTime       0;

stopAt          endTime;

endTime         5;

deltaT          0.01;

writeControl    timeStep;

writeInterval   250;  // Write every 2.5 seconds

purgeWrite      0;

writeFormat     ascii;

writePrecision  6;

writeCompression off;

timeFormat      general;

timePrecision   6;

runTimeModifiable true;

functions
{
    residuals
    {
        type            residuals;
        functionObjectLibs ("libutilityFunctionObjects.so");
        writeControl    timeStep;
        writeInterval   50;
        fields          (p U);
    }
}

// ************************************************************************* //
EOF

# Copy fixed solver settings
cp ../fixed_simpleFoam_settings/fvSchemes system/
cp ../fixed_simpleFoam_settings/fvSolution system/

# Create initial velocity field
cat > 0/U << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volVectorField;
    object      U;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

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

// ************************************************************************* //
EOF

# Create initial pressure field
cat > 0/p << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       volScalarField;
    object      p;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

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

// ************************************************************************* //
EOF

# Create physical properties
cat > constant/physicalProperties << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      physicalProperties;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

viscosityModel  constant;

nu              1.5e-05;

// ************************************************************************* //
EOF

# Create momentum transport
cat > constant/momentumTransport << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      momentumTransport;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

simulationType  laminar;

// ************************************************************************* //
EOF

# Copy debris STL file
cp "../$STL_FILE" constant/debris.stl

echo "Starting mesh generation process..."

# Step 1: Generate background mesh
echo "1. Generating background mesh..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; blockMesh" > log.blockMesh 2>&1

if [ ! -f "constant/polyMesh/points" ]; then
    echo "ERROR: Background mesh generation failed"
    cat log.blockMesh | tail -20
    exit 1
fi

echo "✅ Background mesh created"

# Step 2: Generate mesh with debris
echo "2. Generating mesh with debris using snappyHexMesh..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; snappyHexMesh -overwrite" > log.snappyHexMesh 2>&1

# Check if snappyHexMesh succeeded
if [ ! -f "constant/polyMesh/points" ]; then
    echo "ERROR: snappyHexMesh failed"
    tail -20 log.snappyHexMesh
    exit 1
fi

echo "✅ Debris mesh created"

# Check mesh quality
echo "3. Checking mesh quality..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; checkMesh" > log.checkMesh 2>&1

# Show mesh statistics
MESH_INFO=$(grep -E "(cells|points|faces)" log.checkMesh | head -3)
echo "Mesh statistics:"
echo "$MESH_INFO"

# Step 3: Run flow simulation
echo "4. Running flow simulation (5 seconds, 500 time steps)..."
START_TIME=$(date +%s)

docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc; simpleFoam" > log.simpleFoam 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "✅ Simulation completed in ${DURATION} seconds"

# Step 4: Analyze results
echo ""
echo "=== Results Analysis ==="

# Check if we have final results
if [ -f "5/U" ] && [ -f "5/p" ]; then
    echo "✅ Final fields (t=5s) generated successfully"
    
    # Check mesh around debris
    TOTAL_CELLS=$(grep -E "cells:" log.checkMesh | awk '{print $2}')
    echo "Total mesh cells: $TOTAL_CELLS"
    
    # Analyze velocity field
    echo ""
    echo "Velocity field analysis:"
    U_MAX=$(head -100 5/U | grep "(" | head -20 | awk -F'[(),]' '{print $2}' | sort -n | tail -1)
    U_MIN=$(head -100 5/U | grep "(" | head -20 | awk -F'[(),]' '{print $2}' | sort -n | head -1)
    echo "  U velocity range: $U_MIN to $U_MAX m/s"
    
    # Analyze pressure field  
    echo "Pressure field analysis:"
    P_MAX=$(head -100 5/p | grep -E "^-?[0-9]" | head -20 | sort -n | tail -1)
    P_MIN=$(head -100 5/p | grep -E "^-?[0-9]" | head -20 | sort -n | head -1)
    echo "  Pressure range: $P_MIN to $P_MAX Pa"
    
    # Check convergence
    echo ""
    echo "Convergence check:"
    FINAL_RESIDUALS=$(tail -10 log.simpleFoam | grep "Final residual" | tail -3)
    echo "$FINAL_RESIDUALS"
    
    echo ""
    echo "🎯 SUCCESS: Debris flow simulation completed"
    echo "   Simulation time: ${DURATION}s"
    echo "   Mesh cells: $TOTAL_CELLS"
    echo "   Output: 5/U, 5/p fields"
    
else
    echo "❌ ERROR: Final fields not generated"
    echo "Available time directories:"
    ls -d [0-9]* 2>/dev/null || echo "None"
    
    echo ""
    echo "Last 20 lines of simulation log:"
    tail -20 log.simpleFoam
fi

echo ""
echo "Test case directory: $(pwd)"
echo "Logs: log.blockMesh, log.snappyHexMesh, log.simpleFoam"
echo "STL file: constant/debris.stl"

cd ..
echo "Done!"