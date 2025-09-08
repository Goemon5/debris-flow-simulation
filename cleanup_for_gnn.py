#!/usr/bin/env python3
"""
OpenFOAM case cleanup script for GNN training
Removes unnecessary files and reorganizes output for GNN compatibility
"""

import os
import shutil
import glob
import json
import re
from pathlib import Path

def cleanup_case(case_path):
    """Clean up a single OpenFOAM case for GNN training"""
    case_path = Path(case_path)
    
    print(f"Cleaning up case: {case_path}")
    
    # 1. Clean up polyMesh directory
    polymesh_path = case_path / "constant" / "polyMesh"
    if polymesh_path.exists():
        # Files to keep
        keep_files = {'points', 'faces', 'owner', 'neighbour', 'boundary'}
        
        # Remove unnecessary files
        for file in polymesh_path.iterdir():
            if file.name not in keep_files and file.is_file():
                print(f"  Removing: {file}")
                file.unlink()
    
    # 2. Find time directories (numerical names)
    time_dirs = []
    for item in case_path.iterdir():
        if item.is_dir() and re.match(r'^\d+(\.\d+)?$', item.name):
            time_dirs.append((float(item.name), item))
    
    if not time_dirs:
        print("  No time directories found")
        return None
    
    # Sort by time and get final time
    time_dirs.sort(key=lambda x: x[0])
    final_time, final_dir = time_dirs[-1]
    
    # 3. Create final directory and move essential files
    final_output_dir = case_path / "final"
    if final_output_dir.exists():
        shutil.rmtree(final_output_dir)
    final_output_dir.mkdir()
    
    # Copy only U and p from final time
    essential_files = ['U', 'p']
    for file in essential_files:
        src_file = final_dir / file
        if src_file.exists():
            shutil.copy2(src_file, final_output_dir / file)
            print(f"  Copied {file} to final/")
        else:
            print(f"  Warning: {file} not found in {final_dir}")
    
    # 4. Remove all time directories except 0 (initial conditions)
    for time_val, time_dir in time_dirs:
        if time_val != 0:  # Keep initial conditions (0 directory)
            print(f"  Removing time directory: {time_dir}")
            shutil.rmtree(time_dir)
    
    # 5. Clean up 0 directory (keep only U and p)
    init_dir = case_path / "0"
    if init_dir.exists():
        for file in init_dir.iterdir():
            if file.name not in essential_files and file.is_file():
                print(f"  Removing from 0/: {file}")
                file.unlink()
    
    # 6. Remove unnecessary files and directories
    cleanup_patterns = [
        "*.log*",
        "log.*",
        "VTK",
        "postProcessing",
        "dynamicCode",
        "processor*"
    ]
    
    for pattern in cleanup_patterns:
        for item in case_path.glob(pattern):
            if item.is_dir():
                print(f"  Removing directory: {item}")
                shutil.rmtree(item)
            else:
                print(f"  Removing file: {item}")
                item.unlink()
    
    return final_time

def count_cells(case_path):
    """Count number of cells from owner file"""
    owner_file = Path(case_path) / "constant" / "polyMesh" / "owner"
    if not owner_file.exists():
        return 0
    
    try:
        with open(owner_file, 'r') as f:
            lines = f.readlines()
        
        # Find the number (first line after header)
        in_data = False
        for line in lines:
            line = line.strip()
            if line and not line.startswith('//') and not line.startswith('/*'):
                if line.startswith('FoamFile') or line.startswith('{') or line.startswith('}'):
                    continue
                if line.isdigit():
                    return int(line)
    except:
        pass
    return 0

def generate_metadata(case_path, final_time):
    """Generate metadata JSON file for GNN"""
    case_path = Path(case_path)
    
    # Count cells
    num_cells = count_cells(case_path)
    
    # Read transport properties for Reynolds number calculation
    nu = 1e-5  # default kinematic viscosity
    try:
        transport_file = case_path / "constant" / "transportProperties"
        if transport_file.exists():
            with open(transport_file, 'r') as f:
                content = f.read()
                # Simple extraction of nu value
                nu_match = re.search(r'nu\s+nu\s+\[\s*\d+\s+\-\d+\s+\-\d+.*?\]\s+([\d\.e\-\+]+)', content)
                if nu_match:
                    nu = float(nu_match.group(1))
    except:
        pass
    
    # Estimate Reynolds number (U=1 m/s, L=1 m characteristic)
    reynolds_number = 1.0 / nu
    
    metadata = {
        "case_name": case_path.name,
        "final_time": final_time,
        "num_cells": num_cells,
        "reynolds_number": reynolds_number,
        "kinematic_viscosity": nu,
        "mesh_type": "snappyHexMesh",
        "variables": ["U", "p"],
        "boundary_conditions": {
            "inlet": "fixedValue U, zeroGradient p",
            "outlet": "zeroGradient U, fixedValue p",
            "ground": "noSlip U, zeroGradient p",
            "atmosphere": "slip U, zeroGradient p",
            "debris": "noSlip U, zeroGradient p"
        },
        "solver": "simpleFoam",
        "turbulence_model": "kOmegaSST"
    }
    
    # Write metadata file
    metadata_file = case_path / "case_info.json"
    with open(metadata_file, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"  Generated metadata: {num_cells} cells, Re={reynolds_number:.1e}")
    return metadata

def main():
    """Clean up all pattern cases for GNN training"""
    import sys
    
    if len(sys.argv) > 1:
        # Clean specific case
        case_path = sys.argv[1]
        final_time = cleanup_case(case_path)
        if final_time is not None:
            generate_metadata(case_path, final_time)
    else:
        # Clean all pattern cases
        pattern_dirs = glob.glob("simulation_results/pattern_*")
        
        print(f"Found {len(pattern_dirs)} pattern directories to clean")
        
        for pattern_dir in sorted(pattern_dirs):
            case_dir = os.path.join(pattern_dir, "debrisCase")
            if os.path.exists(case_dir):
                final_time = cleanup_case(case_dir)
                if final_time is not None:
                    generate_metadata(case_dir, final_time)
                print()

if __name__ == "__main__":
    main()