#!/usr/bin/env python3
"""
全パターン（1-5）のCSVファイルを生成
"""

import os
import sys
from pathlib import Path

# extract_to_csv.pyから関数をインポート
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from extract_to_csv import create_csv_from_openfoam

def generate_pattern_csv(pattern_num):
    """指定パターンのCSVを生成"""
    
    case_dir = f"/Users/takeuchidaiki/research/stepB_project/simulation_results/pattern_{pattern_num}/debrisCase"
    output_file = f"/Users/takeuchidaiki/research/stepB_project/pattern_{pattern_num}_results.csv"
    
    if not os.path.exists(case_dir):
        print(f"❌ パターン{pattern_num}のケースディレクトリが見つかりません")
        return False
    
    # 5秒時刻のデータを確認
    time_dir = "5"
    time_path = Path(case_dir) / time_dir
    
    if not time_path.exists():
        print(f"❌ パターン{pattern_num}: 時刻{time_dir}のデータが見つかりません")
        # 利用可能な時刻を表示
        available_times = [d for d in os.listdir(case_dir) 
                          if os.path.isdir(os.path.join(case_dir, d)) 
                          and d.replace('.', '').replace('-', '').isdigit()]
        available_times.sort(key=float)
        print(f"   利用可能な時刻: {available_times}")
        
        if available_times:
            # 最終時刻を使用
            time_dir = available_times[-1]
            print(f"   最終時刻 {time_dir} を使用します")
        else:
            return False
    
    print(f"=== パターン{pattern_num} CSV生成開始 (時刻={time_dir}) ===")
    
    try:
        success = create_csv_from_openfoam(case_dir, time_dir, output_file)
        
        if success:
            # ファイルサイズ確認
            file_size = os.path.getsize(output_file)
            print(f"✅ パターン{pattern_num}: CSV生成完了 (サイズ: {file_size:,} bytes)")
            return True
        else:
            print(f"❌ パターン{pattern_num}: CSV生成失敗")
            return False
            
    except Exception as e:
        print(f"❌ パターン{pattern_num} エラー: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """全パターンのCSVを生成"""
    
    print("=" * 60)
    print("  全パターンCSV生成プログラム")
    print("=" * 60)
    
    success_count = 0
    failed_patterns = []
    
    for pattern_num in range(1, 6):
        print("")
        if generate_pattern_csv(pattern_num):
            success_count += 1
        else:
            failed_patterns.append(pattern_num)
    
    print("")
    print("=" * 60)
    print(f"  完了: {success_count}/5 パターン")
    
    if failed_patterns:
        print(f"  失敗パターン: {failed_patterns}")
    else:
        print("  🎉 全パターンのCSV生成に成功！")
    
    print("=" * 60)
    
    # CSVファイル一覧
    print("\n生成されたCSVファイル:")
    for i in range(1, 6):
        csv_file = f"pattern_{i}_results.csv"
        if os.path.exists(csv_file):
            size = os.path.getsize(csv_file)
            print(f"  ✓ {csv_file}: {size:,} bytes")
        else:
            print(f"  ✗ {csv_file}: 未生成")
    
    return success_count == 5

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)