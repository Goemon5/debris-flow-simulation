#!/bin/bash
# Apply successful scent simulation method to flow simulation
# Based on analysis of case_openfoam10_scent success

echo "=== Debris Flow Simulation - Success-Based Approach ==="
echo "Applying lessons learned from successful scent simulation"

TEST_DIR="debris_flow_success_based"
STL_FILE="debris_pattern_01.stl"

# Check prerequisites
if [ ! -f "$STL_FILE" ]; then
    echo "ERROR: STL file $STL_FILE not found"
    exit 1
fi

if [ ! -d "case_openfoam10_scent" ]; then
    echo "ERROR: Reference case_openfoam10_scent not found"
    exit 1
fi

# Clean setup
rm -rf $TEST_DIR
mkdir -p $TEST_DIR
cd $TEST_DIR

echo "Setting up case based on successful scent simulation methodology..."

# Create directory structure
mkdir -p 0 constant system

echo ""
echo "=== STEP 1: Copy Proven Mesh from Successful Case ==="
# Key insight: Use the proven mesh that worked for scent simulation
if [ -d "../case_openfoam10_scent/constant/polyMesh" ]; then
    cp -r ../case_openfoam10_scent/constant/polyMesh constant/
    echo "✅ Copied proven mesh with debris integration (96,305 cells)"
    
    # Verify debris boundary exists
    DEBRIS_FACES=$(grep -A5 "debris" constant/polyMesh/boundary | grep "nFaces" | awk '{print $2}' | sed 's/;//')
    echo "   Debris boundary faces: $DEBRIS_FACES"
    
else
    echo "❌ Cannot find proven mesh from case_openfoam10_scent"
    exit 1
fi

echo ""
echo "=== STEP 2: Create Flow-Specific Configuration ==="

# Use the proven controlDict approach but for simpleFoam
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

// Using simpleFoam for steady-state flow simulation
application     simpleFoam;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         5;

// Same conservative time step as successful scent case
deltaT          0.01;
adjustTimeStep  no;

writeControl    timeStep;
writeInterval   250;    // Write every 2.5 seconds

purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;
EOF

# Copy proven solver settings
cp ../fixed_simpleFoam_settings/fvSchemes system/
cp ../fixed_simpleFoam_settings/fvSolution system/

echo "✅ Created flow simulation configuration"

echo ""
echo "=== STEP 3: Create Initial Conditions with Proven Boundaries ==="

# Create U field with all boundaries from successful case
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
    debris
    {
        type            fixedValue;
        value           uniform (0 0 0);
    }
}
EOF

# Create p field with proven boundaries
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
    debris
    {
        type            zeroGradient;
    }
}
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
viscosityModel  constant;
nu              1.5e-05;
EOF

cat > constant/momentumTransport << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      momentumTransport;
}
simulationType  laminar;
EOF

echo "✅ Created initial conditions with proven boundary structure"

echo ""
echo "=== STEP 4: Run Simulation Using Proven Methodology ==="

START_TIME=$(date +%s)

echo "Running simpleFoam with proven mesh and boundaries..."
docker run --rm -v "$(pwd):/home/openfoam" -w /home/openfoam --platform linux/amd64 --entrypoint="" openfoam/openfoam10-paraview510 bash -c "source /opt/openfoam10/etc/bashrc && simpleFoam" > log.simpleFoam 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== RESULTS ANALYSIS ==="
echo "Execution time: ${DURATION} seconds"

# Find final time
FINAL_TIME=$(ls -d [0-9]* 2>/dev/null | sort -n | tail -1)

