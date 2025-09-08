#!/bin/bash

# ===============================================================================
# Automated 90-Case Scent Simulation System
# 30 debris patterns × 3 source locations = 90 total simulations
# Parallel execution with OpenFOAM 10 scalarTransportFoam
# ===============================================================================

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}90-Case Automated Scent Simulation System${NC}"
echo -e "${BLUE}===============================================${NC}"

# ===============================================================================
# CONFIGURATION SECTION
# ===============================================================================

# Execution parameters
MAX_JOBS=4              # Maximum parallel jobs (adjust based on system resources)
FLOW_CASE_DIR="debrisCase"
FLOW_TIME_DIR="5"

# Define the 3 odor source locations as per requirements (Bash 3.2 compatible)
SOURCES_center="(7.5 7.5 0.5)"   # Center position
SOURCES_upwind="(5.0 7.5 1.0)"   # Upwind position  
SOURCES_side="(7.5 5.0 1.5)"     # Side position
SOURCES_LIST="center upwind side"

# Pattern range (patterns 1-30)
PATTERN_START=1
PATTERN_END=30

# Output organization
RESULTS_BASE_DIR="simulation_results_90cases"
LOG_DIR="logs_90cases"

# ===============================================================================
# INITIALIZATION
# ===============================================================================

# Create output directories
echo -e "${YELLOW}Setting up directory structure...${NC}"
mkdir -p "$RESULTS_BASE_DIR"
mkdir -p "$LOG_DIR"

# Cleanup function for interrupted runs
cleanup() {
    echo -e "\n${YELLOW}Cleaning up running jobs...${NC}"
    jobs -p | xargs -r kill 2>/dev/null
    docker ps -a --filter name=openfoam10_auto --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null
    exit 1
}
trap cleanup INT TERM

# Job tracking arrays  
RUNNING_JOBS=()
JOB_PIDS=()

# ===============================================================================
# UTILITY FUNCTIONS FOR CONFIGURATION FILES
# ===============================================================================

# Function to create fvOptions with dynamic odor source
create_fv_options() {
    local case_dir=$1
    local source_coords=$2
    local source_name=$3
    
    cat > "$case_dir/system/fvOptions" << EOF
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
    object      fvOptions;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

scent_source_$source_name
{
    type            semiImplicitSource;
    active          yes;

    semiImplicitSourceCoeffs
    {
        selectionMode   points;
        points          
        (
            $source_coords
        );
        
        volumeMode      absolute;
        
        sources
        {
            T
            {
                explicit    1e5;    // Source term value (kg/m3/s)
                implicit    0;      // No implicit part
            }
        }
    }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF
}

# Function to create topoSetDict for source region
create_topo_set_dict() {
    local case_dir=$1
    local source_coords=$2
    local source_name=$3
    
    cat > "$case_dir/system/topoSetDict" << EOF
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
    object      topoSetDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

actions
(
    {
        name    scent_source_$source_name;
        type    cellSet;
        action  new;
        source  sphereToCell;
        sourceInfo
        {
            centre  $source_coords;
            radius  0.3;
        }
    }
);

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF
}

# ===============================================================================
# CORE SIMULATION FUNCTION
# ===============================================================================

run_single_simulation() {
    local pattern_dir=$1
    local source_name=$2
    
    # Get source coordinates using case statement (Bash 3.2 compatible)
    case $source_name in
        center)
            local source_coords="$SOURCES_center"
            ;;
        upwind)
            local source_coords="$SOURCES_upwind"
            ;;
        side)
            local source_coords="$SOURCES_side"
            ;;
        *)
            echo "Error: Unknown source name: $source_name"
            return 1
            ;;
    esac
    
    # Case naming: pattern_XX_source_NAME
    case_name="${pattern_dir}_${source_name}"
    case_dir="$RESULTS_BASE_DIR/$case_name"
    log_file="$LOG_DIR/${case_name}.log"
    
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Starting: $case_name${NC}" | tee -a "$log_file"
    
    # Validate pattern directory exists
    if [ ! -d "$pattern_dir" ]; then
        echo -e "${RED}ERROR: Pattern directory $pattern_dir not found${NC}" | tee -a "$log_file"
        return 1
    fi
    
    # Clean and create case directory
    rm -rf "$case_dir" 2>/dev/null
    mkdir -p "$case_dir"/{0,constant,system}
    
    # Copy mesh from pattern directory
    if [ -d "$pattern_dir/constant/polyMesh" ]; then
        cp -r "$pattern_dir/constant/polyMesh" "$case_dir/constant/" 2>>"$log_file"
    else
        echo -e "${RED}ERROR: Mesh not found in $pattern_dir/constant/polyMesh${NC}" | tee -a "$log_file"
        return 1
    fi
    
    # Copy velocity and pressure fields from pattern directory
    for field in U p; do
        if [ -f "$pattern_dir/$FLOW_TIME_DIR/$field" ]; then
            cp "$pattern_dir/$FLOW_TIME_DIR/$field" "$case_dir/0/" 2>>"$log_file"
        else
            echo -e "${RED}ERROR: Field $field not found in $pattern_dir/$FLOW_TIME_DIR/$field${NC}" | tee -a "$log_file"
            return 1
        fi
    done
    
    # Create configuration files with parameterized source
    create_fv_options "$case_dir" "$source_coords" "$source_name"
    create_topo_set_dict "$case_dir" "$source_coords" "$source_name"
    
    # Create controlDict
    cat > "$case_dir/system/controlDict" << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

