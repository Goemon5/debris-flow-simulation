#!/usr/bin/env python3
"""
VTKファイルのセルデータ（境界パッチ情報）を確認するスクリプト
"""

try:
    import pyvista as pv
    import numpy as np
    import os
    
    vtk_file = "/Users/takeuchidaiki/research/stepB_project/simulation_results/pattern_1/debrisCase/VTK/workspace_10000.vtk"
    
    print("=== VTKファイルのセルデータ確認 ===")
    print(f"ファイル: {vtk_file}")
    print(f"ファイルサイズ: {os.path.getsize(vtk_file) / 1024 / 1024:.1f} MB")
    
    # VTKファイル読み込み
    mesh = pv.read(vtk_file)
    
    print(f"\n=== メッシュ基本情報 ===")
    print(f"ポイント数: {mesh.n_points:,}")
    print(f"セル数: {mesh.n_cells:,}")
    print(f"メッシュタイプ: {type(mesh)}")
    
    print(f"\n=== Point Data Arrays ===")
    if hasattr(mesh, 'point_data') and len(mesh.point_data) > 0:
        for name, array in mesh.point_data.items():
            print(f"  {name}: {array.shape}, dtype={array.dtype}")
            if len(array) > 0:
                print(f"    範囲: {array.min():.6f} ～ {array.max():.6f}")
    else:
        print("  Point Dataなし")
    
    print(f"\n=== Cell Data Arrays ===")
    if hasattr(mesh, 'cell_data') and len(mesh.cell_data) > 0:
        for name, array in mesh.cell_data.items():
            print(f"  {name}: {array.shape}, dtype={array.dtype}")
            if len(array) > 0:
                if array.dtype in [np.int32, np.int64, np.int8, np.int16]:
                    unique_values = np.unique(array)
                    print(f"    ユニーク値: {unique_values}")
                    print(f"    値の数: {len(unique_values)}")
                else:
                    print(f"    範囲: {array.min():.6f} ～ {array.max():.6f}")
    else:
        print("  ❌ Cell Dataが存在しません")
    
    print(f"\n=== Field Data ===")
    if hasattr(mesh, 'field_data') and len(mesh.field_data) > 0:
        for name, data in mesh.field_data.items():
            print(f"  {name}: {data}")
    else:
        print("  Field Dataなし")
    
    # 境界パッチ情報の確認
    print(f"\n=== 境界パッチ情報の確認 ===")
    boundary_indicators = ['PatchID', 'BoundaryType', 'Region', 'Patch', 'MaterialID', 'ZoneID']
    found_boundary = False
    
    for indicator in boundary_indicators:
        if hasattr(mesh, 'cell_data') and indicator in mesh.cell_data:
            print(f"✅ {indicator} が見つかりました！")
            data = mesh.cell_data[indicator]
            unique_vals = np.unique(data)
            print(f"   値: {unique_vals}")
            found_boundary = True
    
    if not found_boundary:
        print("❌ 境界パッチ情報が見つかりませんでした")
        print("\n💡 対策: OpenFOAMでfoamToVTK実行時に以下を追加:")
        print("   foamToVTK -fields '(U p)' -cellSet")
        print("   または")
        print("   foamToVTK -exclude-patches false")
    
    print(f"\n=== 座標範囲 ===")
    bounds = mesh.bounds
    print(f"X: {bounds[0]:.2f} ～ {bounds[1]:.2f}")
    print(f"Y: {bounds[2]:.2f} ～ {bounds[3]:.2f}")
    print(f"Z: {bounds[4]:.2f} ～ {bounds[5]:.2f}")

except ImportError:
    print("❌ PyVistaがインストールされていません")
    print("インストール: pip install pyvista")
    
    # 代替方法：VTKファイル構造の簡易解析
    print("\n=== VTKファイル構造の簡易確認 ===")
    
    with open(vtk_file, 'rb') as f:
        # ヘッダー読み込み（テキスト部分）
        header = f.read(1000).decode('ascii', errors='ignore')
        print("ヘッダー情報:")
        print(header[:500])
        
        # CELL_DATAセクションがあるか確認
        if 'CELL_DATA' in header:
            print("✅ CELL_DATAセクションが存在します")
        else:
            print("❌ CELL_DATAセクションが見つかりません")

except Exception as e:
    print(f"❌ エラー: {e}")
    print("\n代替方法でVTKファイルの基本情報を確認します...")
    
    # strings コマンドでテキスト部分を抽出
    import subprocess
    try:
        result = subprocess.run(['strings', vtk_file], capture_output=True, text=True, timeout=10)
        strings_output = result.stdout
        
        print("VTKファイル内の文字列:")
        for line in strings_output.split('\n')[:20]:
            if line.strip():
                print(f"  {line}")
                
        if 'CELL_DATA' in strings_output:
            print("✅ CELL_DATAセクションが存在")
        else:
            print("❌ CELL_DATAセクションなし")
            
    except:
        print("文字列抽出も失敗しました")