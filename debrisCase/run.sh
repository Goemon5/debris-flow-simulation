#!/bin/bash
# OpenFOAM debris case execution script
# This script runs the complete simulation workflow for debris scent dispersion analysis

echo "Starting OpenFOAM debris case simulation..."

# Step 1: Generate background mesh
echo "Step 1: Running blockMesh..."
blockMesh
if [ $? -ne 0 ]; then
    echo "ERROR: blockMesh failed!"
    exit 1
fi

# Step 2: Extract surface features
echo "Step 2: Running surfaceFeatureExtract..."
surfaceFeatureExtract
if [ $? -ne 0 ]; then
    echo "ERROR: surfaceFeatureExtract failed!"
    exit 1
fi

# Step 3: Generate refined mesh around debris
echo "Step 3: Running snappyHexMesh..."
snappyHexMesh -overwrite
if [ $? -ne 0 ]; then
    echo "ERROR: snappyHexMesh failed!"
    exit 1
fi

# Step 4: Run flow and scalar transport simulation
echo "Step 4: Running simpleFoam..."
simpleFoam
if [ $? -ne 0 ]; then
    echo "ERROR: simpleFoam failed!"
    exit 1
fi

# Step 5: Create case.foam file for ParaView
echo "Step 5: Creating case.foam file for ParaView..."
touch case.foam

echo "Simulation completed successfully!"
echo "To visualize results, open case.foam in ParaView"