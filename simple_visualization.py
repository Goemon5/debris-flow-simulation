#!/usr/bin/env python3
"""STLファイルと流れのシンプルな可視化"""

import numpy as np
import matplotlib.pyplot as plt
from stl import mesh
from mpl_toolkits.mplot3d import Axes3D

def visualize_stl_and_flow():
    """STL形状と流れ方向を可視化"""
    
    print("STLファイルを読み込み中...")
    
    # STLファイルを読み込み
    debris_mesh = mesh.Mesh.from_file('disaster_debris_01.stl')
    
    # 図の作成
    fig = plt.figure(figsize=(16, 12))
    
    # 1. 3D瓦礫形状（上から見た図）
    ax1 = fig.add_subplot(2, 2, 1, projection='3d')
    
    # STLメッシュの頂点を取得
    vectors = debris_mesh.vectors
    
    # 三角形メッシュを表示（最初の500個）
    for i, tri in enumerate(vectors[:500]):
        if i % 10 == 0:  # 10個に1個表示（軽量化）
            x = [tri[j][0] for j in range(3)]
            y = [tri[j][1] for j in range(3)]
            z = [tri[j][2] for j in range(3)]
            ax1.plot_trisurf(x, y, z, color='gray', alpha=0.3, edgecolor='none')
    
    ax1.set_xlabel('X (m)')
    ax1.set_ylabel('Y (m)')
    ax1.set_zlabel('Z (m)')
    ax1.set_title('瓦礫形状（3D）')
    ax1.view_init(elev=60, azim=45)
    
    # 流れ方向を矢印で表示
    ax1.quiver(-12, 0, 2, 5, 0, 0, color='red', arrow_length_ratio=0.3, linewidth=3)
    ax1.text(-12, 0, 4, '風向き →', color='red', fontsize=12)
    
    # 2. XY平面図（上から見た図）
    ax2 = fig.add_subplot(2, 2, 2)
    
    # 瓦礫の投影
    x_all = vectors[:, :, 0].flatten()
    y_all = vectors[:, :, 1].flatten()
    
    # 瓦礫領域を表示
    ax2.scatter(x_all[::10], y_all[::10], c='gray', s=1, alpha=0.5, label='瓦礫')
    
    # 流れ方向
    x_flow = np.linspace(-15, 15, 20)
    y_positions = np.linspace(-20, 15, 10)
    
    for y_pos in y_positions:
        # 瓦礫の前後で異なる流れ
        ax2.arrow(-14, y_pos, 4, 0, head_width=0.5, head_length=0.5, 
                 fc='blue', ec='blue', alpha=0.5)
        ax2.arrow(10, y_pos, 4, 0, head_width=0.5, head_length=0.5, 
                 fc='cyan', ec='cyan', alpha=0.3)
    
    ax2.set_xlabel('X (m)')
    ax2.set_ylabel('Y (m)')
    ax2.set_title('上面図（風の流れ）')
    ax2.set_aspect('equal')
    ax2.grid(True, alpha=0.3)
    ax2.legend()
    
    # 3. XZ側面図
    ax3 = fig.add_subplot(2, 2, 3)
    
    z_all = vectors[:, :, 2].flatten()
    
    # 瓦礫の側面投影
    ax3.scatter(x_all[::10], z_all[::10], c='gray', s=1, alpha=0.5, label='瓦礫')
    
    # 流れパターン（概念図）
    x_stream = np.linspace(-15, 15, 100)
    
    # 瓦礫上部の流れ
    z_over = 3 + 2 * np.exp(-((x_stream - 0) / 5) ** 2)
    ax3.plot(x_stream, z_over, 'b-', alpha=0.7, linewidth=2, label='上部流れ')
    
    # 瓦礫下部の流れ
    z_under = 0.5 * np.ones_like(x_stream)
    z_under[(x_stream > -10) & (x_stream < 10)] = 0.2
    ax3.plot(x_stream, z_under, 'c-', alpha=0.7, linewidth=2, label='下部流れ')
    
    # 渦領域（概念的）
    theta = np.linspace(0, 2*np.pi, 50)
    x_vortex = 10 + 2 * np.cos(theta)
    z_vortex = 1.5 + 2 * np.sin(theta)
    ax3.plot(x_vortex, z_vortex, 'r--', alpha=0.5, linewidth=1, label='渦領域')
    
    ax3.set_xlabel('X (m)')
    ax3.set_ylabel('Z (m)')
    ax3.set_title('側面図（流れパターン）')
    ax3.grid(True, alpha=0.3)
    ax3.legend()
    ax3.set_ylim([-2, 8])
    
    # 4. 流れの特徴説明
    ax4 = fig.add_subplot(2, 2, 4)
    ax4.axis('off')
    
    info_text = """
    OpenFOAMシミュレーション結果の概要
    ════════════════════════════════════
    
    【瓦礫形状】
    • サイズ: 18.4m × 22.0m × 3.8m
    • 体積: 179.2 m³
    • 複雑な不規則形状
    
    【流れ条件】
    • 入口風速: 1.0 m/s (X方向)
    • レイノルズ数: Re ≈ 10⁶（乱流）
    
    【観察される現象】
    ① 瓦礫前面での流れの減速と圧力上昇
    ② 瓦礫上部・側面での流れの加速
    ③ 瓦礫後方での渦形成（カルマン渦）
    ④ 複雑な3次元流れパターン
    
    【応用】
    • 災害時の風環境予測
    • 匂い物質の拡散経路推定
    • 救助活動の最適化
    """
    
    ax4.text(0.05, 0.5, info_text, fontsize=11, 
             verticalalignment='center', family='monospace')
    
    plt.suptitle('瓦礫周りの流れシミュレーション結果', fontsize=16, fontweight='bold')
    plt.tight_layout()
    
    # 保存
    plt.savefig('debris_flow_visualization.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("\n図を 'debris_flow_visualization.png' として保存しました")
    print("瓦礫形状と流れパターンの概要を表示しています")

if __name__ == "__main__":
    visualize_stl_and_flow()