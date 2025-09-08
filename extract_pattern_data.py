#!/usr/bin/env python3
"""
指定パターンのOpenFOAMデータを抽出
"""

import sys
import os
from pathlib import Path

# 既存のスクリプトから関数をインポート
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def extract_pattern_data(pattern_num):
    """指定パターンのデータを抽出"""
    
    case_dir = f"/Users/takeuchidaiki/research/stepB_project/simulation_results/pattern_{pattern_num}/debrisCase"
    
    if not os.path.exists(case_dir):
        print(f"❌ パターン{pattern_num}のケースディレクトリが見つかりません: {case_dir}")
        return False
    
    print(f"=== パターン{pattern_num}のデータ抽出開始 ===")
    
    try:
        # extract_real_data.py の処理を実行
        from extract_real_data import create_real_csv
        success1 = create_real_csv(case_dir, "5", f"{case_dir}/real_openfoam_results.csv")
        
        if success1:
            print(f"✅ パターン{pattern_num}: 実データ抽出完了")
        
        # extract_boundary_patches.py の処理を実行  
        from extract_boundary_patches import create_boundary_csv
        success2 = create_boundary_csv(case_dir)
        
        if success2:
            print(f"✅ パターン{pattern_num}: 境界データ抽出完了")
        
        return success1 and success2
        
    except Exception as e:
        print(f"❌ パターン{pattern_num} データ抽出エラー: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("使用方法: python extract_pattern_data.py <pattern_number>")
        print("例: python extract_pattern_data.py 2")
        sys.exit(1)
    
    pattern_num = int(sys.argv[1])
    success = extract_pattern_data(pattern_num)
    
    if success:
        print(f"🎉 パターン{pattern_num}のデータ抽出完了")
    else:
        print(f"❌ パターン{pattern_num}のデータ抽出失敗")
        sys.exit(1)