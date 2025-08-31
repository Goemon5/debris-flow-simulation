# 災害瓦礫環境流体シミュレーションプロジェクト

## 概要
本プロジェクトは、災害現場における瓦礫環境での流体挙動と匂い物質拡散をシミュレーションするシステムです。PyBulletによる物理シミュレーションで現実的な瓦礫配置を生成し、OpenFOAMで流体解析を行います。

### 主な特徴
- **物理的に現実的な瓦礫生成**: PyBulletで建物崩壊をシミュレーション
- **高精度流体解析**: OpenFOAM v11による非圧縮性流体シミュレーション
- **Web可視化**: ブラウザベースの3D可視化ツール
- **複数パターン対応**: 異なる瓦礫配置での比較解析

## システム要件

### 必須ソフトウェア
- Python 3.8以上
- Docker Desktop
- 8GB以上のRAM推奨
- 50GB以上の空きディスク容量

### Pythonライブラリ
```bash
pip install pybullet numpy trimesh
```

### Dockerイメージ
```bash
docker pull openfoam/openfoam11-paraview510:latest
```

## ディレクトリ構造

```
stepB_project/
├── disaster_debris_generator.py    # 瓦礫生成スクリプト
├── visualize_results.py           # 結果可視化スクリプト
├── openfoam_web_viewer.html       # Web3Dビューア
│
├── run_multi_simulations.sh       # 5パターン個別実行スクリプト
├── run_complete_simulation.sh     # 統合実行スクリプト（単一）
│
├── debrisCase/                    # OpenFOAMケースディレクトリ
│   ├── 0/                        # 初期条件
│   │   ├── U                     # 流速場
│   │   └── p                     # 圧力場
│   ├── constant/                 # 定常設定
│   │   ├── polyMesh/            # メッシュデータ
│   │   └── triSurface/          # STL瓦礫形状
│   └── system/                   # シミュレーション設定
│       ├── controlDict          # 実行制御（時間、出力）
│       ├── blockMeshDict        # 基本メッシュ定義
│       ├── snappyHexMeshDict    # メッシュ細分化設定
│       ├── fvSolution           # 数値解法設定
│       ├── fvSchemes            # 離散化スキーム
│       ├── setFieldsDict        # 初期場設定
│       └── topoSetDict          # トポロジー設定
│
├── simulation_results/            # 実行結果保存先
│   ├── pattern_1/                # パターン1の結果
│   ├── pattern_2/                # パターン2の結果
│   ├── ...                      
│   ├── simulation_summary.txt    # 実行サマリー
│   └── comparison_viewer.html    # 結果比較ビューア
│
└── disaster_debris_*.stl         # 生成された瓦礫STLファイル

```

## クイックスタート

### 1. 基本的な実行（5パターン個別シミュレーション）
```bash
# 5つの異なる瓦礫パターンを個別にシミュレーション
./run_multi_simulations.sh
```
- 実行時間: 約70-100分
- 各パターンを順次実行
- 結果は`simulation_results/pattern_[1-5]/`に保存

### 2. 単一パターンの実行
```bash
# 1つの瓦礫パターンのみ実行
./run_complete_simulation.sh
```
- 実行時間: 約15-25分
- 5つのSTLを結合して1つのシミュレーション

## 主要コンポーネント

### 1. 瓦礫生成 (disaster_debris_generator.py)

災害現場の瓦礫環境を物理シミュレーションで生成します。

#### 主要パラメータ
```python
# 構造材の数
NUM_WALL_FRAGMENTS = 8    # 壁片（大型コンクリート片）
NUM_BEAMS = 6            # 梁（鉄骨やコンクリート梁）
NUM_COLUMNS = 4          # 柱（支柱）
NUM_FLOOR_SLABS = 3      # 床スラブ（大型の平板）
NUM_SMALL_DEBRIS = 15    # 小瓦礫（家具、設備の破片など）

# 崩壊エリア設定
COLLAPSE_AREA_SIZE = (8.0, 8.0)  # XY平面での崩壊範囲（メートル）
SPAWN_HEIGHT_MIN = 3.0            # 最小落下高さ（1階分）
SPAWN_HEIGHT_MAX = 9.0            # 最大落下高さ（3階分）

# 物理シミュレーション
SIMULATION_STEPS = 5000           # シミュレーションステップ数
TIME_STEP = 1/240.0              # タイムステップ（秒）
```

#### 使用方法
```python
# 単一瓦礫生成
python disaster_debris_generator.py

# 複数パターン生成（プログラム内で実行）
generate_disaster_scenarios(num_scenarios=5)
```

### 2. OpenFOAMシミュレーション設定

