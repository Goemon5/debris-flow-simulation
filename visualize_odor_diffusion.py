#!/usr/bin/env python3
"""匂い拡散結果の可視化（matplotlib使用）"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm
from matplotlib.colors import LinearSegmentedColormap
import re
import os
from mpl_toolkits.mplot3d import Axes3D

def read_scalar_field(filepath):
    """OpenFOAMのスカラー場を読み込む"""
    if not os.path.exists(filepath):
        print(f"ファイルが見つかりません: {filepath}")
        return None
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # internalFieldのデータを抽出
    internal_match = re.search(r'internalField\s+nonuniform\s+List<scalar>\s*\n(\d+)\s*\n\(([\s\S]*?)\)', content)
    if internal_match:
        ncells = int(internal_match.group(1))
        values_str = internal_match.group(2)
        values = re.findall(r'([0-9.-e]+)', values_str)
        return np.array([float(v) for v in values[:ncells]])
    
    # uniform fieldの場合
    uniform_match = re.search(r'internalField\s+uniform\s+([0-9.-e]+)', content)
    if uniform_match:
        value = float(uniform_match.group(1))
        # 仮のセル数を設定（実際のメッシュサイズに合わせて調整が必要）
        return np.full(637147, value)  # 前回のメッシュサイズを使用
    
    return None

def read_mesh_centers(case_dir):
    """メッシュの中心座標を推定（簡易版）"""
    # 実際のメッシュサイズから推定
    # 領域: X[-15, 15], Y[-20, 15], Z[-2, 8]
    nx, ny, nz = 60, 70, 20  # blockMeshの分割数
    x = np.linspace(-15, 15, nx)
    y = np.linspace(-20, 15, ny)
    z = np.linspace(-2, 8, nz)
    
    # 3Dグリッドを作成
    X, Y, Z = np.meshgrid(x, y, z, indexing='ij')
    centers = np.column_stack([X.ravel(), Y.ravel(), Z.ravel()])
    
    return centers[:637147]  # 実際のセル数に合わせる

def visualize_odor_evolution():
    """匂い拡散の時間発展を可視化"""
    
    case_dir = "/Users/takeuchidaiki/research/stepB_project/debrisCase"
    
    # 時間ディレクトリを検索
    time_dirs = []
    for item in os.listdir(case_dir):
        if item.startswith('10') and os.path.isdir(os.path.join(case_dir, item)):
            try:
                time_dirs.append(int(item))
            except:
                pass
    
    if not time_dirs:
        print("時間ディレクトリが見つかりません")
        return
    
    time_dirs.sort()
    print(f"利用可能な時間ステップ: {time_dirs}")
    
    # 図の準備
    fig = plt.figure(figsize=(18, 12))
    
    # カスタムカラーマップ（透明から赤へ）
    colors = [(1, 1, 1, 0), (1, 0.9, 0, 0.3), (1, 0.5, 0, 0.6), (1, 0, 0, 1)]
    n_bins = 100
    cmap = LinearSegmentedColormap.from_list('odor', colors, N=n_bins)
    
    # メッシュ中心座標を取得
    centers = read_mesh_centers(case_dir)
    
    # 最大4つの時間ステップを表示
    n_plots = min(4, len(time_dirs))
    plot_times = time_dirs[-n_plots:]  # 最後のn個
    
    for idx, time in enumerate(plot_times):
        # スカラー場を読み込み
        s_file = os.path.join(case_dir, str(time), 's')
        s_values = read_scalar_field(s_file)
        
        if s_values is None:
            print(f"時刻{time}のデータ読み込み失敗")
            continue
        
        # データサンプリング
        n_samples = min(10000, len(s_values))
        sample_idx = np.random.choice(len(s_values), n_samples, replace=False)
        
        x = centers[sample_idx, 0]
        y = centers[sample_idx, 1]
        z = centers[sample_idx, 2]
        s = s_values[sample_idx]
        
        # 有意な濃度のみ表示（閾値以上）
        threshold = 0.01
        mask = s > threshold
        
        # 1. XY平面（Z=0.5付近）
        ax1 = fig.add_subplot(n_plots, 3, idx*3 + 1)
        z_slice = np.abs(z - 0.5) < 0.5
        if np.any(z_slice & mask):
            scatter = ax1.scatter(x[z_slice & mask], y[z_slice & mask], 
                                c=s[z_slice & mask], cmap=cmap, 
                                s=20, alpha=0.7, vmin=0, vmax=1)
            plt.colorbar(scatter, ax=ax1, label='濃度')
        
        # 匂い源位置を表示
        ax1.plot(2, -3, 'r*', markersize=15, label='匂い源')
        
        # 瓦礫領域（概略）
        rect = plt.Rectangle((-10, -15), 20, 22, fill=False, 
                            edgecolor='gray', linewidth=1, alpha=0.3)
        ax1.add_patch(rect)
        
        ax1.set_xlabel('X (m)')
        ax1.set_ylabel('Y (m)')
        ax1.set_title(f'XY平面 (Z≈0.5m) - 時刻{time}')
        ax1.set_xlim([-15, 15])
        ax1.set_ylim([-20, 15])
        ax1.set_aspect('equal')
        ax1.grid(True, alpha=0.3)
        if idx == 0:
            ax1.legend()
        
        # 2. XZ平面（Y=-3付近、匂い源を通る）
        ax2 = fig.add_subplot(n_plots, 3, idx*3 + 2)
        y_slice = np.abs(y + 3) < 1  # Y=-3付近
        if np.any(y_slice & mask):
            scatter = ax2.scatter(x[y_slice & mask], z[y_slice & mask], 
                                c=s[y_slice & mask], cmap=cmap, 
                                s=20, alpha=0.7, vmin=0, vmax=1)
            plt.colorbar(scatter, ax=ax2, label='濃度')
        
        # 匂い源位置
        ax2.plot(2, 0.5, 'r*', markersize=15)
        
        ax2.set_xlabel('X (m)')
        ax2.set_ylabel('Z (m)')
        ax2.set_title(f'XZ平面 (Y≈-3m) - 時刻{time}')
        ax2.set_xlim([-15, 15])
        ax2.set_ylim([-2, 8])
        ax2.grid(True, alpha=0.3)
        
        # 3. 3D表示
        ax3 = fig.add_subplot(n_plots, 3, idx*3 + 3, projection='3d')
        
        # 高濃度領域のみ表示
        high_conc = s > 0.1
        if np.any(high_conc):
            n_3d = min(2000, np.sum(high_conc))
            idx_3d = np.random.choice(np.where(high_conc)[0], n_3d, replace=False)
            
            scatter = ax3.scatter(x[idx_3d], y[idx_3d], z[idx_3d], 
                                c=s[idx_3d], cmap=cmap, 
                                s=5, alpha=0.5, vmin=0, vmax=1)
        
        # 匂い源
        ax3.scatter([2], [-3], [0.5], color='red', s=100, marker='*')
        
        ax3.set_xlabel('X (m)')
        ax3.set_ylabel('Y (m)')
        ax3.set_zlabel('Z (m)')
        ax3.set_title(f'3D濃度分布 - 時刻{time}')
        ax3.set_xlim([-15, 15])
        ax3.set_ylim([-20, 15])
        ax3.set_zlim([-2, 8])
        ax3.view_init(elev=20, azim=45)
    
    plt.suptitle('匂い拡散シミュレーション結果', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('odor_diffusion_results.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("\n図を 'odor_diffusion_results.png' として保存しました")

def create_concentration_profile():
    """濃度プロファイルのグラフを作成"""
    
    case_dir = "/Users/takeuchidaiki/research/stepB_project/debrisCase"
    
    # 最新の時間ステップを取得
    time_dirs = []
    for item in os.listdir(case_dir):
        if item.startswith('10') and os.path.isdir(os.path.join(case_dir, item)):
            try:
                time_dirs.append(int(item))
            except:
                pass
    
    if not time_dirs:
        print("データが見つかりません")
        return
    
    latest_time = max(time_dirs)
    print(f"最新時刻: {latest_time}")
    
    # データ読み込み
    s_file = os.path.join(case_dir, str(latest_time), 's')
    s_values = read_scalar_field(s_file)
    
    if s_values is None:
        print("データ読み込み失敗")
        return
    
    # 統計情報
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # 1. 濃度ヒストグラム
    ax1 = axes[0, 0]
    s_nonzero = s_values[s_values > 1e-6]
    if len(s_nonzero) > 0:
        ax1.hist(s_nonzero, bins=50, edgecolor='black', alpha=0.7)
        ax1.set_xlabel('濃度')
        ax1.set_ylabel('セル数')
        ax1.set_title('濃度分布ヒストグラム')
        ax1.set_yscale('log')
        ax1.grid(True, alpha=0.3)
    
    # 2. 累積分布
    ax2 = axes[0, 1]
    if len(s_nonzero) > 0:
        sorted_s = np.sort(s_nonzero)
        cumsum = np.arange(1, len(sorted_s) + 1) / len(sorted_s)
        ax2.plot(sorted_s, cumsum, linewidth=2)
        ax2.set_xlabel('濃度')
        ax2.set_ylabel('累積確率')
        ax2.set_title('濃度の累積分布')
        ax2.grid(True, alpha=0.3)
    
    # 3. 統計情報テキスト
    ax3 = axes[1, 0]
    ax3.axis('off')
    
    stats_text = f"""
    匂い拡散統計（時刻: {latest_time}）
    =====================================
    
    総セル数: {len(s_values):,}
    
    濃度が0より大きいセル: {len(s_nonzero):,}
    ({100*len(s_nonzero)/len(s_values):.2f}%)
    
    最大濃度: {np.max(s_values):.6f}
    平均濃度: {np.mean(s_values):.6f}
    中央値: {np.median(s_values):.6f}
    
    匂い源情報:
    • 位置: (2, -3, 0.5) m
    • 半径: 0.3 m
    • 初期濃度: 1.0
    """
    
    ax3.text(0.1, 0.5, stats_text, fontsize=11, 
             verticalalignment='center', family='monospace')
    
    # 4. 距離vs濃度（簡易版）
    ax4 = axes[1, 1]
    centers = read_mesh_centers(case_dir)
    source = np.array([2, -3, 0.5])
    distances = np.linalg.norm(centers - source, axis=1)
    
    # 距離ビンごとの平均濃度
    dist_bins = np.linspace(0, 20, 21)
    avg_conc = []
    for i in range(len(dist_bins)-1):
        mask = (distances >= dist_bins[i]) & (distances < dist_bins[i+1])
        if np.any(mask):
            avg_conc.append(np.mean(s_values[mask]))
        else:
            avg_conc.append(0)
    
    ax4.bar(dist_bins[:-1], avg_conc, width=0.8, alpha=0.7, edgecolor='black')
    ax4.set_xlabel('匂い源からの距離 (m)')
    ax4.set_ylabel('平均濃度')
    ax4.set_title('距離による濃度減衰')
    ax4.grid(True, alpha=0.3)
    
    plt.suptitle('匂い拡散の統計解析', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig('odor_statistics.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("\n図を 'odor_statistics.png' として保存しました")

if __name__ == "__main__":
    print("匂い拡散結果を可視化中...")
    visualize_odor_evolution()
    create_concentration_profile()