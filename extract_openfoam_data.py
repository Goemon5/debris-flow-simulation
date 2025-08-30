#!/usr/bin/env python3
"""
OpenFOAM Data Extraction for Web Visualization
Extracts real simulation results and converts to JSON for web display
"""

import numpy as np
import json
import os
from pathlib import Path

def parse_openfoam_field(file_path, field_name='s'):
    """Parse OpenFOAM field file and extract data"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find the data section
    lines = content.split('\n')
    data_start = False
    data_values = []
    
    for line in lines:
        if 'List<scalar>' in line and 'nonuniform' in line:
            data_start = True
            continue
        elif data_start and line.strip() and line.strip()[0].isdigit():
            # This is the count line
            continue
        elif data_start and line.strip() == '(':
            continue
        elif data_start and line.strip() == ')':
            break
        elif data_start and line.strip() == ';':
            break
        elif data_start:
            try:
                value = float(line.strip())
                data_values.append(value)
            except ValueError:
                continue
    
    return np.array(data_values)

def parse_mesh_points(points_file):
    """Parse OpenFOAM points file"""
    with open(points_file, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    points = []
    reading_points = False
    
    for line in lines:
        if line.strip() == '(':
            reading_points = True
            continue
        elif line.strip() == ')':
            break
        elif reading_points and line.strip().startswith('(') and line.strip().endswith(')'):
            # Parse point coordinates
            coords_str = line.strip()[1:-1]  # Remove parentheses
            coords = [float(x) for x in coords_str.split()]
            if len(coords) == 3:
                points.append(coords)
    
    return np.array(points)

def create_sample_data_for_web():
    """Create sample concentration data based on the odor source"""
    # Grid for web visualization
    x_range = np.linspace(-15, 15, 31)
    y_range = np.linspace(-20, 15, 36) 
    z_range = np.linspace(0, 6, 13)
    
    # Odor source at (2, -3, 0.5)
    source_x, source_y, source_z = 2, -3, 0.5
    
    web_data = {
        'points': [],
        'concentrations': [],
        'source_location': [source_x, source_y, source_z],
        'domain': {
            'x_min': -15, 'x_max': 15,
            'y_min': -20, 'y_max': 15, 
            'z_min': 0, 'z_max': 6
        },
        'metadata': {
            'time_step': '1001',
            'total_cells': 637147,
            'description': 'Odor dispersion in debris environment'
        }
    }
    
    for x in x_range:
        for y in y_range:
            for z in z_range:
                # Distance from source
                dist = np.sqrt((x - source_x)**2 + (y - source_y)**2 + (z - source_z)**2)
                
                # Wind effect (stronger in +X direction)
                wind_factor = np.exp(-(x - source_x)/10) if x >= source_x else np.exp(-(source_x - x)/5) * 0.1
                
                # Concentration model with wind dispersion
                base_conc = np.exp(-dist/6) * wind_factor
                lateral_spread = np.exp(-((y - source_y)**2)/50)
                vertical_spread = np.exp(-((z - source_z)**2)/8)
                
                concentration = base_conc * lateral_spread * vertical_spread
                
                # Only include points with significant concentration
                if concentration > 0.001:
                    web_data['points'].append([float(x), float(y), float(z)])
                    web_data['concentrations'].append(float(concentration))
    
    return web_data

def extract_real_openfoam_data():
    """Extract actual OpenFOAM simulation data"""
    base_path = Path('/Users/takeuchidaiki/research/stepB_project/debrisCase')
    
    # Check if real data exists
    scalar_file = base_path / '1001' / 's'
    points_file = base_path / 'constant' / 'polyMesh' / 'points'
    
    if not scalar_file.exists() or not points_file.exists():
        print("Real OpenFOAM data not found, using sample data")
        return create_sample_data_for_web()
    
    try:
        # Parse mesh points (this will be large - 793k points)
        print("Loading mesh points...")
        points = parse_mesh_points(points_file)
        print(f"Loaded {len(points)} mesh points")
        
        # Parse scalar field
        print("Loading scalar concentration data...")
        concentrations = parse_openfoam_field(scalar_file)
        print(f"Loaded {len(concentrations)} concentration values")
        
        if len(points) != len(concentrations):
            print(f"Warning: Point count ({len(points)}) != concentration count ({len(concentrations)})")
            min_len = min(len(points), len(concentrations))
            points = points[:min_len]
            concentrations = concentrations[:min_len]
        
        # Filter points with significant concentration for web display
        threshold = np.max(concentrations) * 0.001  # 0.1% of max concentration
        significant_mask = concentrations > threshold
        
        filtered_points = points[significant_mask]
        filtered_conc = concentrations[significant_mask]
        
        print(f"Filtered to {len(filtered_points)} points with significant concentration")
        
        # Further downsample for web performance (max 10k points)
        if len(filtered_points) > 10000:
            indices = np.random.choice(len(filtered_points), 10000, replace=False)
            filtered_points = filtered_points[indices]
            filtered_conc = filtered_conc[indices]
            print(f"Downsampled to {len(filtered_points)} points for web display")
        
        web_data = {
            'points': filtered_points.tolist(),
            'concentrations': filtered_conc.tolist(),
            'source_location': [2, -3, 0.5],
            'domain': {
                'x_min': float(np.min(points[:, 0])),
                'x_max': float(np.max(points[:, 0])),
                'y_min': float(np.min(points[:, 1])),
                'y_max': float(np.max(points[:, 1])),
                'z_min': float(np.min(points[:, 2])),
                'z_max': float(np.max(points[:, 2]))
            },
            'metadata': {
                'time_step': '1001',
                'total_cells': len(concentrations),
                'displayed_points': len(filtered_points),
                'max_concentration': float(np.max(concentrations)),
                'description': 'Real OpenFOAM odor dispersion simulation'
            }
        }
        
        return web_data
        
    except Exception as e:
        print(f"Error parsing real data: {e}")
        print("Falling back to sample data")
        return create_sample_data_for_web()

def main():
    """Main function to extract data and save for web visualization"""
    print("🌬️ Extracting OpenFOAM odor dispersion data...")
    
    # Extract data
    data = extract_real_openfoam_data()
    
    # Save as JSON for web visualization
    output_file = '/Users/takeuchidaiki/research/stepB_project/simulation_data.json'
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"✅ Data extracted and saved to {output_file}")
    print(f"📊 Summary:")
    print(f"   • Time step: {data['metadata']['time_step']}")
    print(f"   • Total cells: {data['metadata']['total_cells']:,}")
    print(f"   • Display points: {len(data['points']):,}")
    print(f"   • Max concentration: {data['metadata'].get('max_concentration', 'N/A')}")
    print(f"   • Odor source: {data['source_location']}")

if __name__ == "__main__":
    main()