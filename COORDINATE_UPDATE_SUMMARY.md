# 座標系更新の概要

## 変更内容
計算領域を現実的な正の座標系に変更しました：

### 変更前
- X: [-15, 15] m  
- Y: [-20, 15] m
- Z: [-2, 8] m

### 変更後
- X: [0, 15] m
- Y: [0, 15] m  
- Z: [0, 8] m

## 更新したファイル

### 1. OpenFOAM設定ファイル

#### debrisCase/system/blockMeshDict
- 頂点座標を正の値に変更
- メッシュ分割を (30, 30, 16) に調整

#### debrisCase/system/snappyHexMeshDict
- refinementBox: (2, 2, 0) ～ (13, 13, 5)
- locationInMesh: (1, 1, 4)

#### debrisCase/system/topoSetDict
- 匂い源位置: (7.5, 7.5, 0.5) - 瓦礫中心付近

### 2. 瓦礫生成スクリプト

#### disaster_debris_generator.py
- 瓦礫生成の中心を (7.5, 7.5) に設定
- 全ての瓦礫が計算領域内に配置されるよう調整

## 実行方法
変更後も同じコマンドで実行可能：

```bash
# 一括実行
./run_pattern1_simulation.sh

# または個別実行
python3 generate_debris_pattern1.py
./apply_debris_to_openfoam.sh
./run_openfoam_simulation.sh
```

## 物理的意味
- 地面を Z=0 とした現実的な座標系
- 瓦礫は地面 (Z=0) から上方 (Z=3～9m) から落下
- 計算領域の中央付近に瓦礫が集中配置
- 匂い源は瓦礫内部の地面付近に設定