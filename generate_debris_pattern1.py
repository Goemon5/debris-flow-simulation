#!/usr/bin/env python3
"""
瓦礫パターン1生成スクリプト
災害現場を想定した基本的な瓦礫配置パターンを生成
"""

import subprocess
import sys
import os

def generate_pattern1():
    """パターン1の瓦礫を生成"""
    print("=" * 60)
    print("瓦礫パターン1を生成中...")
    print("=" * 60)
    
    # 既存のdisaster_debris_generator.pyを使用してパターン1を生成
    # OUTPUT_FILENAMEは既にdisaster_debris_01.stlに設定されている
    try:
        result = subprocess.run([sys.executable, 'disaster_debris_generator.py'], 
                              capture_output=True, text=True, check=True)
        print(result.stdout)
        if result.stderr:
            print("警告:", result.stderr)
        
        # 生成されたファイルを確認
        if os.path.exists('disaster_debris_01.stl'):
            file_size = os.path.getsize('disaster_debris_01.stl') / 1024
            print(f"\n✓ 瓦礫パターン1生成完了: disaster_debris_01.stl ({file_size:.1f} KB)")
            return True
        else:
            print("✗ エラー: STLファイルが生成されませんでした")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"✗ エラー: 瓦礫生成に失敗しました")
        print(f"エラー出力: {e.stderr}")
        return False
    except Exception as e:
        print(f"✗ 予期しないエラー: {e}")
        return False

if __name__ == "__main__":
    success = generate_pattern1()
    sys.exit(0 if success else 1)