#!/usr/bin/env python3
"""
3ブロック配置の5パターン生成
各パターンで異なる配置・サイズ・角度を持つ3つのブロック
"""

import numpy as np
import trimesh

def create_three_blocks_pattern(pattern_num):
    """
    3ブロックの異なる配置パターンを生成
    """
    meshes = []
    
    if pattern_num == 1:
        # パターン1: 直線配置（流れに沿って）
        print("  配置: 直線配置（X軸に沿って）")
        # ブロック1（上流）
        box1 = trimesh.creation.box(extents=[1.5, 2.0, 2.5])
        box1.apply_translation([4.0, 7.5, 1.25])
        meshes.append(box1)
        
        # ブロック2（中央）
        box2 = trimesh.creation.box(extents=[1.5, 2.0, 2.0])
        box2.apply_translation([7.5, 7.5, 1.0])
        meshes.append(box2)
        
        # ブロック3（下流）
        box3 = trimesh.creation.box(extents=[1.5, 2.0, 2.5])
        box3.apply_translation([11.0, 7.5, 1.25])
        meshes.append(box3)
        
    elif pattern_num == 2:
        # パターン2: 三角配置（流れを分岐）
        print("  配置: 三角配置（流れを分岐）")
        # ブロック1（前方中央）
        box1 = trimesh.creation.box(extents=[2.0, 2.0, 2.0])
        box1.apply_translation([5.0, 7.5, 1.0])
        meshes.append(box1)
        
        # ブロック2（後方左）
        box2 = trimesh.creation.box(extents=[1.8, 1.8, 2.2])
        box2.apply_translation([9.0, 5.5, 1.1])
        meshes.append(box2)
        
        # ブロック3（後方右）
        box3 = trimesh.creation.box(extents=[1.8, 1.8, 2.2])
        box3.apply_translation([9.0, 9.5, 1.1])
        meshes.append(box3)
        
    elif pattern_num == 3:
        # パターン3: ジグザグ配置（蛇行流を作る）
        print("  配置: ジグザグ配置（蛇行流）")
        # ブロック1（左前）
        box1 = trimesh.creation.box(extents=[1.5, 2.5, 2.0])
        box1.apply_translation([4.5, 5.0, 1.0])
        meshes.append(box1)
        
        # ブロック2（右中）
        box2 = trimesh.creation.box(extents=[1.5, 2.5, 2.0])
        box2.apply_translation([7.5, 10.0, 1.0])
        meshes.append(box2)
        
        # ブロック3（左後）
        box3 = trimesh.creation.box(extents=[1.5, 2.5, 2.0])
        box3.apply_translation([10.5, 5.0, 1.0])
        meshes.append(box3)
        
    elif pattern_num == 4:
        # パターン4: 階段状配置（高さ変化）
        print("  配置: 階段状配置（高さ変化）")
        # ブロック1（低い）
        box1 = trimesh.creation.box(extents=[2.0, 2.0, 1.0])
        box1.apply_translation([4.5, 7.5, 0.5])
        meshes.append(box1)
        
        # ブロック2（中間）
        box2 = trimesh.creation.box(extents=[2.0, 2.0, 2.0])
        box2.apply_translation([7.5, 7.5, 1.0])
        meshes.append(box2)
        
        # ブロック3（高い）
        box3 = trimesh.creation.box(extents=[2.0, 2.0, 3.0])
        box3.apply_translation([10.5, 7.5, 1.5])
        meshes.append(box3)
        
    elif pattern_num == 5:
        # パターン5: 回転配置（異なる角度）
        print("  配置: 回転配置（異なる角度）")
        # ブロック1（45度回転）
        box1 = trimesh.creation.box(extents=[2.0, 1.5, 2.0])
        rotation_matrix1 = trimesh.transformations.rotation_matrix(
            np.radians(45), [0, 0, 1], [5.0, 7.5, 0]
        )
        box1.apply_transform(rotation_matrix1)
        box1.apply_translation([5.0, 7.5, 1.0])
        meshes.append(box1)
        
        # ブロック2（回転なし）
        box2 = trimesh.creation.box(extents=[1.8, 2.2, 2.0])
        box2.apply_translation([7.5, 7.5, 1.0])
        meshes.append(box2)
        
        # ブロック3（-30度回転）
        box3 = trimesh.creation.box(extents=[2.0, 1.5, 2.0])
        rotation_matrix3 = trimesh.transformations.rotation_matrix(
            np.radians(-30), [0, 0, 1], [10.0, 7.5, 0]
        )
        box3.apply_transform(rotation_matrix3)
        box3.apply_translation([10.0, 7.5, 1.0])
        meshes.append(box3)
    
    return meshes

def generate_three_blocks_files():
    """
    5つの3ブロックパターンを生成
    """
    patterns = [
        "直線配置（流れに沿って）",
        "三角配置（流れを分岐）",
        "ジグザグ配置（蛇行流）",
        "階段状配置（高さ変化）",
        "回転配置（異なる角度）"
    ]
    
    print("=" * 60)
    print("3ブロック配置パターン生成")
    print("各パターン3個のブロック、異なる配置")
    print("=" * 60)
    
    for i in range(1, 6):
        print(f"\nパターン{i}: {patterns[i-1]}")
        
        # メッシュ生成
        meshes = create_three_blocks_pattern(i)
        
        # 結合
        combined_mesh = trimesh.util.concatenate(meshes)
        
        # STLファイル出力
        filename = f"three_blocks_{i:02d}.stl"
        combined_mesh.export(filename)
        
        # 情報表示
        print(f"  ファイル: {filename}")
        print(f"  ブロック数: 3個")
        print(f"  頂点数: {len(combined_mesh.vertices)}")
        print(f"  面数: {len(combined_mesh.faces)}")
        print(f"  総体積: {combined_mesh.volume:.2f} m³")
        
        # バウンディングボックス
        bounds = combined_mesh.bounds
        print(f"  範囲: X[{bounds[0][0]:.1f}-{bounds[1][0]:.1f}], "
              f"Y[{bounds[0][1]:.1f}-{bounds[1][1]:.1f}], "
              f"Z[{bounds[0][2]:.1f}-{bounds[1][2]:.1f}]")

if __name__ == "__main__":
    generate_three_blocks_files()
    
    print("\n" + "=" * 60)
    print("✅ 3ブロックパターン生成完了！")
    print("\n各パターンの特徴:")
    print("1. 直線配置 - 最も単純、流れが予測しやすい")
    print("2. 三角配置 - 流れが分岐、圧力差が生じる")
    print("3. ジグザグ - 蛇行流、複雑だが安定")
    print("4. 階段状 - 高さ変化による3D効果")
    print("5. 回転配置 - 角度による流れの変化")
    print("\n推奨: パターン1から順に試すことで安定性確認")
    print("=" * 60)