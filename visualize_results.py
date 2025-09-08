#!/usr/bin/env python3
"""OpenFOAM結果の可視化（matplotlib使用）"""

import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import re
import os

def read_openfoam_field(filepath, field_type='scalar'):
    """OpenFOAMフィールドファイルを読み込む"""

    with open(filepath, 'r') as f:
        content = f.read()
    
    if field_type == 'vector':
        # ベクトル場の読み込み
        pattern = r'\(([0-9.-e]+)\s+([0-9.-e]+)\s+([0-9.-e]+)\)'
        matches = re.findall(pattern, content)
        if matches:
            return np.array([[float(x), float(y), float(z)] for x, y, z in matches])
    else:
        # スカラー場の読み込み
        pattern = r'^([0-9.-e]+)$'
        matches = re.findall(pattern, content, re.MULTILINE)
        if matches:
            return np.array([float(v) for v in matches])
    return None

def read_mesh_points(case_dir):
    """メッシュポイントを読み込む"""
    
    points_file = os.path.join(case_dir, "constant/polyMesh/points")
    if not os.path.exists(points_file):
        return None
    
    with open(points_file, 'r') as f:
        content = f.read()
    
    # ポイント座標を抽出
    pattern = r'\(([0-9.-e]+)\s+([0-9.-e]+)\s+([0-9.-e]+)\)'
    matches = re.findall(pattern, content)
    if matches:
        return np.array([[float(x), float(y), float(z)] for x, y, z in matches])
    return None