#### controlDict（時間制御）
```c++
endTime         5;        // シミュレーション時間（秒）
deltaT          0.001;    // タイムステップ（秒）
writeInterval   500;      // 保存間隔（0.5秒ごと）
```

#### blockMeshDict（計算領域）
```c++
// 計算領域: 15m × 15m × 5m
vertices
(
    (0 0 0)      // 原点
    (15 0 0)     // X方向15m
    (15 15 0)    // Y方向15m
    (0 15 0)
    (0 0 5)      // Z方向5m（高さ）
    (15 0 5)
    (15 15 5)
    (0 15 5)
);

blocks
(
    hex (0 1 2 3 4 5 6 7) (30 30 10)  // 30×30×10セル
);
```

#### 境界条件
- **inlet**: 流入口（流速 0.5 m/s）
- **outlet**: 流出口（圧力 0 Pa）
- **walls**: 壁面（滑りなし）
- **ground**: 地面（滑りなし）
- **top**: 上面（滑り）
- **debris**: 瓦礫表面（滑りなし）

### 3. メッシュ生成

#### 基本メッシュ
```bash
blockMesh  # 基本六面体メッシュ生成
```

#### 瓦礫形状への適合
```bash
snappyHexMesh -overwrite  # STL形状に合わせてメッシュ細分化
```
- セル数: 約27万セル
- 瓦礫周辺で自動的に細分化

### 4. シミュレーション実行

#### Dockerコンテナ内での実行
```bash
docker run --platform linux/amd64 --rm \
    -v "$(pwd):/workspace" \
    -w /workspace/debrisCase \
    openfoam/openfoam11-paraview510:latest \
    /bin/bash -c 'source /opt/openfoam11/etc/bashrc && foamRun -solver incompressibleFluid'
```

#### ソルバー
- **incompressibleFluid**: 非圧縮性流体ソルバー
- **SIMPLE法**: 圧力-速度連成
- **乱流モデル**: 利用可能（設定により）

### 5. 可視化

#### Web3Dビューア (openfoam_web_viewer.html)
- **機能**:
  - VTKファイルの3D表示
  - 流速ベクトル表示
  - 圧力分布表示
  - マウス操作による視点変更

#### 使用方法
1. ブラウザでHTMLファイルを開く
2. VTKファイルをドラッグ&ドロップ
3. 表示する物理量を選択（U: 流速, p: 圧力）

## 実行時間の目安

| プロセス | 時間 |
|---------|------|
| 瓦礫生成（1パターン） | 1-2分 |
| メッシュ生成 | 2-5分 |
| シミュレーション（5秒） | 10-20分 |
| VTK変換 | 1分 |
| **合計（1パターン）** | **15-30分** |
| **5パターン合計** | **70-100分** |

## トラブルシューティング

### メモリ不足エラー
```bash
# Docker Desktop設定でメモリを増やす
# Settings > Resources > Memory: 8GB以上推奨
```

### メッシュ生成エラー
```bash
# STLファイルの確認
ls -la debrisCase/constant/triSurface/
# メッシュログ確認
cat debrisCase/mesh_generation.log
```

### シミュレーション発散
```bash
# タイムステップを小さくする
# controlDict: deltaT 0.0005;
```

## 結果の解析

### シミュレーション結果の場所
```
simulation_results/pattern_1/debrisCase/
├── 0/        # 初期状態
├── 0.5/      # 0.5秒時点
├── 1.0/      # 1.0秒時点
├── ...
├── 5.0/      # 5.0秒時点（最終）
└── VTK/      # VTK形式出力
```

### 主要な評価指標
- **流速分布**: 瓦礫周辺の流れパターン
- **圧力損失**: 瓦礫による圧力変化
- **渦生成**: 瓦礫背後の渦構造
- **滞留域**: 流れが停滞する領域

## 拡張機能

### 匂い物質拡散（開発中）
```c++
// setFieldsDict での匂い源設定
regions
(
    boxToCell
    {
        box (7 7 0) (8 8 1);  // 匂い源の位置
        fieldValues
        (
            volScalarFieldValue odor 1.0
        );
    }
);
```

### 並列計算（将来対応）
```bash
# domain分割
decomposePar
# 並列実行
mpirun -np 4 foamRun -parallel
# 結果統合
reconstructPar
```

## ライセンスと引用

このプロジェクトはMITライセンスの下で公開されています。

学術利用の際は以下を引用してください：
```
災害瓦礫環境流体シミュレーションシステム
開発者: [プロジェクトチーム名]
年: 2025
```

## 貢献とサポート

- イシュー報告: GitHubのIssuesページ
- プルリクエスト歓迎
- 質問: プロジェクトのDiscussionsページ

## 更新履歴

- 2025-08-31: 初版リリース
- 5パターン個別シミュレーション機能追加
- Web3Dビューア実装
- Docker環境対応
