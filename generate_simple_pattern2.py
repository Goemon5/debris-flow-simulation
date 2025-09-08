#!/usr/bin/env python3
"""
パターン2用の簡略化された瓦礫STLファイル生成スクリプト
発散を防ぐため、よりシンプルで安定した形状を生成
"""

import numpy as np
import trimesh

def create_simple_debris_pattern2():
    """
    パターン2: コンパクトで流れに優しい配置
    - 全体的に低い配置（高さ2m以下）
    - Y方向の広がりを抑える
    - ブロック間に適切な間隔を確保
    """
    meshes = []
    
    # 大きな基礎ブロック（地面に近い安定した配置）
    # ブロック1: 中央の大きな瓦礫
    box1 = trimesh.creation.box(extents=[3.0, 2.0, 1.5])
    box1.apply_translation([2.0, 2.0, 0.75])
    meshes.append(box1)
    
    # ブロック2: 左側の瓦礫
    box2 = trimesh.creation.box(extents=[2.5, 2.5, 1.2])
    box2.apply_translation([-1.5, 1.5, 0.6])
    meshes.append(box2)
    
    # ブロック3: 右側の低い瓦礫
    box3 = trimesh.creation.box(extents=[2.0, 1.8, 0.8])
    box3.apply_translation([5.5, 1.0, 0.4])
    meshes.append(box3)
    
    # 中サイズのブロック（適度な間隔で配置）
    # ブロック4: 前方の瓦礫
    box4 = trimesh.creation.box(extents=[1.8, 1.5, 1.0])
    box4.apply_translation([1.0, -1.0, 0.5])
    meshes.append(box4)
    
    # ブロック5: 後方の瓦礫
    box5 = trimesh.creation.box(extents=[1.5, 1.8, 0.9])
    box5.apply_translation([3.0, 4.5, 0.45])
    meshes.append(box5)
    
    # 小さいブロック（流れの緩衝材として）
    # ブロック6: 小瓦礫1
    box6 = trimesh.creation.box(extents=[0.8, 0.8, 0.6])
    box6.apply_translation([-0.5, -0.5, 0.3])
    meshes.append(box6)
    
    # ブロック7: 小瓦礫2
    box7 = trimesh.creation.box(extents=[0.7, 0.9, 0.5])
    box7.apply_translation([4.5, 3.0, 0.25])
    meshes.append(box7)
    
    # ブロック8: 小瓦礫3（流れを整える）
    box8 = trimesh.creation.box(extents=[0.6, 0.7, 0.4])
    box8.apply_translation([0.5, 3.5, 0.2])
    meshes.append(box8)
    
    # すべてのメッシュを結合
    combined_mesh = trimesh.util.concatenate(meshes)
    
    # メッシュの品質確認
    print("生成されたメッシュの統計:")
    print(f"  頂点数: {len(combined_mesh.vertices)}")
    print(f"  面数: {len(combined_mesh.faces)}")
    print(f"  体積: {combined_mesh.volume:.3f} m³")
    print(f"  表面積: {combined_mesh.area:.3f} m²")
    bounds = combined_mesh.bounds
    print(f"  境界ボックス: {bounds[0]} to {bounds[1]}")
    print(f"  サイズ: X={bounds[1][0]-bounds[0][0]:.1f}m, Y={bounds[1][1]-bounds[0][1]:.1f}m, Z={bounds[1][2]-bounds[0][2]:.1f}m")
    print(f"  重心: {combined_mesh.center_mass}")
    
    # ワータータイト性確認
    if combined_mesh.is_watertight:
        print("✓ メッシュはワータータイトです（閉じた形状）")
    else:
        print("⚠ メッシュはワータータイトではありません")
    
    return combined_mesh

def main():
    print("パターン2の簡略化された瓦礫STLファイルを生成中...")
    
    # メッシュ生成
    mesh = create_simple_debris_pattern2()
    
    # STLファイルとして保存
    output_filename = 'disaster_debris_02.stl'
    mesh.export(output_filename)
    print(f"\n✓ {output_filename} を生成しました")
    
    # パターン1との比較
    try:
        mesh1 = trimesh.load_mesh('disaster_debris_01.stl')
        print(f"\nパターン1との比較:")
        print(f"  体積比: {mesh.volume/mesh1.volume:.2f}倍")
        print(f"  表面積比: {mesh.area/mesh1.area:.2f}倍")
        print(f"  最大高さ: パターン2={mesh.bounds[1][2]:.2f}m, パターン1={mesh1.bounds[1][2]:.2f}m")
    except:
        pass

if __name__ == "__main__":
    main()