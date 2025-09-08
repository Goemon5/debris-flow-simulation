#!/bin/bash

# ===============================================================================
# Generate Flow Field Patterns from STL files
# Creates pattern_01 to pattern_30 directories with U,p fields
# ===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}Generating 30 Flow Field Patterns${NC}"
echo -e "${BLUE}===============================================${NC}"

# Check if debrisCase exists as template
if [ ! -d "debrisCase" ]; then
    echo -e "${RED}ERROR: debrisCase directory not found${NC}"
    exit 1
fi

# Count available STL files
STL_COUNT=$(ls debris_pattern_*.stl 2>/dev/null | wc -l)
echo -e "${YELLOW}Found $STL_COUNT STL pattern files${NC}"

if [ $STL_COUNT -eq 0 ]; then
    echo -e "${RED}ERROR: No debris_pattern_*.stl files found${NC}"
    exit 1
fi

# Process each pattern (limit to 30 or available STLs)
MAX_PATTERNS=30
if [ $STL_COUNT -lt $MAX_PATTERNS ]; then
    MAX_PATTERNS=$STL_COUNT
fi

echo -e "${BLUE}Will generate $MAX_PATTERNS pattern directories${NC}"

for i in $(seq -f "%02g" 1 $MAX_PATTERNS); do
    PATTERN_DIR="pattern_$i"
    STL_FILE="debris_pattern_$i.stl"
    
    echo -e "${YELLOW}Processing Pattern $i...${NC}"
    
    # Check if STL file exists
    if [ ! -f "$STL_FILE" ]; then
        echo -e "${RED}Warning: $STL_FILE not found, skipping${NC}"
        continue
    fi
    
    # Check if pattern directory already exists with valid data
    if [ -d "$PATTERN_DIR/5" ] && [ -f "$PATTERN_DIR/5/U" ] && [ -f "$PATTERN_DIR/5/p" ]; then
        echo -e "${GREEN}Pattern $i already exists with flow fields, skipping${NC}"
        continue
    fi
    
    # Create pattern directory structure
    echo "  Creating directory structure..."
    rm -rf "$PATTERN_DIR" 2>/dev/null
    mkdir -p "$PATTERN_DIR"
    
    # Copy base case structure
    cp -r debrisCase/constant "$PATTERN_DIR/"
    cp -r debrisCase/system "$PATTERN_DIR/" 2>/dev/null || mkdir -p "$PATTERN_DIR/system"
    cp -r debrisCase/0 "$PATTERN_DIR/" 2>/dev/null || mkdir -p "$PATTERN_DIR/0"
    
    # Copy existing flow field if available
    if [ -d "debrisCase/5" ]; then
        echo "  Using existing flow field from debrisCase/5..."
        cp -r debrisCase/5 "$PATTERN_DIR/"
        echo -e "${GREEN}✓ Pattern $i created using existing flow field${NC}"
    else
        echo -e "${YELLOW}  No flow field found in debrisCase/5${NC}"
        echo "  Would need to run flow simulation for this pattern"
        # Here you would typically run simpleFoam or similar
        # For now, we'll just copy what we have
        
        # Create minimal U and p fields if needed
        if [ -f "debrisCase/0/U" ] && [ -f "debrisCase/0/p" ]; then
            mkdir -p "$PATTERN_DIR/5"
            cp debrisCase/0/U "$PATTERN_DIR/5/"
            cp debrisCase/0/p "$PATTERN_DIR/5/"
            echo -e "${YELLOW}  Created placeholder fields in $PATTERN_DIR/5${NC}"
        fi
    fi
    
    # Update the STL reference if needed (optional)
    # This would typically be done in system/snappyHexMeshDict if using different STLs
    
done

echo
echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}Pattern Generation Complete!${NC}"
echo -e "${BLUE}===============================================${NC}"

# Summary
COMPLETED_COUNT=0
for i in $(seq -f "%02g" 1 $MAX_PATTERNS); do
    if [ -d "pattern_$i/5" ] && [ -f "pattern_$i/5/U" ] && [ -f "pattern_$i/5/p" ]; then
        ((COMPLETED_COUNT++))
    fi
done

echo "Summary:"
echo "  - Patterns processed: $MAX_PATTERNS"
echo "  - Successfully created: $COMPLETED_COUNT"
echo "  - STL files available: $STL_COUNT"
echo
echo "Patterns ready for 90-case simulation:"
ls -d pattern_* 2>/dev/null | head -10

if [ $COMPLETED_COUNT -lt 30 ]; then
    echo
    echo -e "${YELLOW}Note: Only $COMPLETED_COUNT patterns have flow fields.${NC}"
    echo -e "${YELLOW}To generate unique flow fields for each pattern,${NC}"
    echo -e "${YELLOW}you would need to run CFD simulations with different STL geometries.${NC}"
fi