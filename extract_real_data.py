#!/usr/bin/env python3
"""
実際のOpenFOAMデータをCSV形式で抽出（VTK経由）
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
    
    # internalFieldセクションを抽出
    # nonuniform List<vector>の後の数値を探す
    pattern = r'internalField\s+nonuniform\s+List<vector>\s*\n(\d+)\s*\(\s*(.*?)\s*\);'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print("internalFieldが見つかりません")
        return None
    
    n_cells = int(match.group(1))
    data_section = match.group(2)
    print(f"セル数: {n_cells}")
    
    # ベクトルデータを抽出 (x y z)
    vector_pattern = r'\(\s*([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s*\)'
    vectors = re.findall(vector_pattern, data_section)
    
    if len(vectors) != n_cells:
        print(f"警告: 期待セル数 {n_cells}, 実際 {len(vectors)}")
    
    # numpy配列に変換
    data = []
    for vec in vectors:
        try:
            x, y, z = float(vec[0]), float(vec[1]), float(vec[2])
            data.append([x, y, z])
        except ValueError as e:
            print(f"変換エラー: {vec} -> {e}")
    
    return np.array(data)

def parse_openfoam_scalar_field(file_path):
    """OpenFOAM scalarフィールド（p）を解析"""
    print(f"解析中: {file_path}")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # internalFieldセクションを抽出
    pattern = r'internalField\s+nonuniform\s+List<scalar>\s*\n(\d+)\s*\(\s*(.*?)\s*\);'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print("internalFieldが見つかりません")
        return None
    
    n_cells = int(match.group(1))
    data_section = match.group(2)
    print(f"セル数: {n_cells}")
    
    # スカラー値を抽出
    scalar_pattern = r'([+-]?[\d.]+(?:[eE][+-]?\d+)?)'
    scalars = re.findall(scalar_pattern, data_section)
    
    if len(scalars) != n_cells:
        print(f"警告: 期待セル数 {n_cells}, 実際 {len(scalars)}")
    
    # numpy配列に変換
    data = []
    for scalar in scalars:
        try:
            data.append(float(scalar))
        except ValueError as e:
            print(f"変換エラー: {scalar} -> {e}")
    
    return np.array(data)

def extract_cell_centers_from_vtk(vtk_file):
    """VTKファイルからセル中心座標を抽出"""
    print(f"VTK解析中: {vtk_file}")
    
    try:
        with open(vtk_file, 'r') as f:
            content = f.read()
        
        # POINTSセクションを探す
        points_match = re.search(r'POINTS\s+(\d+)\s+float\s*\n(.*?)(?=\n\w|\n$)', content, re.DOTALL)
        if not points_match:
            print("POINTSセクションが見つかりません")
            return None
        
        n_points = int(points_match.group(1))
        points_data = points_match.group(2)
        
        # 座標を抽出
        coords = []
        numbers = re.findall(r'([+-]?[\d.]+(?:[eE][+-]?\d+)?)', points_data)
        
        for i in range(0, len(numbers) - 2, 3):
            try:
                x = float(numbers[i])
                y = float(numbers[i+1]) 
                z = float(numbers[i+2])
                coords.append([x, y, z])
            except (ValueError, IndexError):
                break
        
        print(f"抽出座標数: {len(coords)}")
        return np.array(coords[:n_points])
        
    except Exception as e:
        print(f"VTK読み込みエラー: {e}")
        return None

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

def create_real_csv(case_dir, time_dir, output_file):
    """実際のOpenFOAMデータからCSVを作成"""
    case_path = Path(case_dir)
    time_path = case_path / time_dir
    
    print(f"=== OpenFOAM実データ抽出開始 ===")
    print(f"ケース: {case_dir}")
    print(f"時刻: {time_dir}")
    
    # VTKファイルから座標を取得
    vtk_file = case_path / "VTK" / "workspace_10000.vtk"
    coords = None
    
    if vtk_file.exists():
        coords = extract_cell_centers_from_vtk(vtk_file)
    
    if coords is None:
        print("VTKからの座標取得に失敗、規則格子を使用")
        coords = create_grid_coordinates()
    
    print(f"使用座標数: {len(coords)}")
    
    # データフレーム初期化
    df_data = {
        'x': coords[:, 0],
        'y': coords[:, 1],
        'z': coords[:, 2]
    }
    
    # 流速データ読み込み
    u_file = time_path / 'U'
    if u_file.exists():
        u_data = parse_openfoam_vector_field(u_file)
        if u_data is not None:
            # データ数を座標数に合わせる
            n_coords = len(coords)
            if len(u_data) >= n_coords:
                df_data['Ux'] = u_data[:n_coords, 0]
                df_data['Uy'] = u_data[:n_coords, 1] 
                df_data['Uz'] = u_data[:n_coords, 2]
                print(f"✓ 流速データ読み込み成功: {len(u_data)}要素")
            else:
                print(f"警告: 流速データ不足 {len(u_data)} < {n_coords}")
                # 不足分は0で埋める
                u_padded = np.zeros((n_coords, 3))
                u_padded[:len(u_data)] = u_data
                df_data['Ux'] = u_padded[:, 0]
                df_data['Uy'] = u_padded[:, 1]
                df_data['Uz'] = u_padded[:, 2]
        else:
            print("流速データ読み込み失敗")
            df_data['Ux'] = np.zeros(len(coords))
            df_data['Uy'] = np.zeros(len(coords))
            df_data['Uz'] = np.zeros(len(coords))
    else:
        print(f"流速ファイルが見つかりません: {u_file}")
        df_data['Ux'] = np.zeros(len(coords))
        df_data['Uy'] = np.zeros(len(coords))
        df_data['Uz'] = np.zeros(len(coords))
    
    # 圧力データ読み込み
    p_file = time_path / 'p'
    if p_file.exists():
        p_data = parse_openfoam_scalar_field(p_file)
        if p_data is not None:
            n_coords = len(coords)
            if len(p_data) >= n_coords:
                df_data['pressure'] = p_data[:n_coords]
                print(f"✓ 圧力データ読み込み成功: {len(p_data)}要素")
            else:
                print(f"警告: 圧力データ不足 {len(p_data)} < {n_coords}")
                p_padded = np.zeros(n_coords)
                p_padded[:len(p_data)] = p_data
                df_data['pressure'] = p_padded
        else:
            print("圧力データ読み込み失敗")
            df_data['pressure'] = np.zeros(len(coords))
    else:
        print(f"圧力ファイルが見つかりません: {p_file}")
        df_data['pressure'] = np.zeros(len(coords))
    
    # 流速の大きさを計算
    df_data['velocity_magnitude'] = np.sqrt(
        df_data['Ux']**2 + df_data['Uy']**2 + df_data['Uz']**2
    )
    
    # DataFrame作成とCSV出力
    df = pd.DataFrame(df_data)
    df.to_csv(output_file, index=False)
    
    print(f"\n=== CSV出力完了 ===")
    print(f"出力ファイル: {output_file}")
    print(f"データ形状: {df.shape}")
    print(f"列: {list(df.columns)}")
    
    # 統計情報
    print(f"\n=== データ統計 ===")
    for col in ['Ux', 'Uy', 'Uz', 'velocity_magnitude', 'pressure']:
        if col in df.columns:
            print(f"{col}: {df[col].min():.6f} ～ {df[col].max():.6f} (平均: {df[col].mean():.6f})")
    
    return True

if __name__ == "__main__":
    case_dir = "/Users/takeuchidaiki/research/stepB_project/simulation_results/pattern_1/debrisCase"
    
    print("実際のOpenFOAMデータをCSV変換中...")
    success = create_real_csv(case_dir, "5", f"{case_dir}/real_openfoam_results.csv")
    
    if success:
        print("\n🎉 実データ抽出完了!")
        print("新しいファイル: real_openfoam_results.csv")
        print("このファイルをWebビューアにドラッグ&ドロップしてください。")
    else:
        print("\n❌ データ抽出に失敗しました。")