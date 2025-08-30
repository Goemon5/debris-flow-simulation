#!/bin/bash
# OpenFOAM mesh regeneration script with corrected domain

echo "========================================="
echo "Regenerating mesh with corrected domain"
echo "========================================="

# Clean previous results
echo "Cleaning previous mesh and results..."
rm -rf constant/polyMesh
rm -rf 1 2 100 200 300 400 500 600 700 800 900 1000
rm -rf VTK
rm -rf processor*
rm -rf postProcessing

# Step 1: Create background mesh with expanded domain
echo -e "\n1. Creating blockMesh (expanded domain)..."
blockMesh

# Step 2: Extract surface features
echo -e "\n2. Extracting surface features..."
surfaceFeatures

# Step 3: Generate snappyHexMesh
echo -e "\n3. Running snappyHexMesh..."
snappyHexMesh -overwrite

# Step 4: Check mesh quality
echo -e "\n4. Checking mesh quality..."
checkMesh | tail -30

# Step 5: Convert to VTK for visualization
echo -e "\n5. Converting to VTK format..."
foamToVTK -time 0 -ascii

# Step 6: Create ParaView file
echo -e "\n6. Creating case.foam file..."
touch case.foam

echo -e "\n========================================="
echo "Mesh regeneration complete!"
echo "========================================="
echo "You can now visualize the mesh in ParaView:"
echo "  - Open case.foam or VTK/debrisCase_0.vtk"
echo "  - Check debris shape at VTK/debris/debris_0.vtk"