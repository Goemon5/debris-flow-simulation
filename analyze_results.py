#!/usr/bin/env python3
"""OpenFOAM結果の分析"""

import numpy as np
import re
import os

def analyze_openfoam_results():
    print("="*60)
    print("OpenFOAM シミュレーション結果分析")
    print("="*60)
    
    # 時間ステップの確認
    case_dir = "/Users/takeuchidaiki/research/stepB_project/debrisCase"
    time_dirs = []
    
    for item in os.listdir(case_dir):
        if os.path.isdir(os.path.join(case_dir, item)) and item.replace('.', '').isdigit():
            time_dirs.append(float(item))
    
    time_dirs.sort()
    print(f"\n1. 時間ステップ:")
    print(f"   - 開始: {min(time_dirs)}")
    print(f"   - 終了: {max(time_dirs)}")
    print(f"   - ステップ数: {len(time_dirs)}")
    
    # メッシュ情報
    boundary_file = os.path.join(case_dir, "constant/polyMesh/boundary")
    if os.path.exists(boundary_file):
        with open(boundary_file, 'r') as f:
            content = f.read()
        
        print(f"\n2. 境界面情報:")
        boundaries = re.findall(r'(\w+)\s*\{\s*type\s+(\w+);\s*(?:inGroups.*?)?\s*nFaces\s+(\d+);', content, re.DOTALL)
        total_faces = 0
        for name, btype, nfaces in boundaries:
            nfaces = int(nfaces)
            total_faces += nfaces
            print(f"   - {name}: {btype} ({nfaces:,} faces)")
        print(f"   - 総境界面数: {total_faces:,}")
    
    # 最終結果の解析
    final_time = str(int(max(time_dirs)))
    final_dir = os.path.join(case_dir, final_time)
    
    print(f"\n3. 最終時刻({final_time})の結果:")
    
    # 速度場の解析
    u_file = os.path.join(final_dir, "U")
    if os.path.exists(u_file):
        with open(u_file, 'r') as f:
            content = f.read()
        
        # セル数を取得
        cell_match = re.search(r'nonuniform List<vector>\s*\n(\d+)', content)
        if cell_match:
            ncells = int(cell_match.group(1))
            print(f"   - メッシュセル数: {ncells:,} cells")
        
        # 速度値のサンプル
        velocity_match = re.findall(r'\(([0-9.-]+)\s+([0-9.-e]+)\s+([0-9.-e]+)\)', content)
        if velocity_match:
            velocities = np.array([[float(x), float(y), float(z)] for x, y, z in velocity_match[:1000]])
            speed = np.linalg.norm(velocities, axis=1)
            
            print(f"   - 速度統計 (最初の1000セル):")
            print(f"     * 平均速度: {np.mean(speed):.4f} m/s")
            print(f"     * 最大速度: {np.max(speed):.4f} m/s")
            print(f"     * 最小速度: {np.min(speed):.4f} m/s")
            print(f"     * X方向平均: {np.mean(velocities[:, 0]):.4f} m/s")
            print(f"     * Y方向平均: {np.mean(velocities[:, 1]):.6f} m/s")
            print(f"     * Z方向平均: {np.mean(velocities[:, 2]):.4f} m/s")
    
    # 圧力場の解析
    p_file = os.path.join(final_dir, "p")
    if os.path.exists(p_file):
        with open(p_file, 'r') as f:
            content = f.read()
        
        pressure_values = re.findall(r'^([0-9.-e]+)$', content, re.MULTILINE)
        if pressure_values:
            pressures = np.array([float(p) for p in pressure_values[:1000]])
            
            print(f"   - 圧力統計 (最初の1000セル):")
            print(f"     * 平均圧力: {np.mean(pressures):.6f} Pa")
            print(f"     * 最大圧力: {np.max(pressures):.6f} Pa")
            print(f"     * 最小圧力: {np.min(pressures):.6f} Pa")
            print(f"     * 圧力範囲: {np.max(pressures) - np.min(pressures):.6f} Pa")
    
    print(f"\n4. 物理的解釈:")
    print(f"   - 流入速度: 1.0 m/s (X方向)")
    print(f"   - 瓦礫による流れの偏向と渦生成")
    print(f"   - 瓦礫後方での圧力回復")
    print(f"   - 複雑な3D流れパターンの形成")
    
    print(f"\n5. 推奨する可視化:")
    print(f"   - 速度ベクトル表示（瓦礫周辺の流れ）")
    print(f"   - 圧力コンター表示（高低圧領域）")
    print(f"   - 流線表示（流れの軌跡）")
    print(f"   - 断面表示（内部流れ構造）")
    
    print("\n" + "="*60)

if __name__ == "__main__":
    analyze_openfoam_results()