#!/usr/bin/env python3
"""
パターン3〜5用の簡略化された瓦礫STLファイル生成スクリプト
発散を防ぐため、シンプルで安定した形状を生成
"""

import numpy as np
import trimesh

def create_simple_debris_pattern3():
    """
    パターン3: L字型配置
    - 流れを妨げない開放的な配置
    - 高さ制限1.8m以下
    """
    meshes = []
    
    # L字の長い方（X方向）
    box1 = trimesh.creation.box(extents=[4.0, 1.5, 1.2])
    box1.apply_translation([2.0, 0.0, 0.6])
    meshes.append(box1)
    
    box2 = trimesh.creation.box(extents=[3.0, 1.2, 1.0])
    box2.apply_translation([5.5, 0.0, 0.5])
    meshes.append(box2)
    
    # L字の短い方（Y方向）
    box3 = trimesh.creation.box(extents=[1.5, 3.0, 1.1])
    box3.apply_translation([0.0, 2.5, 0.55])
    meshes.append(box3)
    
    box4 = trimesh.creation.box(extents=[1.2, 2.0, 0.9])
    box4.apply_translation([0.0, 5.0, 0.45])
    meshes.append(box4)
    
    # 小さな瓦礫
    box5 = trimesh.creation.box(extents=[0.8, 0.8, 0.6])
    box5.apply_translation([3.0, 2.0, 0.3])
    meshes.append(box5)
    
    box6 = trimesh.creation.box(extents=[0.6, 0.7, 0.5])
    box6.apply_translation([1.5, 1.5, 0.25])
    meshes.append(box6)
    
    return trimesh.util.concatenate(meshes)

def create_simple_debris_pattern4():
    """
    パターン4: 円形配置
    - 中心から放射状に配置
    - 流れが周囲を回り込みやすい
    """
    meshes = []
    
    # 中央のブロック
    box1 = trimesh.creation.box(extents=[2.0, 2.0, 1.3])
    box1.apply_translation([2.5, 2.5, 0.65])
    meshes.append(box1)
    
    # 周囲のブロック（4方向）
    # 北側
    box2 = trimesh.creation.box(extents=[1.5, 1.2, 0.9])
    box2.apply_translation([2.5, 5.0, 0.45])
    meshes.append(box2)
    
    # 東側
    box3 = trimesh.creation.box(extents=[1.2, 1.5, 0.8])
    box3.apply_translation([5.0, 2.5, 0.4])
    meshes.append(box3)
    
    # 南側
    box4 = trimesh.creation.box(extents=[1.5, 1.2, 0.7])
    box4.apply_translation([2.5, 0.0, 0.35])
    meshes.append(box4)
    
    # 西側
    box5 = trimesh.creation.box(extents=[1.2, 1.5, 0.8])
    box5.apply_translation([0.0, 2.5, 0.4])
    meshes.append(box5)
    
    # 角の小瓦礫
    box6 = trimesh.creation.box(extents=[0.6, 0.6, 0.5])
    box6.apply_translation([4.5, 4.5, 0.25])
    meshes.append(box6)
    
    box7 = trimesh.creation.box(extents=[0.5, 0.5, 0.4])
    box7.apply_translation([0.5, 4.5, 0.2])
    meshes.append(box7)
    
    return trimesh.util.concatenate(meshes)

def create_simple_debris_pattern5():
    """
    パターン5: 階段状配置
    - 段階的に高くなる配置
    - 流れの剥離を最小限に
    """
    meshes = []
    
    # 1段目（低い）
    box1 = trimesh.creation.box(extents=[3.0, 2.0, 0.6])
    box1.apply_translation([1.5, 1.0, 0.3])
    meshes.append(box1)
    
    box2 = trimesh.creation.box(extents=[2.5, 1.8, 0.6])
    box2.apply_translation([4.5, 1.0, 0.3])
    meshes.append(box2)
    
    # 2段目（中間）
    box3 = trimesh.creation.box(extents=[2.5, 1.8, 1.0])
    box3.apply_translation([2.0, 3.0, 0.5])
    meshes.append(box3)
    
    box4 = trimesh.creation.box(extents=[2.0, 1.5, 1.0])
    box4.apply_translation([5.0, 3.0, 0.5])
    meshes.append(box4)
    
    # 3段目（高い）
    box5 = trimesh.creation.box(extents=[2.0, 1.5, 1.4])
    box5.apply_translation([3.5, 5.0, 0.7])
    meshes.append(box5)
    
    # 小瓦礫
    box6 = trimesh.creation.box(extents=[0.7, 0.7, 0.5])
    box6.apply_translation([0.5, 2.5, 0.25])
    meshes.append(box6)
    
    box7 = trimesh.creation.box(extents=[0.6, 0.6, 0.4])
    box7.apply_translation([6.5, 4.0, 0.2])
    meshes.append(box7)
    
    return trimesh.util.concatenate(meshes)

def save_pattern(mesh, pattern_num):
    """
    パターンをSTLファイルとして保存し、統計を表示
    """
    filename = f'disaster_debris_{pattern_num:02d}.stl'
    
    print(f"\n=== パターン{pattern_num} ===")
    print(f"  頂点数: {len(mesh.vertices)}")
    print(f"  面数: {len(mesh.faces)}")
    print(f"  体積: {mesh.volume:.3f} m³")
    print(f"  表面積: {mesh.area:.3f} m²")
    bounds = mesh.bounds
    print(f"  境界: {bounds[0]} to {bounds[1]}")
    print(f"  サイズ: X={bounds[1][0]-bounds[0][0]:.1f}m, Y={bounds[1][1]-bounds[0][1]:.1f}m, Z={bounds[1][2]-bounds[0][2]:.1f}m")
    
    if mesh.is_watertight:
        print("  ✓ ワータータイト")
    else:
        print("  ⚠ 非ワータータイト")
    
    mesh.export(filename)
    print(f"  → {filename} 保存完了")
    
    return filename

def main():
    print("パターン3〜5の簡略化された瓦礫STLファイルを生成中...")
    
    # 既存ファイルのバックアップ
    import os
    for i in range(3, 6):
        original = f'disaster_debris_{i:02d}.stl'
        if os.path.exists(original):
            backup = f'disaster_debris_{i:02d}_original.stl'
            if not os.path.exists(backup):
                os.rename(original, backup)
                print(f"バックアップ: {original} → {backup}")
    
    # 各パターンの生成
    pattern3 = create_simple_debris_pattern3()
    save_pattern(pattern3, 3)
    
    pattern4 = create_simple_debris_pattern4()
    save_pattern(pattern4, 4)
    
    pattern5 = create_simple_debris_pattern5()
    save_pattern(pattern5, 5)
    
    print("\n✅ パターン3〜5の生成完了")

if __name__ == "__main__":
    main()