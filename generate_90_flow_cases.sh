#!/bin/bash

# ===============================================================================
# Generate 90 Flow Pattern Cases from STL files
# Creates OpenFOAM flow simulation cases for all 90 debris patterns
# ===============================================================================

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}90 Flow Pattern Case Generator${NC}"
echo -e "${BLUE}===============================================${NC}"

# Configuration
MAX_JOBS=4
BASE_DIR="flow_results_90patterns"
TEMPLATE_DIR="flow_results_90patterns/pattern_01_flow"  # Use existing pattern_01 as template

# Create base directory
mkdir -p "$BASE_DIR"

# Function to create single flow case
create_flow_case() {
    local pattern_num=$1
    local pattern_name="pattern_$(printf "%02d" $pattern_num)"
    local case_dir="$BASE_DIR/${pattern_name}_flow"
    local stl_file="debris_pattern_$(printf "%02d" $pattern_num).stl"
    
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Creating $pattern_name flow case${NC}"
    
    # Skip if already exists
    if [ -d "$case_dir" ]; then
        echo -e "${YELLOW}Skipping $pattern_name (already exists)${NC}"
        return 0
    fi
    
    # Check if STL file exists
    if [ ! -f "$stl_file" ]; then
        echo -e "${RED}ERROR: STL file $stl_file not found${NC}"
        return 1
    fi
    
    # Copy template directory structure
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo -e "${RED}ERROR: Template directory $TEMPLATE_DIR not found${NC}"
        return 1
    fi
    
    cp -r "$TEMPLATE_DIR" "$case_dir"
    
    # Copy STL file to case
    cp "$stl_file" "$case_dir/constant/triSurface/debris.stl"
    
    # Create run script for this pattern
    cat > "$case_dir/run_simulation.sh" << 'EOF'
#!/bin/bash

echo "Starting flow simulation for this pattern..."

# Source OpenFOAM environment
source /opt/openfoam10/etc/bashrc

# Clean previous results
rm -rf [1-9]* 0/cellLevel 0/pointLevel processor* constant/polyMesh

# Generate mesh
echo "Generating mesh..."
blockMesh > blockMesh.log 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: blockMesh failed"
    exit 1
fi

# Extract surface features
echo "Extracting surface features..."
surfaceFeatures > surfaceFeatures.log 2>&1

# Generate snappy mesh
echo "Running snappyHexMesh..."
snappyHexMesh -overwrite > snappyHexMesh.log 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: snappyHexMesh failed"
    exit 1
fi

# Run flow simulation
echo "Running flow simulation..."
simpleFoam > simpleFoam.log 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: simpleFoam failed"
    exit 1
fi

echo "Flow simulation completed successfully"
EOF
    
    chmod +x "$case_dir/run_simulation.sh"
    
    echo -e "${GREEN}[$(date '+%H:%M:%S')] Created $pattern_name flow case${NC}"
    return 0
}

# Job tracking arrays  
RUNNING_JOBS=()
JOB_PIDS=()

# Wait for job slots to become available
wait_for_slot() {
    while [ ${#RUNNING_JOBS[@]} -ge $MAX_JOBS ]; do
        for i in "${!RUNNING_JOBS[@]}"; do
            if ! kill -0 "${JOB_PIDS[$i]}" 2>/dev/null; then
                unset RUNNING_JOBS[$i]
                unset JOB_PIDS[$i]
                RUNNING_JOBS=("${RUNNING_JOBS[@]}")
                JOB_PIDS=("${JOB_PIDS[@]}")
                break
            fi
        done
        sleep 1
    done
}

echo -e "${YELLOW}Creating 90 flow pattern cases...${NC}"
echo "Template: $TEMPLATE_DIR"
echo "Output: $BASE_DIR"
echo

# Create all 90 cases
for i in $(seq 1 90); do
    echo -e "${BLUE}[$(date '+%H:%M:%S')] Progress: $i/90${NC}"
    
    # Wait for available slot
    wait_for_slot
    
    # Create case in background
    create_flow_case "$i" &
    job_pid=$!
    
    # Track the job
    RUNNING_JOBS+=("pattern_$(printf "%02d" $i)")
    JOB_PIDS+=($job_pid)
    
    echo -e "${CYAN}Active jobs: ${#RUNNING_JOBS[@]}/$MAX_JOBS${NC}"
    sleep 0.1
done

# Wait for all jobs to complete
echo -e "${YELLOW}Waiting for all case creation jobs to complete...${NC}"
while [ ${#RUNNING_JOBS[@]} -gt 0 ]; do
    for i in "${!RUNNING_JOBS[@]}"; do
        if ! kill -0 "${JOB_PIDS[$i]}" 2>/dev/null; then
            echo -e "${GREEN}Completed: ${RUNNING_JOBS[$i]}${NC}"
            unset RUNNING_JOBS[$i]
            unset JOB_PIDS[$i]
            RUNNING_JOBS=("${RUNNING_JOBS[@]}")
            JOB_PIDS=("${JOB_PIDS[@]}")
        fi
    done
    if [ ${#RUNNING_JOBS[@]} -gt 0 ]; then
        echo -e "${CYAN}Still creating: ${#RUNNING_JOBS[@]} cases${NC}"
        sleep 2
    fi
done

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}90 Flow Pattern Cases Created!${NC}"
echo -e "${BLUE}===============================================${NC}"

# Count successful cases
SUCCESS_COUNT=0
for i in $(seq 1 90); do
    pattern_name="pattern_$(printf "%02d" $i)"
    case_dir="$BASE_DIR/${pattern_name}_flow"
    if [ -d "$case_dir" ] && [ -f "$case_dir/run_simulation.sh" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

echo "Summary:"
echo "  - Total cases created: $SUCCESS_COUNT/90"
echo "  - Directory: $BASE_DIR"
echo

if [ $SUCCESS_COUNT -eq 90 ]; then
    echo -e "${GREEN}✅ All 90 flow pattern cases created successfully!${NC}"
    echo "Next step: Run flow simulations for all patterns"
else
    echo -e "${RED}❌ Some cases failed to create${NC}"
fi