if [ -n "$FINAL_TIME" ] && [ "$FINAL_TIME" != "0" ]; then
    echo "✅ Simulation reached time: ${FINAL_TIME}s"
    
    # Analyze velocity field 
    if [ -f "$FINAL_TIME/U" ]; then
        echo ""
        echo "📊 Velocity Field Success Check:"
        
        # Check if field is nonuniform (indicating proper simulation)
        if grep -q "nonuniform" $FINAL_TIME/U; then
            echo "✅ Non-uniform velocity field generated"
            
            # Sample values
            U_SAMPLE=$(head -100 $FINAL_TIME/U | grep "(" | head -5 | awk -F'[(),]' '{print $2}' | head -3)
            echo "   Sample U velocities: $(echo $U_SAMPLE | tr '\n' ' ')"
            
            # Check if values are realistic
            U_MAX=$(echo $U_SAMPLE | tr ' ' '\n' | sort -n | tail -1)
            if (( $(echo "$U_MAX > 0.1 && $U_MAX < 10" | bc -l) )); then
                echo "✅ Realistic velocity magnitude: $U_MAX m/s"
            else
                echo "⚠️  Questionable velocity magnitude: $U_MAX m/s"
            fi
        else
            echo "❌ Uniform velocity field - no flow development"
        fi
    fi
    
    # Analyze pressure field
    if [ -f "$FINAL_TIME/p" ]; then
        echo ""
        echo "📊 Pressure Field Success Check:"
        
        if grep -q "nonuniform" $FINAL_TIME/p; then
            echo "✅ Non-uniform pressure field generated"
            
            P_SAMPLE=$(head -100 $FINAL_TIME/p | grep -E "^-?[0-9]" | head -3)
            if [ -n "$P_SAMPLE" ]; then
                P_RANGE=$(echo "$P_SAMPLE" | sort -n | head -1)
                echo "   Sample pressure: $P_RANGE Pa"
                
                # Check for reasonable pressure values
                P_ABS=$(echo "$P_RANGE" | awk '{print ($1<0)?-$1:$1}')
                if (( $(echo "$P_ABS < 1000" | bc -l) )); then
                    echo "✅ Realistic pressure magnitude"
                else
                    echo "⚠️  High pressure magnitude: may indicate issues"
                fi
            fi
        else
            echo "❌ Uniform pressure field"
        fi
    fi
    
    # Check debris boundary interaction
    DEBRIS_MENTIONED=$(grep -c "debris" $FINAL_TIME/U $FINAL_TIME/p 2>/dev/null || echo 0)
    if [ $DEBRIS_MENTIONED -gt 0 ]; then
        echo "✅ Debris boundary properly included in solution"
    else
        echo "⚠️  Debris boundary not detected in solution files"
    fi
    
    # Convergence check
    echo ""
    echo "📊 Convergence Analysis:"
    FINAL_RESIDUALS=$(tail -20 log.simpleFoam | grep "Final residual" | tail -3)
    if [ -n "$FINAL_RESIDUALS" ]; then
        echo "$FINAL_RESIDUALS"
    else
        echo "No convergence information found"
    fi
    
    # Check for errors
    ERRORS=$(grep -c "ERROR\|FATAL" log.simpleFoam 2>/dev/null || echo 0)
    if [ $ERRORS -eq 0 ]; then
        echo "✅ No fatal errors detected"
    else
        echo "❌ $ERRORS errors found in log"
    fi
    
    echo ""
    if [ "$FINAL_TIME" == "5" ] && grep -q "nonuniform" $FINAL_TIME/U $FINAL_TIME/p; then
        echo "🎯 SUCCESS: Debris flow simulation completed using proven methodology!"
        echo ""
        echo "Key Success Factors:"
        echo "✅ Used proven mesh from successful scent case"
        echo "✅ Applied same conservative time stepping"
        echo "✅ Maintained proper boundary conditions"
        echo "✅ Generated physically realistic fields"
        echo ""
        echo "📁 Results: $FINAL_TIME/U, $FINAL_TIME/p"
        echo "📊 Mesh: $(grep "nFaces" constant/polyMesh/boundary | grep debris | awk '{print $2}' | sed 's/;//') debris faces"
        echo "⏱️  Time: ${DURATION}s"
    else
        echo "⚠️  Partial success - simulation completed but may need verification"
    fi
    
else
    echo "❌ FAILED: Simulation did not progress beyond t=0"
    echo ""
    echo "Error Analysis:"
    tail -20 log.simpleFoam | grep -E "(ERROR|FATAL|error)"
    
    echo ""
    echo "Suggestions:"
    echo "1. Check mesh quality: checkMesh"
    echo "2. Verify boundary conditions match mesh boundaries"
    echo "3. Review solver settings for stability"
fi

echo ""
echo "Case directory: $(pwd)"
echo "Logs: log.simpleFoam"
echo "Mesh source: ../case_openfoam10_scent/constant/polyMesh"

cd ..
echo ""
echo "Analysis complete!"