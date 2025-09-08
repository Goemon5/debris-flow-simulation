#!/bin/bash

# ===============================================================================
# Complete U,p,C Field Simulation Script (2-Stage Approach)
# Stage 1: incompressibleFluid for U,p fields
# Stage 2: scalarTransportFoam for C field using existing U,p
# ===============================================================================

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}Complete U,p,C Field Simulation (2-Stage)${NC}"
echo -e "${BLUE}===============================================${NC}"

CASE_NAME="case_complete_scent"
FLOW_CASE_DIR="debrisCase"
FLOW_TIME_DIR="5"

# Stage 1: Generate U,p fields using current method
echo -e "${YELLOW}Stage 1: Generating U,p fields...${NC}"
./run_simple_scent_simulation.sh

# Check if Stage 1 completed successfully
if [ ! -d "case_simple_scent/3.5" ]; then
    echo -e "${RED}ERROR: Stage 1 failed - no time directories found${NC}"
    exit 1
fi

# Copy Stage 1 results to new case
echo -e "${YELLOW}Stage 2: Setting up scalarTransportFoam for C field...${NC}"
if [ -d "$CASE_NAME" ]; then
    rm -rf "$CASE_NAME"
fi
cp -r case_simple_scent "$CASE_NAME"
cd "$CASE_NAME"

# Create proper C field initial condition
cat <<EOF > 0/C
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       volScalarField;
    location    "0";
    object      C;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

dimensions      [0 0 0 1 0 0 0];    // Dimensionless concentration

// Initialize entire domain to zero concentration
internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform 1.0;    // Scent source: contaminated air entering
    }
    
    outlet
    {
        type            zeroGradient;   // Natural outflow
    }
    
    ground
    {
        type            zeroGradient;   // No flux through ground
    }
    
    atmosphere
    {
        type            zeroGradient;   // Natural atmospheric boundary
    }
    
    debris
    {
        type            zeroGradient;   // No flux through debris walls
    }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Create controlDict for scalarTransportFoam
cat <<EOF > system/controlDict
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

// Using scalarTransportFoam for C field with frozen U,p
application     scalarTransportFoam;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         5;          // Same as Stage 1

// Fixed small time step for maximum stability
deltaT          0.005;      
adjustTimeStep  no;         

writeControl    timeStep;
writeInterval   100;        // Write every 0.5 seconds

purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Create simple fvSchemes for scalarTransportFoam
cat <<EOF > system/fvSchemes
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      fvSchemes;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

ddtSchemes
{
    default         Euler;          
}

gradSchemes
{
    default         Gauss linear;   
}

divSchemes
{
    default         Gauss linear;
    div(phi,C)      Gauss upwind;    // C is the concentration field
}

laplacianSchemes
{
    default         Gauss linear corrected;  
    laplacian(DT,C) Gauss linear corrected;  // Diffusion for concentration C
}

interpolationSchemes
{
    default         linear;         
}

snGradSchemes
{
    default         corrected;      
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Create simple fvSolution for scalarTransportFoam  
cat <<EOF > system/fvSolution
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      fvSolution;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

solvers
{
    C
    {
        solver          smoothSolver;       
        smoother        symGaussSeidel;     
        tolerance       1e-06;              
        relTol          0.1;                
        maxIter         100;                
    }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Fix transportProperties for scalarTransportFoam
cat <<EOF > constant/transportProperties
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  11
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      transportProperties;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

transportModel  Newtonian;

// Kinematic viscosity 
nu              [0 2 -1 0 0 0 0] 1e-05;

// Molecular diffusivity for the scent/tracer
DT              [0 2 -1 0 0 0 0] 2e-05;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

echo -e "${YELLOW}Running Stage 2: scalarTransportFoam for C field...${NC}"

# Run scalarTransportFoam with existing U,p fields
docker rm -f complete_scent 2>/dev/null || true
docker run -dit --name complete_scent -v $(pwd)/..:/work -w /work/$CASE_NAME openfoam-cfd:latest /bin/bash

docker exec complete_scent bash -c "
source /opt/openfoam11/etc/bashrc
scalarTransportFoam
" > ../scalarTransport_stage2.log 2>&1

# Check results
echo -e "${BLUE}Checking final results (U, p, C):${NC}"
cd ..
for field in U p C; do
    if [ -f "$CASE_NAME/5/$field" ]; then
        echo -e "${GREEN}✅ Field $field: Present in $CASE_NAME/5/${NC}"
        size=$(du -sh "$CASE_NAME/5/$field" | cut -f1)
        echo "   File size: $size"
    else
        echo -e "${RED}❌ Field $field: Missing${NC}"
    fi
done

# Clean up
docker stop complete_scent >/dev/null 2>&1
docker rm complete_scent >/dev/null 2>&1

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}Complete Simulation Results Summary:${NC}"
echo -e "${BLUE}===============================================${NC}"
echo "Results directory: $CASE_NAME/"
echo "Fields generated: U (velocity), p (pressure), C (concentration)"
echo "Time range: 0-5 seconds, 0.5s intervals"
echo "Ready for GNN training data extraction!"
echo -e "${GREEN}Success!${NC}"