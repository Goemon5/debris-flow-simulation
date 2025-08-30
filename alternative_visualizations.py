#!/usr/bin/env python3
"""ParaView以外の可視化方法"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm
import os

def create_simple_odor_map():
    """簡単な匂いマップの作成（概念図）"""
    
    print("概念的な匂い拡散マップを作成中...")
    
    # 解析領域の設定
    x = np.linspace(-15, 15, 100)
    y = np.linspace(-20, 15, 120)
    X, Y = np.meshgrid(x, y)
    
    # 匂い源の位置
    source_x, source_y = 2, -3
    
    # 風向き（X方向）
    wind_speed = 1.0  # m/s
    
    # 簡単な拡散モデル（ガウシアンプルーム）
    def gaussian_plume(x, y, source_x, source_y, wind_speed, time):
        # 風下方向の距離
        x_rel = x - source_x
        y_rel = y - source_y
        
        # 風上は濃度ほぼゼロ
        mask = x_rel >= 0
        
        # 簡単な拡散係数
        sigma_y = 0.1 * np.sqrt(x_rel + 0.1)
        sigma_z = 0.05 * np.sqrt(x_rel + 0.1)
        
        # ガウシアン分布
        concentration = np.zeros_like(X)
        concentration[mask] = np.exp(-(y_rel[mask]**2) / (2 * sigma_y[mask]**2))
        
        # 距離による減衰
        distance = np.sqrt(x_rel**2 + y_rel**2)
        concentration *= np.exp(-distance / 10)  # 減衰
        
        return concentration
    
    # 複数の時間での拡散を計算
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    times = [1, 5, 10, 20]
    
    for idx, t in enumerate(times):
        ax = axes[idx//2, idx%2]
        
        # 濃度分布を計算
        conc = gaussian_plume(X, Y, source_x, source_y, wind_speed, t)
        
        # コンターマップ
        levels = np.linspace(0, 1, 21)
        contour = ax.contourf(X, Y, conc, levels=levels, cmap='Reds', alpha=0.7)
        ax.contour(X, Y, conc, levels=[0.1, 0.3, 0.5, 0.7, 0.9], colors='black', linewidths=0.5)
        
        # 匂い源
        ax.plot(source_x, source_y, 'r*', markersize=15, label='匂い源')
        
        # 瓦礫領域（概略）
        rect = plt.Rectangle((-10, -15), 20, 22, fill=False, 
                            edgecolor='gray', linewidth=2, alpha=0.7, label='瓦礫')
        ax.add_patch(rect)
        
        # 風向きの矢印
        ax.arrow(-12, 10, 4, 0, head_width=1, head_length=1, 
                 fc='blue', ec='blue', alpha=0.7)
        ax.text(-12, 12, f'風 {wind_speed} m/s', color='blue', fontsize=10)
        
        ax.set_xlabel('X (m)')
        ax.set_ylabel('Y (m)')
        ax.set_title(f'時刻 {t} 分後の匂い分布（概念図）')
        ax.set_xlim([-15, 15])
        ax.set_ylim([-20, 15])
        ax.set_aspect('equal')
        ax.grid(True, alpha=0.3)
        
        if idx == 0:
            ax.legend()
        
        # カラーバー
        plt.colorbar(contour, ax=ax, label='相対濃度')
    
    plt.suptitle('匂い拡散の概念図（ガウシアンプルームモデル）', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('odor_concept_map.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("概念図を 'odor_concept_map.png' として保存しました")

def create_3d_odor_cloud():
    """3D匂い雲の可視化"""
    
    print("3D匂い雲を作成中...")
    
    from mpl_toolkits.mplot3d import Axes3D
    
    # 3Dグリッドの作成
    x = np.linspace(-5, 25, 50)
    y = np.linspace(-15, 10, 40)
    z = np.linspace(0, 6, 25)
    X, Y, Z = np.meshgrid(x, y, z)
    
    # 匂い源
    source = np.array([2, -3, 0.5])
    
    # 距離計算
    distances = np.sqrt((X - source[0])**2 + (Y - source[1])**2 + (Z - source[2])**2)
    
    # 風による移流を考慮した濃度分布
    wind_effect = np.exp(-(X - source[0])**2 / 50) * (X >= source[0])  # 風下側のみ
    vertical_diffusion = np.exp(-(Z - source[2])**2 / 4)
    lateral_diffusion = np.exp(-(Y - source[1])**2 / 10)
    
    concentration = wind_effect * vertical_diffusion * lateral_diffusion
    concentration *= np.exp(-distances / 8)  # 距離による減衰
    
    # 3D可視化
    fig = plt.figure(figsize=(15, 10))
    
    # 等値面表示
    ax1 = fig.add_subplot(1, 2, 1, projection='3d')
    
    # 複数の等値面を表示
    for level, alpha, color in [(0.1, 0.1, 'blue'), (0.3, 0.3, 'green'), (0.5, 0.5, 'orange')]:
        try:
            from skimage import measure
            verts, faces, _, _ = measure.marching_cubes(concentration, level)
            # 座標を実際の値に変換
            verts[:, 0] = x[0] + verts[:, 0] * (x[-1] - x[0]) / (len(x) - 1)
            verts[:, 1] = y[0] + verts[:, 1] * (y[-1] - y[0]) / (len(y) - 1)
            verts[:, 2] = z[0] + verts[:, 2] * (z[-1] - z[0]) / (len(z) - 1)
            
            # 三角メッシュを表示
            ax1.plot_trisurf(verts[:, 0], verts[:, 1], verts[:, 2], 
                           triangles=faces, color=color, alpha=alpha)
        except ImportError:
            print("skimage がインストールされていません。等値面をスキップします。")
            break
    
    # 匂い源
    ax1.scatter([source[0]], [source[1]], [source[2]], 
               color='red', s=100, marker='*', label='匂い源')
    
    ax1.set_xlabel('X (m)')
    ax1.set_ylabel('Y (m)')
    ax1.set_zlabel('Z (m)')
    ax1.set_title('3D匂い雲（等値面表示）')
    ax1.legend()
    
    # 断面表示
    ax2 = fig.add_subplot(1, 2, 2, projection='3d')
    
    # Z=0.5での断面
    z_idx = np.abs(z - 0.5).argmin()
    conc_slice = concentration[:, :, z_idx]
    
    # 有意な濃度の点のみ表示
    thresh = 0.05
    mask = conc_slice > thresh
    y_grid, x_grid = np.meshgrid(y, x)
    
    colors = cm.Reds(conc_slice[mask.T] / np.max(conc_slice))
    ax2.scatter(x_grid[mask.T], y_grid[mask.T], 
               np.full(np.sum(mask), 0.5), 
               c=colors, s=20, alpha=0.7)
    
    # 匂い源
    ax2.scatter([source[0]], [source[1]], [source[2]], 
               color='red', s=100, marker='*')
    
    ax2.set_xlabel('X (m)')
    ax2.set_ylabel('Y (m)')
    ax2.set_zlabel('Z (m)')
    ax2.set_title('XY断面（Z=0.5m）での濃度分布')
    
    plt.tight_layout()
    plt.savefig('3d_odor_cloud.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("3D匂い雲を '3d_odor_cloud.png' として保存しました")

def create_time_series_animation_frames():
    """時系列アニメーション用フレームの作成"""
    
    print("時系列アニメーションフレームを作成中...")
    
    # フレーム用ディレクトリを作成
    os.makedirs('animation_frames', exist_ok=True)
    
    # パラメータ
    x = np.linspace(-15, 15, 80)
    y = np.linspace(-20, 15, 100)
    X, Y = np.meshgrid(x, y)
    
    source_x, source_y = 2, -3
    wind_speed = 1.0
    
    # 時間ステップ
    time_steps = np.linspace(0, 30, 31)  # 0-30分、1分間隔
    
    for i, t in enumerate(time_steps):
        fig, ax = plt.subplots(figsize=(12, 9))
        
        # 時間発展を考慮した拡散
        x_rel = X - source_x
        y_rel = Y - source_y
        
        # 風による移流
        effective_x = x_rel - wind_speed * t * 0.1  # 時間とともに移流
        
        # 拡散幅の時間発展
        sigma_y = 0.5 + 0.1 * np.sqrt(t + 1)
        sigma_x = 0.3 + 0.05 * np.sqrt(t + 1)
        
        # 濃度分布
        conc = np.exp(-(effective_x**2) / (2 * sigma_x**2)) * \
               np.exp(-(y_rel**2) / (2 * sigma_y**2)) * \
               np.exp(-t / 20)  # 時間による減衰
        
        # 風上側をマスク
        conc[x_rel < -wind_speed * t * 0.1] *= 0.1
        
        # コンタープロット
        levels = np.linspace(0, 1, 21)
        contour = ax.contourf(X, Y, conc, levels=levels, cmap='Reds', alpha=0.8)
        ax.contour(X, Y, conc, levels=[0.1, 0.3, 0.5, 0.7, 0.9], 
                   colors='darkred', linewidths=0.8)
        
        # 匂い源
        ax.plot(source_x, source_y, 'r*', markersize=20, markeredgecolor='black')
        
        # 瓦礫領域
        rect = plt.Rectangle((-10, -15), 20, 22, fill=False, 
                            edgecolor='gray', linewidth=3, alpha=0.8)
        ax.add_patch(rect)
        
        # 風向き
        ax.arrow(-12, 12, 4, 0, head_width=1, head_length=1, 
                 fc='blue', ec='blue', linewidth=2)
        ax.text(-12, 14, f'風速 {wind_speed} m/s', color='blue', fontsize=12, fontweight='bold')
        
        # 時刻表示
        ax.text(10, -18, f'時刻: {t:.1f} 分', fontsize=14, fontweight='bold',
                bbox=dict(boxstyle="round,pad=0.3", facecolor="white", alpha=0.8))
        
        ax.set_xlabel('X (m)', fontsize=12)
        ax.set_ylabel('Y (m)', fontsize=12)
        ax.set_title(f'匂い拡散シミュレーション - フレーム {i+1:02d}', fontsize=14, fontweight='bold')
        ax.set_xlim([-15, 15])
        ax.set_ylim([-20, 15])
        ax.set_aspect('equal')
        ax.grid(True, alpha=0.3)
        
        plt.colorbar(contour, label='相対濃度', shrink=0.8)
        plt.tight_layout()
        plt.savefig(f'animation_frames/frame_{i:03d}.png', dpi=100, bbox_inches='tight')
        plt.close()
    
    print(f"\n{len(time_steps)}枚のアニメーションフレームを作成しました")
    print("GIFアニメーション作成方法:")
    print("ImageMagickがインストールされている場合:")
    print("  convert -delay 20 -loop 0 animation_frames/frame_*.png odor_diffusion.gif")
    print("\nffmpegがインストールされている場合:")
    print("  ffmpeg -r 5 -i animation_frames/frame_%03d.png -y odor_diffusion.mp4")

def main():
    """メイン関数"""
    print("ParaView以外の可視化方法:")
    print("1. 概念的な匂い拡散マップ")
    print("2. 3D匂い雲の可視化")
    print("3. 時系列アニメーションフレーム")
    print()
    
    create_simple_odor_map()
    print()
    create_3d_odor_cloud()
    print()
    create_time_series_animation_frames()
    
    print("\n" + "="*50)
    print("その他の可視化ツール:")
    print("• VisIt (無料) - ParaViewの代替")
    print("• Blender (無料) - 3Dレンダリング")
    print("• Mayavi (Python) - 3D科学可視化")
    print("• Plotly (Python) - インタラクティブ3D")
    print("• VMD - 分子可視化ツール")
    print("="*50)

if __name__ == "__main__":
    main()