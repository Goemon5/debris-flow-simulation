#!/bin/bash

# ===============================================================================
# OpenFOAM Simulation Runner with Automatic Storage Management
# Monitors disk space and automatically backs up results to Google Drive
# ===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}OpenFOAM with Storage Management${NC}"
echo -e "${BLUE}===============================================${NC}"

# Configuration
MIN_FREE_GB=5.0
BACKUP_THRESHOLD_GB=10.0
SIMULATION_SCRIPT="${1:-run_scent_with_openfoam10.sh}"

# Check if simulation script exists
if [ ! -f "$SIMULATION_SCRIPT" ]; then
    echo -e "${RED}Error: Simulation script '$SIMULATION_SCRIPT' not found${NC}"
    echo "Usage: $0 [simulation_script.sh]"
    exit 1
fi

# Function to check disk space
check_disk_space() {
    df . | tail -1 | awk '{printf "%.1f", $4/1024/1024}'
}

# Function to get disk usage percentage
get_disk_usage_percent() {
    df . | tail -1 | awk '{print $5}' | sed 's/%//'
}

echo -e "${YELLOW}Pre-simulation storage check...${NC}"
python3 storage_manager.py

AVAILABLE_GB=$(check_disk_space)
USAGE_PERCENT=$(get_disk_usage_percent)

echo -e "${BLUE}Current disk status:${NC}"
echo "Available space: ${AVAILABLE_GB} GB"
echo "Usage: ${USAGE_PERCENT}%"

# Check if we have enough space to start simulation
if (( $(echo "$AVAILABLE_GB < $MIN_FREE_GB" | bc -l) )); then
    echo -e "${RED}⚠️  Warning: Low disk space ($AVAILABLE_GB GB < $MIN_FREE_GB GB)${NC}"
    echo -e "${YELLOW}Running pre-simulation backup...${NC}"
    
    python3 backup_to_gdrive.py --threshold $BACKUP_THRESHOLD_GB
    
    # Check space again after backup
    AVAILABLE_GB=$(check_disk_space)
    if (( $(echo "$AVAILABLE_GB < $MIN_FREE_GB" | bc -l) )); then
        echo -e "${RED}❌ Still insufficient disk space after backup${NC}"
        echo -e "${RED}Please free up more space manually or increase backup threshold${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Sufficient disk space available${NC}"
echo -e "${YELLOW}Starting simulation: $SIMULATION_SCRIPT${NC}"

# Start storage monitoring in background
echo -e "${BLUE}Starting storage monitor...${NC}"
python3 -c "
import subprocess
import time
import os
import sys

def monitor_storage():
    while True:
        try:
            # Check if main process is still running
            result = subprocess.run(['pgrep', '-f', '$SIMULATION_SCRIPT'], capture_output=True)
            if result.returncode != 0:
                break
            
            # Check disk space
            df_result = subprocess.run(['df', '.'], capture_output=True, text=True)
            lines = df_result.stdout.strip().split('\n')
            if len(lines) > 1:
                fields = lines[1].split()
                available_gb = int(fields[3]) / (1024 * 1024)
                
                if available_gb < $MIN_FREE_GB:
                    print(f'🚨 CRITICAL: Disk space critically low: {available_gb:.1f} GB')
                    subprocess.run(['python3', 'backup_to_gdrive.py', '--threshold', str($BACKUP_THRESHOLD_GB)])
                elif available_gb < $BACKUP_THRESHOLD_GB:
                    print(f'⚠️  WARNING: Disk space getting low: {available_gb:.1f} GB')
            
            time.sleep(60)  # Check every minute
        except Exception as e:
            print(f'Storage monitor error: {e}')
            time.sleep(60)

monitor_storage()
" &
MONITOR_PID=$!

# Run the actual simulation
echo -e "${GREEN}🚀 Launching simulation...${NC}"
if bash "$SIMULATION_SCRIPT"; then
    echo -e "${GREEN}✅ Simulation completed successfully${NC}"
    SIMULATION_SUCCESS=true
else
    echo -e "${RED}❌ Simulation failed${NC}"
    SIMULATION_SUCCESS=false
fi

# Kill the storage monitor
kill $MONITOR_PID 2>/dev/null

# Post-simulation cleanup and backup
echo -e "${YELLOW}Post-simulation storage management...${NC}"

if [ "$SIMULATION_SUCCESS" = true ]; then
    # Check if we should backup results
    FINAL_AVAILABLE_GB=$(check_disk_space)
    echo "Final available space: ${FINAL_AVAILABLE_GB} GB"
    
    if (( $(echo "$FINAL_AVAILABLE_GB < $BACKUP_THRESHOLD_GB" | bc -l) )); then
        echo -e "${YELLOW}Running post-simulation backup...${NC}"
        python3 backup_to_gdrive.py --threshold $BACKUP_THRESHOLD_GB
    fi
    
    # Final storage status
    python3 storage_manager.py
    
    echo -e "${GREEN}✅ Simulation and storage management completed${NC}"
else
    echo -e "${RED}❌ Simulation failed - skipping backup${NC}"
fi

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}Storage Management Summary${NC}"
echo -e "${BLUE}===============================================${NC}"
FINAL_AVAILABLE_GB=$(check_disk_space)
FINAL_USAGE_PERCENT=$(get_disk_usage_percent)
echo "Final disk status:"
echo "Available space: ${FINAL_AVAILABLE_GB} GB"
echo "Usage: ${FINAL_USAGE_PERCENT}%"

if [ "$SIMULATION_SUCCESS" = true ]; then
    exit 0
else
    exit 1
fi