application     scalarTransportFoam;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         5;

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

    # Create fvSchemes
    cat > "$case_dir/system/fvSchemes" << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
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
    div(phi,T)      Gauss upwind;
}

laplacianSchemes
{
    default         Gauss linear corrected;
    laplacian(DT,T) Gauss linear corrected;
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

    # Create fvSolution
    cat > "$case_dir/system/fvSolution" << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
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
    T
    {
        solver          smoothSolver;
        smoother        symGaussSeidel;
        tolerance       1e-06;
        relTol          0.1;
        maxIter         100;
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 0;
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

    # Create physicalProperties
    cat > "$case_dir/constant/physicalProperties" << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  10
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    format      ascii;
    class       dictionary;
    location    "constant";
    object      physicalProperties;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

DT              DT [0 2 -1 0 0 0 0] 2e-05;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF

    # Create initial condition for T with parameterized source
    # Parse coordinates from source_coord string "(x y z)"
    x_coord=$(echo $source_coord | sed 's/[()]//' | cut -d' ' -f1)
    y_coord=$(echo $source_coord | sed 's/[()]//' | cut -d' ' -f2)
    z_coord=$(echo $source_coord | sed 's/[()]//' | cut -d' ' -f3)
    
    cat > "$case_dir/0/T" << EOF
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

dimensions      [0 0 0 1 0 0 0];

// Initialize entire domain to zero concentration
internalField   uniform 0;

boundaryField
{
    inlet
    {
        type            fixedValue;
        value           uniform 1.0;    // Source location: $source_name at $source_coord
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

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
EOF
    
    # Run simulation using Docker
    container_name="openfoam10_auto_${pattern_dir}_${source_name}"
    
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Running simulation: $case_name${NC}" >> "$log_file"
    
    # Setup Docker container
    docker rm -f "$container_name" 2>/dev/null || true
    docker run -dit --name "$container_name" \
        -v "$(pwd):/work" \
        -w "/work/$case_dir" \
        openfoam/openfoam10-paraview510 /bin/bash >/dev/null 2>&1
    
    # Run simulation
    if docker exec "$container_name" bash -c "
        source /opt/openfoam10/etc/bashrc >/dev/null 2>&1
        scalarTransportFoam
        # Copy pressure field to final time (scalarTransportFoam doesn't solve pressure)
        cp 0/p 5/p 2>/dev/null || true
    " >> "$log_file" 2>&1; then
        echo -e "${GREEN}[$(date '+%H:%M:%S')] SUCCESS: $case_name completed${NC}"
        
        # Validate output
        success=true
        for field in U p T; do
            if [ ! -f "$case_dir/5/$field" ]; then
                echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: Missing field $field in $case_name${NC}"
                success=false
            fi
        done
        
        if [ "$success" = true ]; then
            # Get max concentration for validation
            max_conc=$(docker exec "$container_name" bash -c "
                source /opt/openfoam10/etc/bashrc >/dev/null 2>&1
                head -50 5/T | tail -10 | grep -oE '[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' | sort -n | tail -1 2>/dev/null || echo '0'
            ")
            echo -e "${GREEN}[$(date '+%H:%M:%S')] Max concentration: $max_conc for $case_name${NC}" >> "$log_file"
        fi
    else
        echo -e "${RED}[$(date '+%H:%M:%S')] FAILED: $case_name${NC}"
        echo "Check log: $log_file"
    fi
    
    # Cleanup container
    docker stop "$container_name" >/dev/null 2>&1
    docker rm "$container_name" >/dev/null 2>&1
    
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Completed: $case_name${NC}"
}

# ===============================================================================
# JOB MANAGEMENT FUNCTIONS
# ===============================================================================

# Wait for job slots to become available
wait_for_slot() {
    while [ ${#RUNNING_JOBS[@]} -ge $MAX_JOBS ]; do
        # Check for completed jobs
        for i in "${!RUNNING_JOBS[@]}"; do
            if ! kill -0 "${JOB_PIDS[$i]}" 2>/dev/null; then
                # Job completed, remove from arrays
                unset RUNNING_JOBS[$i]
                unset JOB_PIDS[$i]
                # Reindex arrays
                RUNNING_JOBS=("${RUNNING_JOBS[@]}")
                JOB_PIDS=("${JOB_PIDS[@]}")
                break
            fi
        done
        sleep 2
    done
}

# ===============================================================================
# MAIN EXECUTION LOOP
# ===============================================================================

echo -e "${YELLOW}Starting 90-case simulation workflow...${NC}"
echo "Configuration:"
echo "  - Patterns: pattern_01 to pattern_30 (30 patterns)"
echo "  - Source locations: $SOURCES_LIST (3 locations)"
echo "  - Total cases: 90 simulations"
echo "  - Max parallel jobs: $MAX_JOBS"
echo "  - Results directory: $RESULTS_BASE_DIR"
echo "  - Logs directory: $LOG_DIR"
echo "  - Source coordinates:"
for source_name in $SOURCES_LIST; do
    case $source_name in
        center) echo "    - $source_name: $SOURCES_center" ;;
        upwind) echo "    - $source_name: $SOURCES_upwind" ;;
        side) echo "    - $source_name: $SOURCES_side" ;;
    esac
done
echo

# Initialize progress tracking
TOTAL_CASES=90
CURRENT_CASE=0

START_TIME=$(date +%s)

# Main simulation loop - iterate through pattern directories
for i in $(seq -f "%02g" 1 30); do
    pattern_dir="pattern_$i"
    
    # Skip if pattern directory doesn't exist
    if [ ! -d "$pattern_dir" ]; then
        echo -e "${YELLOW}Skipping $pattern_dir (directory not found)${NC}"
        continue
    fi
    
    for source_name in $SOURCES_LIST; do
        CURRENT_CASE=$((CURRENT_CASE + 1))
        
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Progress: $CURRENT_CASE/$TOTAL_CASES${NC}"
        echo -e "${YELLOW}Queuing: $pattern_dir, Source $source_name${NC}"
        
        # Wait for available job slot
        wait_for_slot
        
        # Start simulation in background
        run_single_simulation "$pattern_dir" "$source_name" &
        job_pid=$!
        
        # Track the job
        RUNNING_JOBS+=("${pattern_dir}_${source_name}")
        JOB_PIDS+=($job_pid)
        
        echo -e "${CYAN}Started job PID $job_pid: $pattern_dir, Source $source_name${NC}"
        echo -e "${CYAN}Active jobs: ${#RUNNING_JOBS[@]}/$MAX_JOBS${NC}"
        
        # Brief pause to prevent overwhelming the system
        sleep 1
    done
done

# Wait for all remaining jobs to complete
echo -e "${YELLOW}Waiting for all remaining jobs to complete...${NC}"
while [ ${#RUNNING_JOBS[@]} -gt 0 ]; do
    for i in "${!RUNNING_JOBS[@]}"; do
        if ! kill -0 "${JOB_PIDS[$i]}" 2>/dev/null; then
            echo -e "${GREEN}Completed: ${RUNNING_JOBS[$i]}${NC}"
            unset RUNNING_JOBS[$i]
            unset JOB_PIDS[$i]
            # Reindex arrays
            RUNNING_JOBS=("${RUNNING_JOBS[@]}")
            JOB_PIDS=("${JOB_PIDS[@]}")
        fi
    done
    if [ ${#RUNNING_JOBS[@]} -gt 0 ]; then
        echo -e "${CYAN}Still running: ${#RUNNING_JOBS[@]} jobs${NC}"
        sleep 5
    fi
done

# ===============================================================================
# COMPLETION SUMMARY
# ===============================================================================

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
HOURS=$((ELAPSED_TIME / 3600))
MINUTES=$(((ELAPSED_TIME % 3600) / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}90-Case Simulation Workflow Completed!${NC}"
echo -e "${BLUE}===============================================${NC}"
echo
echo "Summary:"
echo "  - Total cases processed: $TOTAL_CASES"
echo "  - Execution time: ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo "  - Results directory: $RESULTS_BASE_DIR/"
echo "  - Logs directory: $LOG_DIR/"
echo

# Count successful simulations
SUCCESS_COUNT=0
FAILED_COUNT=0

echo -e "${YELLOW}Validation Summary:${NC}"
for i in $(seq -f "%02g" 1 30); do
    pattern_dir="pattern_$i"
    if [ -d "$pattern_dir" ]; then
        for source_name in $SOURCES_LIST; do
            case_name="${pattern_dir}_${source_name}"
            case_dir="$RESULTS_BASE_DIR/$case_name"
            
            if [ -f "$case_dir/5/T" ] && [ -f "$case_dir/5/U" ] && [ -f "$case_dir/5/p" ]; then
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                FAILED_COUNT=$((FAILED_COUNT + 1))
                echo -e "${RED}  ❌ $case_name: Missing output fields${NC}"
            fi
        done
    fi
done

echo -e "${GREEN}  ✅ Successful simulations: $SUCCESS_COUNT${NC}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}  ❌ Failed simulations: $FAILED_COUNT${NC}"
else
    echo -e "${GREEN}  ✅ All simulations completed successfully!${NC}"
fi

echo
echo -e "${GREEN}Ready for GNN training with 90 complete datasets!${NC}"
echo "Each case contains U (velocity), p (pressure), and T (concentration) fields"
echo "Source configurations used:"
for source_name in $SOURCES_LIST; do
    case $source_name in
        center) echo "  - $source_name: $SOURCES_center" ;;
        upwind) echo "  - $source_name: $SOURCES_upwind" ;;
        side) echo "  - $source_name: $SOURCES_side" ;;
    esac
done