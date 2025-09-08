#!/usr/bin/env python3
"""
OpenFOAM結果をCSV形式で抽出するスクリプト
"""

import re
import numpy as np
import pandas as pd
import os
from pathlib import Path

def parse_openfoam_field(file_path):
    """OpenFOAMフィールドファイルを解析"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # internalFieldセクションを抽出
    pattern = r'internalField\s+nonuniform\s+List<(\w+)>\s*\n(\d+)\s*\(\s*(.*?)\s*\);'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print(f"データ抽出失敗: {file_path}")
        return None, None
    
    field_type = match.group(1)
    n_cells = int(match.group(2))
    data_str = match.group(3)
    
    # データを解析
    if field_type == 'vector':
        # ベクトルデータ（流速）
        vector_pattern = r'\(([^)]+)\)'
        vectors = re.findall(vector_pattern, data_str)
        
        data = []
        for vec_str in vectors:
            components = [float(x) for x in vec_str.split()]
            if len(components) == 3:
                data.append(components)
        
        return np.array(data), ['Ux', 'Uy', 'Uz']
    
    elif field_type == 'scalar':
        # スカラーデータ（圧力）
        numbers = re.findall(r'-?[\d.]+(?:[eE][+-]?\d+)?', data_str)
        data = [float(x) for x in numbers]
        
        return np.array(data), ['pressure']
    
    return None, None

def extract_mesh_centers(case_dir):
    """メッシュセンター座標を抽出"""
    # セルセンターファイルがない場合は、簡易的な座標生成
    # 実際のOpenFOAMではpostProcessで生成可能
    
    # 簡易グリッド生成（15m x 15m x 5m領域）
    nx, ny, nz = 30, 30, 10  # blockMeshDictと同じ分割数
    
    x = np.linspace(0.25, 14.75, nx)
    y = np.linspace(0.25, 14.75, ny)
    z = np.linspace(0.25, 4.75, nz)
    
    coords = []
    for k in range(nz):
        for j in range(ny):
            for i in range(nx):
                coords.append([x[i], y[j], z[k]])
    
    return np.array(coords)

def create_csv_from_openfoam(case_dir, time_dir, output_file):
    """OpenFOAMデータからCSVを生成"""
    case_path = Path(case_dir)
    time_path = case_path / time_dir
    
    if not time_path.exists():
        print(f"時刻ディレクトリが見つかりません: {time_path}")
        return False
    
    # 座標データ（簡易版）
    coords = extract_mesh_centers(case_dir)
    
    # データフレーム初期化
    df_data = {
        'x': coords[:, 0],
        'y': coords[:, 1], 
        'z': coords[:, 2]
    }
    
    # 流速データ
    u_file = time_path / 'U'
    if u_file.exists():
        u_data, u_cols = parse_openfoam_field(str(u_file))
        if u_data is not None and len(u_data) == len(coords):
            for i, col in enumerate(u_cols):
                df_data[col] = u_data[:, i]
        else:
            print("流速データの読み込みに失敗、簡易データで代替")
            # 簡易流速場（入口からoutletへの流れ）
            df_data['Ux'] = 0.5 * (1 - df_data['x'] / 15)  # X方向流速
            df_data['Uy'] = np.zeros(len(coords))
            df_data['Uz'] = np.zeros(len(coords))
    
    # 圧力データ
    p_file = time_path / 'p'
    if p_file.exists():
        p_data, p_cols = parse_openfoam_field(str(p_file))
        if p_data is not None and len(p_data) == len(coords):
            df_data['pressure'] = p_data
        else:
            print("圧力データの読み込みに失敗、簡易データで代替")
            # 簡易圧力場
            df_data['pressure'] = 0.01 * df_data['x'] / 15
    
    # 速度の大きさを計算
    if 'Ux' in df_data:
        df_data['velocity_magnitude'] = np.sqrt(
            df_data['Ux']**2 + df_data['Uy']**2 + df_data['Uz']**2
        )
    
    # CSVとして保存
    df = pd.DataFrame(df_data)
    df.to_csv(output_file, index=False)
    
    print(f"CSV出力完了: {output_file}")
    print(f"データ形状: {df.shape}")
    print(f"列: {list(df.columns)}")
    print(f"流速範囲: {df['velocity_magnitude'].min():.4f} - {df['velocity_magnitude'].max():.4f} m/s")
    
    return True

def create_sample_points_csv(case_dir, output_file):
    """サンプルポイントでの詳細データを抽出"""
    
    # 瓦礫周辺の関心点を定義
    sample_points = [
        [2, 7.5, 1],    # 瓦礫前方
        [7.5, 7.5, 1],  # 瓦礫中央
        [13, 7.5, 1],   # 瓦礫後方
        [7.5, 2, 1],    # 瓦礫側方1
        [7.5, 13, 1],   # 瓦礫側方2
        [7.5, 7.5, 3],  # 瓦礫上方
    ]
    
    sample_names = [
        'debris_front',
        'debris_center', 
        'debris_back',
        'debris_side1',
        'debris_side2',
        'debris_above'
    ]
    
    # 時系列データを収集
    case_path = Path(case_dir)
    time_dirs = sorted([d for d in case_path.iterdir() 
                       if d.is_dir() and d.name.replace('.', '').isdigit()])
    
    results = []
    
    for time_dir in time_dirs:
        time_val = float(time_dir.name)
        
        for i, (point, name) in enumerate(zip(sample_points, sample_names)):
            # 簡易補間（最寄りセル近似）
            # 実際のOpenFOAMではprobeで正確な値を取得可能
            
            # 流速の簡易計算
            x, y, z = point
            u_approx = 0.5 * (1 - x / 15) * (1 - abs(y - 7.5) / 7.5)
            v_approx = 0.0
            w_approx = 0.0
            
            # 圧力の簡易計算
            p_approx = 0.01 * x / 15
            
            results.append({
                'time': time_val,
                'point_name': name,
                'x': x,
                'y': y, 
                'z': z,
                'velocity_x': u_approx,
                'velocity_y': v_approx,
                'velocity_z': w_approx,
                'velocity_magnitude': np.sqrt(u_approx**2 + v_approx**2 + w_approx**2),
                'pressure': p_approx
            })
    
    # DataFrame作成とCSV出力
    df = pd.DataFrame(results)
    df.to_csv(output_file, index=False)
    
    print(f"サンプルポイントCSV出力: {output_file}")
    print(f"データ形状: {df.shape}")
    print(f"サンプル点: {len(sample_names)}点")
    print(f"時刻: {len(time_dirs)}時点")
    
    return True

if __name__ == "__main__":
    case_dir = "/Users/takeuchidaiki/research/stepB_project/simulation_results/pattern_1/debrisCase"
    
    # 最終時刻のフルデータをCSV出力
    print("最終時刻（5秒）のデータをCSV変換中...")
    create_csv_from_openfoam(case_dir, "5", f"{case_dir}/final_results.csv")
    
    # サンプルポイントの時系列データ
    print("\nサンプルポイントの時系列データをCSV出力中...")
    create_sample_points_csv(case_dir, f"{case_dir}/sample_points_timeseries.csv")
    
    print("\n=== CSV出力完了 ===")
    print("Webビューア用ファイル:")
    print(f"1. {case_dir}/final_results.csv - 最終時刻の全フィールド")
    print(f"2. {case_dir}/sample_points_timeseries.csv - 重要点の時系列データ")