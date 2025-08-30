#!/usr/bin/env python3
"""STL形状の確認と可視化"""

import numpy as np
from stl import mesh
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

# STLファイルを読み込み
debris_mesh = mesh.Mesh.from_file('disaster_debris_01.stl')

# メッシュ情報を表示
print('=' * 50)
print('STL Mesh Information:')
print('=' * 50)
print(f'Number of triangles: {len(debris_mesh.vectors)}')
print(f'Bounding box:')
print(f'  X: [{debris_mesh.min_[0]:.2f}, {debris_mesh.max_[0]:.2f}]')
print(f'  Y: [{debris_mesh.min_[1]:.2f}, {debris_mesh.max_[1]:.2f}]')
print(f'  Z: [{debris_mesh.min_[2]:.2f}, {debris_mesh.max_[2]:.2f}]')

volume, cog, inertia = debris_mesh.get_mass_properties()
print(f'Volume: {volume:.2f}')
print(f'Center of gravity: [{cog[0]:.2f}, {cog[1]:.2f}, {cog[2]:.2f}]')

# 3D可視化
fig = plt.figure(figsize=(12, 10))

# 3Dビュー
ax = fig.add_subplot(111, projection='3d')

# STLメッシュの頂点を取得
vectors = debris_mesh.vectors

# 各三角形をプロット
for triangle in vectors[:500]:  # 最初の500個の三角形を表示
    polygon = [[triangle[j][i] for j in range(3)] for i in range(3)]
    ax.add_collection3d(plt.Poly3D(polygon, alpha=0.3, facecolor='gray', edgecolor='black'))

# 座標軸の設定
ax.set_xlim([debris_mesh.min_[0], debris_mesh.max_[0]])
ax.set_ylim([debris_mesh.min_[1], debris_mesh.max_[1]])
ax.set_zlim([debris_mesh.min_[2], debris_mesh.max_[2]])

ax.set_xlabel('X (m)')
ax.set_ylabel('Y (m)')
ax.set_zlabel('Z (m)')
ax.set_title('Original STL Shape: disaster_debris_01.stl')

# グリッドを表示
ax.grid(True)

# 視点を調整
ax.view_init(elev=30, azim=45)

plt.tight_layout()
plt.savefig('original_stl_shape.png', dpi=150)
plt.show()

print(f'\n図を original_stl_shape.png として保存しました')