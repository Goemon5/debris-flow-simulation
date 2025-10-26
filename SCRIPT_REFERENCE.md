# スクリプト・設定ファイル完全リファレンス

## 実行済みスクリプト一覧

### 1. メイン実行スクリプト
**ファイル:** `run_10patterns_full_60steps.sh`  
**用途:** 10パターン全タイムステップシミュレーション実行  
**実行コマンド:** `./run_10patterns_full_60steps.sh`

**主要機能:**
- スリープ防止 (caffeinate 8時間)
- パターン01-10順次実行
- controlDict自動調整 (endTime=60, writeInterval=1)
- エラーハンドリング・ログ出力
- 実行時間計測・進捗表示

**重要な修正点:**
```bash
# setup_flow_simulation.sh後にcontrolDict変更
if timeout 60 ./setup_flow_simulation.sh >> "../$log_file" 2>&1; then
    echo "✓ フロー設定完了"
    
    # ここでcontrolDictを全タイムステップ保存に変更
    sed -i '' 's/endTime.*/endTime         60;/' system/controlDict
    sed -i '' 's/writeInterval.*/writeInterval   1;/' system/controlDict
    echo "✓ controlDict設定完了 (endTime=60, writeInterval=1)"
```

### 2. 流体設定スクリプト
**ファイル:** `setup_flow_simulation.sh`  
**用途:** simpleFoam用設定ファイル生成  
**実行:** メインスクリプトから自動実行

**生成ファイル:**
- `system/controlDict` (初期設定: endTime=100, writeInterval=50)
- `system/fvSchemes` (離散化スキーム)
- `system/fvSolution` (ソルバー設定)
- `constant/physicalProperties` (流体物性)
- `constant/momentumTransport` (乱流モデル)
- `0/U`, `0/p` (境界条件)

### 3. OpenFOAM実行スクリプト
**ファイル:** `run_openfoam.sh`  
**用途:** Docker経由でOpenFOAMコマンド実行  
**実行例:**
```bash
./run_openfoam.sh blockMesh
./run_openfoam.sh snappyHexMesh -overwrite
./run_openfoam.sh simpleFoam
```

### 4. STL解析・変換スクリプト
**ファイル:** `stl_tools/stl_analyzer.py`  
**用途:** STLファイルのドメイン内変換  
**実行例:**
```bash
python stl_tools/stl_analyzer.py debris_pattern_01.stl --output debris_pattern_01_transformed.stl
```

## 設定ファイル詳細

### controlDict (最終設定)
```cpp
application     simpleFoam;
startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         60;           // 60回反復
deltaT          1;
writeControl    timeStep;
writeInterval   1;            // 全ステップ保存
purgeWrite      0;
writeFormat     ascii;
```

### 境界条件ファイル (0/U)
```cpp
boundaryField
{
    inlet    { type fixedValue; value uniform (2 0 0); }  // 2m/s入口
    outlet   { type zeroGradient; }
    ground   { type noSlip; }
    atmosphere { type zeroGradient; }                     // 修正済み
    sides    { type zeroGradient; }                       // 修正済み
    debris   { type noSlip; }
}
```

### 境界条件ファイル (0/p)
```cpp
boundaryField
{
    inlet    { type zeroGradient; }
    outlet   { type fixedValue; value uniform 0; }       // 0Pa出口
    ground   { type zeroGradient; }
    atmosphere { type zeroGradient; }                     // 修正済み
    sides    { type zeroGradient; }                       // 修正済み
    debris   { type zeroGradient; }
}
```

## ディレクトリ構造

