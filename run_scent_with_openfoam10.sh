#!/bin/bash

# ===============================================================================
# Scent Simulation with OpenFOAM 10 (scalarTransportFoam available)
# Goal: Generate U, p, C fields using OpenFOAM 10
# ===============================================================================

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}Scent Simulation with OpenFOAM 10${NC}"
echo -e "${BLUE}===============================================${NC}"

# Configuration
CASE_NAME="case_openfoam10_scent"
FLOW_CASE_DIR="debrisCase"
FLOW_TIME_DIR="5"

# Clean and create new case directory
echo -e "${YELLOW}Step 1: Setting up clean case directory...${NC}"
if [ -d "$CASE_NAME" ]; then
    rm -rf "$CASE_NAME"
    echo "Removed existing $CASE_NAME directory"
fi
mkdir -p "$CASE_NAME"
echo -e "${GREEN}Created clean case directory: $CASE_NAME${NC}"

# Create directory structure
mkdir -p "$CASE_NAME/0"
mkdir -p "$CASE_NAME/constant"
mkdir -p "$CASE_NAME/system"

# Step 2: Copy mesh and flow field data
echo -e "${YELLOW}Step 2: Copying mesh and flow field data...${NC}"

# Copy mesh
if [ -d "$FLOW_CASE_DIR/constant/polyMesh" ]; then
    cp -r "$FLOW_CASE_DIR/constant/polyMesh" "$CASE_NAME/constant/"
    echo -e "${GREEN}Copied mesh from $FLOW_CASE_DIR/constant/polyMesh${NC}"
else
    echo -e "${RED}Error: Mesh not found in $FLOW_CASE_DIR/constant/polyMesh${NC}"
    exit 1
fi

# Copy velocity field from final time step
if [ -f "$FLOW_CASE_DIR/$FLOW_TIME_DIR/U" ]; then
    cp "$FLOW_CASE_DIR/$FLOW_TIME_DIR/U" "$CASE_NAME/0/"
    echo -e "${GREEN}Copied velocity field from $FLOW_CASE_DIR/$FLOW_TIME_DIR/U${NC}"
else
    echo -e "${RED}Error: Velocity field not found in $FLOW_CASE_DIR/$FLOW_TIME_DIR/U${NC}"
    exit 1
fi

# Copy pressure field for completeness (optional but good practice)
if [ -f "$FLOW_CASE_DIR/$FLOW_TIME_DIR/p" ]; then
    cp "$FLOW_CASE_DIR/$FLOW_TIME_DIR/p" "$CASE_NAME/0/"
    echo -e "${GREEN}Copied pressure field from $FLOW_CASE_DIR/$FLOW_TIME_DIR/p${NC}"
fi

# Step 3: Create controlDict for scalarTransportFoam
echo -e "${YELLOW}Step 3: Creating controlDict...${NC}"
cat <<EOF > "$CASE_NAME/system/controlDict"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
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

// Using scalarTransportFoam - available in OpenFOAM 10
application     scalarTransportFoam;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         5;          // Short 5-second simulation

// Fixed small time step for maximum stability
deltaT          0.005;      // Very conservative time step
adjustTimeStep  no;         // Fixed time step prevents instabilities

writeControl    timeStep;
writeInterval   100;        // Write every 0.5 seconds (100 * 0.005)

purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Step 4: Create fvSchemes for scalarTransportFoam
echo -e "${YELLOW}Step 4: Creating fvSchemes...${NC}"
cat <<EOF > "$CASE_NAME/system/fvSchemes"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
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

// Conservative, stable numerical schemes for scalarTransportFoam
ddtSchemes
{
    default         Euler;          // First-order implicit, very stable
}

gradSchemes
{
    default         Gauss linear;   // Standard linear gradient
}

divSchemes
{
    default         Gauss linear;   // Most stable convection scheme
    div(phi,T)      Gauss upwind;   // Upwind for scalar transport (very stable)
}

laplacianSchemes
{
    default         Gauss linear corrected;  // Standard diffusion scheme
    laplacian(DT,T) Gauss linear corrected;  // Diffusion for scalar T
}

interpolationSchemes
{
    default         linear;         // Linear interpolation
}

