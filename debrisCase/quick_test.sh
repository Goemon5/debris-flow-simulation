#!/bin/bash
# 高速テスト用設定

echo "高速テスト設定..."

# 高速版のcontrolDictを使用
cp system/controlDict.fast system/controlDict

echo "設定内容:"
echo "• 終了時刻: 1005 (5ステップのみ)"
echo "• 時間刻み: 0.1 (10倍大きく)"
echo "• 予想実行時間: 5-15分"
echo ""
echo "実行コマンド: foamRun -solver incompressibleFluid"