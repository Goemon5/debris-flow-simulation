#!/usr/bin/env python3
"""STL形状の簡単な確認"""

import numpy as np
from stl import mesh

# STLファイルを読み込み
print("Loading STL file...")
debris_mesh = mesh.Mesh.from_file('disaster_debris_01.stl')

print("\n" + "="*60)
print("Original STL Shape Analysis:")
print("="*60)

# 基本情報
print(f"\n1. Mesh Statistics:")
print(f"   - Number of triangles: {len(debris_mesh.vectors)}")
print(f"   - Number of unique vertices: ~{len(debris_mesh.vectors) * 3}")

# バウンディングボックス
print(f"\n2. Bounding Box:")
print(f"   - X range: [{debris_mesh.min_[0]:.3f}, {debris_mesh.max_[0]:.3f}] m")
print(f"   - Y range: [{debris_mesh.min_[1]:.3f}, {debris_mesh.max_[1]:.3f}] m")
print(f"   - Z range: [{debris_mesh.min_[2]:.3f}, {debris_mesh.max_[2]:.3f}] m")

# サイズ
size_x = debris_mesh.max_[0] - debris_mesh.min_[0]
size_y = debris_mesh.max_[1] - debris_mesh.min_[1]
size_z = debris_mesh.max_[2] - debris_mesh.min_[2]
print(f"\n3. Dimensions:")
print(f"   - Width (X): {size_x:.3f} m")
print(f"   - Depth (Y): {size_y:.3f} m")
print(f"   - Height (Z): {size_z:.3f} m")

# 体積と重心
volume, cog, inertia = debris_mesh.get_mass_properties()
print(f"\n4. Physical Properties:")
print(f"   - Volume: {volume:.3f} m³")
print(f"   - Center of gravity: ({cog[0]:.3f}, {cog[1]:.3f}, {cog[2]:.3f}) m")

# blockMeshとの比較
print("\n" + "="*60)
print("Comparison with blockMesh domain:")
print("="*60)
print("\nblockMesh domain: X[-5,15], Y[-5,15], Z[0,10]")
print(f"STL object:       X[{debris_mesh.min_[0]:.1f},{debris_mesh.max_[0]:.1f}], Y[{debris_mesh.min_[1]:.1f},{debris_mesh.max_[1]:.1f}], Z[{debris_mesh.min_[2]:.1f},{debris_mesh.max_[2]:.1f}]")

if debris_mesh.min_[0] < -5 or debris_mesh.max_[0] > 15:
    print("⚠️  Warning: STL extends outside blockMesh domain in X direction!")
if debris_mesh.min_[1] < -5 or debris_mesh.max_[1] > 15:
    print("⚠️  Warning: STL extends outside blockMesh domain in Y direction!")
if debris_mesh.min_[2] < 0 or debris_mesh.max_[2] > 10:
    print("⚠️  Warning: STL extends outside blockMesh domain in Z direction!")

print("\n" + "="*60)
print("Analysis Complete")
print("="*60)