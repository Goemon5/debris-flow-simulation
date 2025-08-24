#!/usr/bin/env python3
"""
STLファイルビューア
生成したSTLファイルを3D表示して確認するためのスクリプト
"""

import trimesh
import numpy as np
import sys
import os
from pathlib import Path

def view_stl(filename: str, show_info: bool = True):
    """
    STLファイルを表示
    
    Args:
        filename: STLファイルのパス
        show_info: メッシュ情報を表示するか
    """
    if not os.path.exists(filename):
        print(f"エラー: ファイル '{filename}' が見つかりません")
        return
    
    # STLファイルを読み込み
    mesh = trimesh.load(filename)
    
    if show_info:
        print(f"\n=== {filename} の情報 ===")
        print(f"頂点数: {len(mesh.vertices)}")
        print(f"面数: {len(mesh.faces)}")
        print(f"バウンディングボックス:")
        print(f"  最小: {mesh.bounds[0]}")
        print(f"  最大: {mesh.bounds[1]}")
        print(f"体積: {mesh.volume:.3f} m³")
        print(f"表面積: {mesh.area:.3f} m²")
        print(f"重心: {mesh.center_mass}")
        print(f"水密性: {'はい' if mesh.is_watertight else 'いいえ'}")
    
    # 3D表示
    mesh.show()

def view_multiple_stls(pattern: str = "debris_*.stl"):
    """
    複数のSTLファイルを一つのシーンで表示
    
    Args:
        pattern: ファイルパターン
    """
    from glob import glob
    
    files = sorted(glob(pattern))
    if not files:
        print(f"パターン '{pattern}' に一致するファイルが見つかりません")
        return
    
    print(f"\n{len(files)} 個のSTLファイルを読み込み中...")
    
    # シーンを作成
    scene = trimesh.Scene()
    
    # 各ファイルを異なる位置に配置
    for i, filename in enumerate(files):
        mesh = trimesh.load(filename)
        
        # グリッド配置（3x4など）
        cols = 4
        row = i // cols
        col = i % cols
        
        # メッシュを移動
        translation = [col * 3, row * 3, 0]
        mesh.apply_translation(translation)
        
        # 色を設定（ランダムまたは固定）
        mesh.visual.vertex_colors = trimesh.visual.random_color()
        
        # シーンに追加
        scene.add_geometry(mesh, node_name=f"debris_{i+1:02d}")
        
        print(f"  {filename} を位置 ({col}, {row}) に配置")
    
    # シーンを表示
    print("\n表示中... (ウィンドウを閉じると終了)")
    scene.show()

def compare_stls(file1: str, file2: str):
    """
    2つのSTLファイルを比較表示
    
    Args:
        file1: 1つ目のSTLファイル
        file2: 2つ目のSTLファイル
    """
    mesh1 = trimesh.load(file1)
    mesh2 = trimesh.load(file2)
    
    # 色を設定
    mesh1.visual.vertex_colors = [255, 0, 0, 128]  # 赤
    mesh2.visual.vertex_colors = [0, 0, 255, 128]  # 青
    
    # 2つ目を横に配置
    bounds1 = mesh1.bounds
    offset = bounds1[1][0] - bounds1[0][0] + 1.0
    mesh2.apply_translation([offset, 0, 0])
    
    # シーンに追加
    scene = trimesh.Scene()
    scene.add_geometry(mesh1, node_name=os.path.basename(file1))
    scene.add_geometry(mesh2, node_name=os.path.basename(file2))
    
    print(f"\n比較表示:")
    print(f"  赤: {file1}")
    print(f"  青: {file2}")
    
    scene.show()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="STLファイルビューア")
    parser.add_argument("filename", nargs="?", default="debris_01.stl",
                       help="表示するSTLファイル (デフォルト: debris_01.stl)")
    parser.add_argument("--all", action="store_true",
                       help="すべてのdebris_*.stlファイルを表示")
    parser.add_argument("--compare", nargs=2, metavar=("FILE1", "FILE2"),
                       help="2つのSTLファイルを比較表示")
    parser.add_argument("--no-info", action="store_true",
                       help="メッシュ情報を表示しない")
    
    args = parser.parse_args()
    
    if args.all:
        view_multiple_stls()
    elif args.compare:
        compare_stls(args.compare[0], args.compare[1])
    else:
        view_stl(args.filename, show_info=not args.no_info)