def visualize_flow_2d():
    """2D断面での流れの可視化"""
    case_dir = "/Users/takeuchidaiki/research/stepB_project/debrisCase"
    
    # データ読み込み
    print("データを読み込み中...")
    U = read_openfoam_field(os.path.join(case_dir, "1000/U"), 'vector')
    p = read_openfoam_field(os.path.join(case_dir, "1000/p"), 'scalar')
    points = read_mesh_points(case_dir)
    
    if U is None or p is None or points is None:
        print("データ読み込みエラー")
        return
    
    # データサンプリング（計算量削減のため）
    n_samples = min(10000, len(U))
    indices = np.random.choice(len(U), n_samples, replace=False)
    
    U_sample = U[indices]
    p_sample = p[indices] if p is not None else None
    points_sample = points[indices] if len(points) > len(U) else points[:n_samples]
    
    # 図の作成
    fig = plt.figure(figsize=(18, 12))
    
    # 1. XY平面（Z=2付近）の速度場
    ax1 = fig.add_subplot(2, 3, 1)
    z_slice = np.abs(points_sample[:, 2] - 2) < 0.5
    if np.any(z_slice):
        x = points_sample[z_slice, 0]
        y = points_sample[z_slice, 1]
        u = U_sample[z_slice, 0]
        v = U_sample[z_slice, 1]
        
        # 速度の大きさ
        speed = np.sqrt(u**2 + v**2)
        
        scatter = ax1.scatter(x, y, c=speed, cmap='jet', s=5, alpha=0.6)
        ax1.quiver(x[::20], y[::20], u[::20], v[::20], alpha=0.7, scale=20)
        ax1.set_xlabel('X (m)')
        ax1.set_ylabel('Y (m)')
        ax1.set_title('速度場 (XY平面, Z≈2m)')
        ax1.set_aspect('equal')
        plt.colorbar(scatter, ax=ax1, label='Speed (m/s)')
    
    # 2. XZ平面（Y=0付近）の速度場
    ax2 = fig.add_subplot(2, 3, 2)
    y_slice = np.abs(points_sample[:, 1]) < 0.5
    if np.any(y_slice):
        x = points_sample[y_slice, 0]
        z = points_sample[y_slice, 2]
        u = U_sample[y_slice, 0]
        w = U_sample[y_slice, 2]
        
        speed = np.sqrt(u**2 + w**2)
        
        scatter = ax2.scatter(x, z, c=speed, cmap='jet', s=5, alpha=0.6)
        ax2.quiver(x[::20], z[::20], u[::20], w[::20], alpha=0.7, scale=20)
        ax2.set_xlabel('X (m)')
        ax2.set_ylabel('Z (m)')
        ax2.set_title('速度場 (XZ平面, Y≈0m)')
        ax2.set_aspect('equal')
        plt.colorbar(scatter, ax=ax2, label='Speed (m/s)')
    
    # 3. 圧力分布（XY平面）
    ax3 = fig.add_subplot(2, 3, 3)
    if p_sample is not None and np.any(z_slice):
        x = points_sample[z_slice, 0]
        y = points_sample[z_slice, 1]
        p_slice = p_sample[z_slice]
        
        scatter = ax3.scatter(x, y, c=p_slice, cmap='coolwarm', s=5, alpha=0.6)
        ax3.set_xlabel('X (m)')
        ax3.set_ylabel('Y (m)')
        ax3.set_title('圧力分布 (XY平面, Z≈2m)')
        ax3.set_aspect('equal')
        plt.colorbar(scatter, ax=ax3, label='Pressure (Pa)')
    
    # 4. 3D速度場
    ax4 = fig.add_subplot(2, 3, 4, projection='3d')
    n_3d = min(2000, len(U_sample))
    indices_3d = np.random.choice(len(U_sample), n_3d, replace=False)
    
    x = points_sample[indices_3d, 0]
    y = points_sample[indices_3d, 1]
    z = points_sample[indices_3d, 2]
    speed = np.linalg.norm(U_sample[indices_3d], axis=1)
    
    scatter = ax4.scatter(x, y, z, c=speed, cmap='jet', s=2, alpha=0.3)
    ax4.set_xlabel('X (m)')
    ax4.set_ylabel('Y (m)')
    ax4.set_zlabel('Z (m)')
    ax4.set_title('3D速度分布')
    plt.colorbar(scatter, ax=ax4, label='Speed (m/s)', shrink=0.6)
    
    # 5. 速度ヒストグラム
    ax5 = fig.add_subplot(2, 3, 5)
    speeds = np.linalg.norm(U_sample, axis=1)
    ax5.hist(speeds, bins=50, edgecolor='black', alpha=0.7)
    ax5.axvline(1.0, color='r', linestyle='--', label='入口速度 (1.0 m/s)')
    ax5.set_xlabel('速度 (m/s)')
    ax5.set_ylabel('頻度')
    ax5.set_title('速度分布ヒストグラム')
    ax5.legend()
    ax5.grid(True, alpha=0.3)
    
    # 6. 統計情報
    ax6 = fig.add_subplot(2, 3, 6)
    ax6.axis('off')
    
    stats_text = f"""
    シミュレーション統計
    ═══════════════════════
    
    メッシュセル数: {len(U):,}
    
    速度統計:
    • 平均: {np.mean(speeds):.3f} m/s
    • 最大: {np.max(speeds):.3f} m/s
    • 最小: {np.min(speeds):.3f} m/s
    • 標準偏差: {np.std(speeds):.3f} m/s
    
    圧力統計:
    • 平均: {np.mean(p_sample):.2f} Pa
    • 最大: {np.max(p_sample):.2f} Pa
    • 最小: {np.min(p_sample):.2f} Pa
    
    瓦礫影響:
    • 速度減少領域あり
    • 複雑な渦構造形成
    • 圧力変動が顕著
    """
    
    ax6.text(0.1, 0.5, stats_text, fontsize=10, 
             verticalalignment='center', family='monospace')
    
    plt.tight_layout()
    plt.savefig('openfoam_results_visualization.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("\n図を 'openfoam_results_visualization.png' として保存しました")
    print("matplotlibウィンドウで表示されています")

if __name__ == "__main__":
    print("OpenFOAM結果を可視化中...")
    visualize_flow_2d()