#!/usr/bin/env python3
import numpy as np
import random
import sys

def generate_stl_ascii(vertices, faces):
    stl_content = "solid debris\n"
    
    for face in faces:
        v1 = vertices[face[0]]
        v2 = vertices[face[1]]
        v3 = vertices[face[2]]
        
        edge1 = v2 - v1
        edge2 = v3 - v1
        normal = np.cross(edge1, edge2)
        normal = normal / np.linalg.norm(normal)
        
        stl_content += f"  facet normal {normal[0]:.6e} {normal[1]:.6e} {normal[2]:.6e}\n"
        stl_content += "    outer loop\n"
        for i in face:
            v = vertices[i]
            stl_content += f"      vertex {v[0]:.6e} {v[1]:.6e} {v[2]:.6e}\n"
        stl_content += "    endloop\n"
        stl_content += "  endfacet\n"
    
    stl_content += "endsolid debris\n"
    return stl_content

def create_box(center, size):
    cx, cy, cz = center
    dx, dy, dz = size[0]/2, size[1]/2, size[2]/2
    
    vertices = np.array([
        [cx - dx, cy - dy, cz - dz],
        [cx + dx, cy - dy, cz - dz],
        [cx + dx, cy + dy, cz - dz],
        [cx - dx, cy + dy, cz - dz],
        [cx - dx, cy - dy, cz + dz],
        [cx + dx, cy - dy, cz + dz],
        [cx + dx, cy + dy, cz + dz],
        [cx - dx, cy + dy, cz + dz]
    ])
    
    faces = [
        [0, 1, 2], [0, 2, 3],  # bottom
        [4, 7, 6], [4, 6, 5],  # top
        [0, 4, 5], [0, 5, 1],  # front
        [2, 6, 7], [2, 7, 3],  # back
        [0, 3, 7], [0, 7, 4],  # left
        [1, 5, 6], [1, 6, 2]   # right
    ]
    
    return vertices, faces

def generate_pattern(pattern_num):
    random.seed(42 + pattern_num)  # Reproducible randomness
    
    all_vertices = []
    all_faces = []
    vertex_offset = 0
    
    # Generate 3-8 boxes with random positions and sizes
    num_boxes = random.randint(3, 8)
    
    for i in range(num_boxes):
        # Random position within the domain
        center = [
            random.uniform(10, 40),   # x position
            random.uniform(5, 25),     # y position  
            random.uniform(0.5, 2.5)   # z position (keep low)
        ]
        
        # Random size
        size = [
            random.uniform(2, 6),      # x size
            random.uniform(2, 6),      # y size
            random.uniform(1, 3)       # z size
        ]
        
        vertices, faces = create_box(center, size)
        
        # Offset faces indices
        offset_faces = [[f[0] + vertex_offset, f[1] + vertex_offset, f[2] + vertex_offset] for f in faces]
        
        all_vertices.extend(vertices)
        all_faces.extend(offset_faces)
        vertex_offset += len(vertices)
    
    all_vertices = np.array(all_vertices)
    
    return all_vertices, all_faces

def main():
    for pattern_num in range(1, 31):
        filename = f"debris_pattern_{pattern_num:02d}.stl"
        
        vertices, faces = generate_pattern(pattern_num)
        stl_content = generate_stl_ascii(vertices, faces)
        
        with open(filename, 'w') as f:
            f.write(stl_content)
        
        print(f"Generated {filename} with {len(faces)//12} boxes")

if __name__ == "__main__":
    main()