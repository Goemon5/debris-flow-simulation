#!/usr/bin/env python3
"""匂い源の位置を可視化"""

import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from stl import mesh

def visualize_odor_source():
    """STL形状と匂い源の位置を表示"""
    
    print("瓦礫形状と匂い源位置を可視化中...")
    
    # STLファイルを読み込み
    debris_mesh = mesh.Mesh.from_file('disaster_debris_01.stl')
    
    # 匂い源の位置
    odor_source = {
        'center': [2, -3, 0.5],  # 中心座標
        'radius': 0.3,           # 半径
        'color': 'red',
        'label': '匂い源'
    }
    
    # 図の作成
    fig = plt.figure(figsize=(16, 10))
    
    # 1. 3D表示
    ax1 = fig.add_subplot(1, 3, 1, projection='3d')
    
    # STLメッシュの頂点を表示（軽量化のため間引き）
    vectors = debris_mesh.vectors
    for i in range(0, len(vectors), 20):
        tri = vectors[i]
        x = [tri[j][0] for j in range(3)]
        y = [tri[j][1] for j in range(3)]  
        z = [tri[j][2] for j in range(3)]
        ax1.plot_trisurf(x, y, z, color='gray', alpha=0.2, edgecolor='none')
    
    # 匂い源を赤い球で表示
    u = np.linspace(0, 2 * np.pi, 20)
    v = np.linspace(0, np.pi, 20)
    x_sphere = odor_source['center'][0] + odor_source['radius'] * np.outer(np.cos(u), np.sin(v))
    y_sphere = odor_source['center'][1] + odor_source['radius'] * np.outer(np.sin(u), np.sin(v))
    z_sphere = odor_source['center'][2] + odor_source['radius'] * np.outer(np.ones(np.size(u)), np.cos(v))
    
    ax1.plot_surface(x_sphere, y_sphere, z_sphere, color='red', alpha=0.8)
    
    # 風向きの矢印
    ax1.quiver(-12, 0, 2, 5, 0, 0, color='blue', arrow_length_ratio=0.3, linewidth=3)
    ax1.text(-12, 0, 4, '風向き →', color='blue', fontsize=12)
    
    ax1.set_xlabel('X (m)')
    ax1.set_ylabel('Y (m)')
    ax1.set_zlabel('Z (m)')
    ax1.set_title('3D表示：瓦礫と匂い源')
    ax1.view_init(elev=30, azim=45)
    
    # 2. XY平面（上から見た図）
    ax2 = fig.add_subplot(1, 3, 2)
    
    # 瓦礫の輪郭
    x_all = vectors[:, :, 0].flatten()
    y_all = vectors[:, :, 1].flatten()
    ax2.scatter(x_all[::20], y_all[::20], c='gray', s=1, alpha=0.3, label='瓦礫')
    
    # 匂い源
    circle = plt.Circle((odor_source['center'][0], odor_source['center'][1]), 
                        odor_source['radius'], color='red', alpha=0.8, label='匂い源')
    ax2.add_patch(circle)
    ax2.plot(odor_source['center'][0], odor_source['center'][1], 'r*', markersize=15)
    
    # 予想される匂いの拡散（概念図）
    theta = np.linspace(-np.pi/4, np.pi/4, 50)
    for r in [1, 2, 3, 4, 5]:
        x_plume = odor_source['center'][0] + r * np.cos(theta) + r
        y_plume = odor_source['center'][1] + r * np.sin(theta)
        ax2.plot(x_plume, y_plume, 'r--', alpha=0.2)
    
    # 風向き
    ax2.arrow(-10, 0, 3, 0, head_width=0.5, head_length=0.5, fc='blue', ec='blue')
    ax2.text(-10, 1, '風', color='blue', fontsize=12)
    
    ax2.set_xlabel('X (m)')
    ax2.set_ylabel('Y (m)')
    ax2.set_title('XY平面：匂い源と予想拡散パターン')
    ax2.set_aspect('equal')
    ax2.grid(True, alpha=0.3)
    ax2.legend()
    ax2.set_xlim([-15, 15])
    ax2.set_ylim([-20, 15])
    
    # 3. XZ平面（側面図）
    ax3 = fig.add_subplot(1, 3, 3)
    
    # 瓦礫の輪郭
    z_all = vectors[:, :, 2].flatten()
    ax3.scatter(x_all[::20], z_all[::20], c='gray', s=1, alpha=0.3, label='瓦礫')
    
    # 匂い源
    circle_xz = plt.Circle((odor_source['center'][0], odor_source['center'][2]), 
                           odor_source['radius'], color='red', alpha=0.8, label='匂い源')
    ax3.add_patch(circle_xz)
    ax3.plot(odor_source['center'][0], odor_source['center'][2], 'r*', markersize=15)
    
    # 匂いの上昇と拡散（概念図）
    x_rise = np.linspace(odor_source['center'][0], odor_source['center'][0] + 8, 50)
    z_rise = odor_source['center'][2] + 0.5 * np.log(1 + (x_rise - odor_source['center'][0]))
    ax3.plot(x_rise, z_rise, 'r--', alpha=0.5, label='匂い上昇')
    
    ax3.set_xlabel('X (m)')
    ax3.set_ylabel('Z (m)')
    ax3.set_title('XZ平面：匂い源と上昇パターン')
    ax3.grid(True, alpha=0.3)
    ax3.legend()
    ax3.set_xlim([-15, 15])
    ax3.set_ylim([-2, 8])
    
    # 全体タイトル
    fig.suptitle(f'匂い源の位置: ({odor_source["center"][0]}, {odor_source["center"][1]}, {odor_source["center"][2]}) m, 半径: {odor_source["radius"]} m', 
                 fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('odor_source_visualization.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("\n図を 'odor_source_visualization.png' として保存しました")
    print(f"\n匂い源情報:")
    print(f"  位置: ({odor_source['center'][0]}, {odor_source['center'][1]}, {odor_source['center'][2]}) m")
    print(f"  半径: {odor_source['radius']} m")
    print(f"  この点から継続的に匂いが放出されます")

if __name__ == "__main__":
    visualize_odor_source()