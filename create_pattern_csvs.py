#!/usr/bin/env python3
"""
各パターンのOpenFOAMデータをCSV形式で個別抽出
"""

import numpy as np
import pandas as pd
import re
from pathlib import Path

def parse_openfoam_vector_field(file_path):
    """OpenFOAM vectorフィールド（U）を解析"""
    print(f"解析中: {file_path}")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    pattern = r'internalField\s+nonuniform\s+List<vector>\s*\n(\d+)\s*\(\s*(.*?)\s*\);'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print("internalFieldが見つかりません")
        return None
    
    n_cells = int(match.group(1))
    data_section = match.group(2)
    print(f"セル数: {n_cells}")
    
    vector_pattern = r'\(\s*([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s*\)'
    vectors = re.findall(vector_pattern, data_section)
    
    data = []
    for vec in vectors:
        try:
            x, y, z = float(vec[0]), float(vec[1]), float(vec[2])
            data.append([x, y, z])
        except ValueError as e:
            print(f"変換エラー: {vec} -> {e}")
    
    return np.array(data)

def create_grid_coordinates(nx=30, ny=30, nz=10):
    """規則格子の座標を生成"""
    x = np.linspace(0.25, 14.75, nx)
    y = np.linspace(0.25, 14.75, ny) 
    z = np.linspace(0.25, 4.75, nz)
    
    coords = []
    for k in range(nz):
        for j in range(ny):
            for i in range(nx):
                coords.append([x[i], y[j], z[k]])
    
    return np.array(coords)

def create_pattern_csv(pattern_num):
    """特定パターンのCSVを作成"""
    case_dir = f"simulation_results/pattern_{pattern_num}/debrisCase"
    case_path = Path(case_dir)
    
    print(f"\n=== パターン{pattern_num} データ抽出 ===")
    
    # 時刻ディレクトリを確認
    time_dirs = [d.name for d in case_path.iterdir() if d.is_dir() and d.name.replace('.', '').isdigit()]
    time_dirs.sort(key=float)
    
    if not time_dirs:
        print(f"時刻ディレクトリが見つかりません: {case_dir}")
        return
    
    # 最後の時刻を使用
    last_time = time_dirs[-1]
    print(f"使用時刻: {last_time}")
    
    # 流速データを読み込み
    u_file = case_path / last_time / "U"
    if not u_file.exists():
        print(f"流速ファイルが見つかりません: {u_file}")
        return
    
    velocity_data = parse_openfoam_vector_field(u_file)
    if velocity_data is None:
        print("流速データの読み込みに失敗")
        return
    
    print(f"✓ 流速データ読み込み成功: {len(velocity_data)}要素")
    
    # 座標データを生成（規則格子）
    coords = create_grid_coordinates()
    n_points = min(len(coords), len(velocity_data))
    
    # データを組み合わせ
    df_data = {
        'x': coords[:n_points, 0],
        'y': coords[:n_points, 1], 
        'z': coords[:n_points, 2],
        'Ux': velocity_data[:n_points, 0],
        'Uy': velocity_data[:n_points, 1],
        'Uz': velocity_data[:n_points, 2],
        'pressure': np.zeros(n_points),  # 圧力は0で初期化
        'velocity_magnitude': np.sqrt(
            velocity_data[:n_points, 0]**2 + 
            velocity_data[:n_points, 1]**2 + 
            velocity_data[:n_points, 2]**2
        )
    }
    
    df = pd.DataFrame(df_data)
    
    # CSVファイルとして出力
    output_file = f"pattern_{pattern_num}_results.csv"
    df.to_csv(output_file, index=False)
    
    print(f"=== CSV出力完了 ===")
    print(f"出力ファイル: {output_file}")
    print(f"データ形状: {df.shape}")
    
    # 統計情報表示
    print(f"\n=== データ統計 ===")
    print(f"Ux: {df['Ux'].min():.6f} ～ {df['Ux'].max():.6f} (平均: {df['Ux'].mean():.6f})")
    print(f"Uy: {df['Uy'].min():.6f} ～ {df['Uy'].max():.6f} (平均: {df['Uy'].mean():.6f})")
    print(f"Uz: {df['Uz'].min():.6f} ～ {df['Uz'].max():.6f} (平均: {df['Uz'].mean():.6f})")
    print(f"velocity_magnitude: {df['velocity_magnitude'].min():.6f} ～ {df['velocity_magnitude'].max():.6f} (平均: {df['velocity_magnitude'].mean():.6f})")
    
    return output_file

if __name__ == "__main__":
    print("全パターンのCSVデータを生成中...")
    
    csv_files = []
    for i in range(1, 6):
        result = create_pattern_csv(i)
        if result:
            csv_files.append(result)
    
    print(f"\n🎉 生成完了!")
    print("生成されたCSVファイル:")
    for csv_file in csv_files:
        print(f"  - {csv_file}")
    print("\nこれらのファイルをWebビューア（openfoam_csv_viewer.html）にドラッグ&ドロップしてください。")