snGradSchemes
{
    default         corrected;      // Standard surface normal gradient
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Step 5: Create fvSolution for scalarTransportFoam
echo -e "${YELLOW}Step 5: Creating fvSolution...${NC}"
cat <<EOF > "$CASE_NAME/system/fvSolution"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
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

// Solver settings for scalar T (scalarTransportFoam in OpenFOAM 10)
solvers
{
    T
    {
        solver          smoothSolver;       // Robust iterative solver
        smoother        symGaussSeidel;     // Stable smoother
        tolerance       1e-06;              // Reasonable convergence criterion
        relTol          0.1;                // Allow some relative tolerance for stability
        maxIter         100;                // Prevent excessive iterations
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 0;
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Step 6: Create physicalProperties (required by OpenFOAM 10 scalarTransportFoam)
echo -e "${YELLOW}Step 6: Creating physicalProperties...${NC}"
cat <<EOF > "$CASE_NAME/constant/physicalProperties"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      physicalProperties;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

// Molecular diffusivity for the scent/tracer (OpenFOAM 10 format)
DT              DT [0 2 -1 0 0 0 0] 2e-05;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Step 7: Create transportProperties (backup)
echo -e "${YELLOW}Step 7: Creating transportProperties...${NC}"
cat <<EOF > "$CASE_NAME/constant/transportProperties"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
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

// Transport properties for passive scalar
transportModel  Newtonian;

// Kinematic viscosity (from original flow simulation)
nu              [0 2 -1 0 0 0 0] 1e-05;

// Molecular diffusivity for the scent/tracer
// Using realistic value for typical gas-phase molecular diffusion
DT              [0 2 -1 0 0 0 0] 2e-05;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

# Step 8: Create initial condition for T (scalar field)
echo -e "${YELLOW}Step 8: Creating initial and boundary conditions for T...${NC}"
cat <<EOF > "$CASE_NAME/0/T"
/*--------------------------------*- C++ -*----------------------------------*\\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       volScalarField;
    location    "0";
    object      T;
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

# Step 9: Run the simulation using Docker with OpenFOAM 10
echo -e "${YELLOW}Step 9: Running simulation with OpenFOAM 10...${NC}"

echo -e "${BLUE}Starting 5-second scent transport simulation...${NC}"
echo "Command: scalarTransportFoam (OpenFOAM 10)"
echo "Case directory: $(pwd)/$CASE_NAME"
echo "Start time: $(date)"

# Setup and run Docker container
echo "Setting up OpenFOAM 10 Docker container..."
docker rm -f openfoam10_scent 2>/dev/null || true
docker run -dit --name openfoam10_scent -v $(pwd):/work -w /work/$CASE_NAME openfoam/openfoam10-paraview510 /bin/bash >/dev/null 2>&1

# Run the simulation with output capture
echo "Running scalarTransportFoam simulation..."
if docker exec openfoam10_scent bash -c "
source /opt/openfoam10/etc/bashrc >/dev/null 2>&1
scalarTransportFoam
" > scent_openfoam10.log 2>&1; then
    echo -e "${GREEN}SUCCESS: Simulation completed without errors!${NC}"
    echo -e "${GREEN}Simulation log saved to: scent_openfoam10.log${NC}"
    
    # Check if final time directory was created
    if [ -d "5" ]; then
        echo -e "${GREEN}Final time directory '5' created successfully${NC}"
        echo "Available time directories:"
        ls -1 | grep -E '^[0-9]+\.?[0-9]*$' | sort -n
        
        # Check all required fields exist
        echo -e "${BLUE}Checking required fields (U, p, T):${NC}"
        for field in U p T; do
            if [ -f "5/$field" ]; then
                echo -e "${GREEN}✅ Field $field: Present${NC}"
                size=$(du -sh "5/$field" | cut -f1)
                echo "   File size: $size"
                
                # Quick value check for T field
                if [ "$field" = "T" ]; then
                    MAX_VAL=$(docker exec openfoam10_scent bash -c "
                        source /opt/openfoam10/etc/bashrc >/dev/null 2>&1
                        head -50 5/T | tail -10 | grep -oE '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' | sort -n | tail -1 || echo '0'
                    ")
                    echo "   Max T value sample: $MAX_VAL"
                fi
            else
                echo -e "${RED}❌ Field $field: Missing${NC}"
            fi
        done
        
    else
        echo -e "${YELLOW}Warning: Final time directory not found${NC}"
    fi
    
    # Clean up Docker container
    docker stop openfoam10_scent >/dev/null 2>&1
    docker rm openfoam10_scent >/dev/null 2>&1
    
else
    echo -e "${RED}ERROR: Simulation failed!${NC}"
    echo -e "${RED}Check the log file: scent_openfoam10.log${NC}"
    echo "Last 20 lines of log:"
    tail -20 scent_openfoam10.log
    
    # Clean up Docker container
    docker stop openfoam10_scent >/dev/null 2>&1
    docker rm openfoam10_scent >/dev/null 2>&1
    exit 1
fi

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}OpenFOAM 10 Scent Simulation Completed!${NC}"
echo -e "${BLUE}===============================================${NC}"
echo
echo "Summary:"
echo "- Case created: $CASE_NAME"
echo "- OpenFOAM version: 10 (scalarTransportFoam available)"
echo "- Solver used: scalarTransportFoam"
echo "- Simulation time: 0-5 seconds"
echo "- Fields generated: U (velocity), p (pressure), T (concentration)"
echo
echo "Results directory: $CASE_NAME/"
echo -e "${GREEN}Ready for GNN development with all three fields!${NC}"