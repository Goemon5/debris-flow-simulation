#!/bin/bash
# Script to run OpenFOAM simulation in stepa_project container

echo "Running OpenFOAM debris case in stepa_project container..."

# Get the current directory for volume mounting
CURRENT_DIR="$(pwd)"
DEBRIS_CASE_DIR="${CURRENT_DIR}/debrisCase"

echo "Mounting directory: ${DEBRIS_CASE_DIR}"

# Run the simulation in the container
docker run -it --rm \
    -v "${DEBRIS_CASE_DIR}:/workspace/debrisCase" \
    -w /workspace/debrisCase \
    openfoam-cfd \
    bash -c "
        echo 'Starting OpenFOAM simulation in container...'
        
        # Source OpenFOAM environment (adjust path as needed)
        source /opt/openfoam*/etc/bashrc 2>/dev/null || source /usr/lib/openfoam/openfoam*/etc/bashrc 2>/dev/null || echo 'OpenFOAM environment already loaded'
        
        # Run the simulation steps
        echo 'Step 1: Running blockMesh...'
        blockMesh
        if [ \$? -ne 0 ]; then
            echo 'ERROR: blockMesh failed!'
            exit 1
        fi
        
        echo 'Step 2: Running surfaceFeatureExtract...'
        surfaceFeatureExtract
        if [ \$? -ne 0 ]; then
            echo 'ERROR: surfaceFeatureExtract failed!'
            exit 1
        fi
        
        echo 'Step 3: Running snappyHexMesh...'
        snappyHexMesh -overwrite
        if [ \$? -ne 0 ]; then
            echo 'ERROR: snappyHexMesh failed!'
            exit 1
        fi
        
        echo 'Step 4: Running simpleFoam...'
        simpleFoam
        if [ \$? -ne 0 ]; then
            echo 'ERROR: simpleFoam failed!'
            exit 1
        fi
        
        echo 'Step 5: Creating case.foam file for ParaView...'
        touch case.foam
        
        echo 'Simulation completed successfully!'
        echo 'Results are saved in the debrisCase directory'
    "

echo "Container execution completed."