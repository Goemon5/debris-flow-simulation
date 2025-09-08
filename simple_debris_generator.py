#!/usr/bin/env python3
"""
シンプルな瓦礫環境生成スクリプト
流体シミュレーション用に最適化
"""

import numpy as np
import trimesh

def create_simple_debris_scenario(scenario_type="single_block"):
    """
    シンプルな瓦礫シナリオを生成
    """
    meshes = []
    
    if scenario_type == "single_block":
        # シナリオ1: 単一ブロック（最もシンプル）
        box = trimesh.creation.box(extents=[2.0, 2.0, 2.0])
        box.apply_translation([7.5, 7.5, 1.0])
        meshes.append(box)
        
    elif scenario_type == "two_blocks":
        # シナリオ2: 2つのブロック（前後配置）
        box1 = trimesh.creation.box(extents=[1.5, 2.0, 2.0])
        box1.apply_translation([5.0, 7.5, 1.0])
        meshes.append(box1)
        
        box2 = trimesh.creation.box(extents=[1.5, 2.0, 2.0])
        box2.apply_translation([10.0, 7.5, 1.0])
        meshes.append(box2)
        
    elif scenario_type == "three_blocks":
        # シナリオ3: 3つのブロック（三角配置）
        box1 = trimesh.creation.box(extents=[1.5, 1.5, 2.0])
        box1.apply_translation([7.5, 7.5, 1.0])
        meshes.append(box1)
        
        box2 = trimesh.creation.box(extents=[1.5, 1.5, 1.5])
        box2.apply_translation([5.0, 5.0, 0.75])
        meshes.append(box2)
        
        box3 = trimesh.creation.box(extents=[1.5, 1.5, 1.5])
        box3.apply_translation([10.0, 10.0, 0.75])
        meshes.append(box3)
        
    elif scenario_type == "wall":
        # シナリオ4: 壁状障害物
        wall = trimesh.creation.box(extents=[0.5, 5.0, 3.0])
        wall.apply_translation([7.5, 7.5, 1.5])
        meshes.append(wall)
        
    elif scenario_type == "cylinder":
        # シナリオ5: 円柱障害物（最も流体的）
        cylinder = trimesh.creation.cylinder(radius=1.5, height=3.0, sections=16)
        cylinder.apply_translation([7.5, 7.5, 1.5])
        meshes.append(cylinder)
    
    return meshes

def generate_simple_debris_files():
    """
    5つのシンプルな瓦礫パターンを生成
    """
    scenarios = [
        ("single_block", "単一ブロック"),
        ("two_blocks", "2ブロック配置"),
        ("three_blocks", "3ブロック配置"),
        ("wall", "壁状障害物"),
        ("cylinder", "円柱障害物")
    ]
    
    for i, (scenario_type, description) in enumerate(scenarios, 1):
        print(f"\nパターン{i}: {description}")
        
        # メッシュ生成
        meshes = create_simple_debris_scenario(scenario_type)
        
        # 結合
        if len(meshes) > 1:
            combined_mesh = trimesh.util.concatenate(meshes)
        else:
            combined_mesh = meshes[0]
        
        # STLファイル出力
        filename = f"simple_debris_{i:02d}.stl"
        combined_mesh.export(filename)
        
        # 情報表示
        print(f"  ファイル: {filename}")
        print(f"  頂点数: {len(combined_mesh.vertices)}")
        print(f"  面数: {len(combined_mesh.faces)}")
        print(f"  体積: {combined_mesh.volume:.2f} m³")
        print(f"  バウンディングボックス: {combined_mesh.bounds}")

if __name__ == "__main__":
    print("=" * 60)
    print("シンプルな瓦礫環境生成")
    print("流体シミュレーション最適化版")
    print("=" * 60)
    
    generate_simple_debris_files()
    
    print("\n" + "=" * 60)
    print("✅ 生成完了！")
    print("\n推奨される使用順序:")
    print("1. simple_debris_01.stl - 最も安定（単一ブロック）")
    print("2. simple_debris_05.stl - 流体的に優しい（円柱）")
    print("3. simple_debris_02.stl - 適度な複雑さ（2ブロック）")
    print("4. simple_debris_03.stl - やや複雑（3ブロック）")
    print("5. simple_debris_04.stl - 壁効果の検証")
    print("=" * 60)