### 作業ディレクトリ
```
/Users/takeuchidaiki/research/stepB_project/
├── debris_pattern_01.stl ~ debris_pattern_10.stl    # 元STLファイル
├── pattern_01_test/ ~ pattern_10_test/               # 各パターン作業フォルダ
├── pattern_01_complete_test/                         # 正常動作テンプレート
├── simulation_results_10patterns_full_60steps/      # 結果フォルダ
├── logs_10patterns_full/                            # 実行ログ
├── stl_tools/stl_analyzer.py                        # STL変換ツール
├── run_10patterns_full_60steps.sh                   # メイン実行スクリプト
├── setup_flow_simulation.sh                         # 流体設定スクリプト
└── run_openfoam.sh                                  # OpenFOAM実行スクリプト
```

### 結果ディレクトリ構造
```
simulation_results_10patterns_full_60steps/
├── pattern_01_full/
│   ├── 0/, 1/, 2/, ..., 60/     # 各反復ステップ結果
│   ├── constant/polyMesh/       # メッシュデータ
│   └── system/                  # 設定ファイル
├── pattern_02_full/
│   └── (同上)
...
└── pattern_09_full/
    └── (同上)
```

## Pattern 10 手動実行手順

### 前提確認
```bash
cd /Users/takeuchidaiki/research/stepB_project/pattern_10_test
ls -la  # ファイル存在確認
```

### Step 1: メッシュ生成
```bash
./run_openfoam.sh blockMesh
# 実行時間: 約30秒
# 成功確認: "End"メッセージ
```

### Step 2: 表面メッシュ生成
```bash
./run_openfoam.sh snappyHexMesh -overwrite
# 実行時間: 約1-2分
# 成功確認: constant/polyMesh/pointsファイル生成
```

### Step 3: 流体設定
```bash
./setup_flow_simulation.sh
# 実行時間: 数秒
# 成功確認: 設定ファイル群生成
```

### Step 4: controlDict調整
```bash
sed -i '' 's/endTime.*/endTime         60;/' system/controlDict
sed -i '' 's/writeInterval.*/writeInterval   1;/' system/controlDict
```

### Step 5: 流体計算実行
```bash
./run_openfoam.sh simpleFoam
# 実行時間: 約2-3分
# 成功確認: タイムステップ0-60まで62個のディレクトリ生成
```

### Step 6: 結果コピー
```bash
mkdir -p ../simulation_results_10patterns_full_60steps/pattern_10_full
cp -r . ../simulation_results_10patterns_full_60steps/pattern_10_full/
```

### Step 7: 完了確認
```bash
cd ../simulation_results_10patterns_full_60steps/pattern_10_full
find . -maxdepth 1 -type d -name "[0-9]*" | wc -l
# 期待値: 62 (t=0からt=60まで + 初期状態)
```

## トラブルシューティング

### よくあるエラーと対処法

1. **"No such file or directory" (STLファイル)**
   - 原因: STLファイルパスが正しくない
   - 対処: `debris_pattern_01.stl`形式で確認

2. **"symmetryPlane vs patch" エラー**
   - 原因: 境界条件タイプ不一致
   - 対処: pattern_01_complete_testから境界条件をコピー

3. **Docker platform警告**
   - 原因: ARM64 Mac上でAMD64イメージ実行
   - 対処: 無視 (動作に影響なし)

4. **mesh generation失敗**
   - 原因: STLファイルの品質問題
   - 対処: `checkMesh`でメッシュ品質確認

5. **計算が収束しない**
   - 原因: 境界条件設定ミス
   - 対処: residualログで確認、設定見直し

## 成功時の出力例

### タイムステップ確認
```bash
# Pattern 01の例
0 1 2 3 4 5 6 7 8 9 10 ... 58 59 60
Total: 62 timesteps
```

### ファイルサイズ確認
```bash
Pattern 01: 466M
Pattern 02: 614M
...
Average: 500MB per pattern
```

### 実行ログ例
```
Pattern 01完了: 2025年 10月16日 00:20:45
  保存されたタイムステップ数: 62
  ✓ 結果コピー完了
```

---
**最終更新:** 2025-10-16  
**動作確認済み環境:** macOS 14.6, Docker Desktop  
**OpenFOAM版本:** v10 (Docker: openfoam/openfoam10-paraview56)