# 流れ場＋匂い拡散シミュレーション システム設計書

## 概要

本設計書は、OpenFOAMを用いた流れ場シミュレーションとその後の匂い拡散シミュレーションを統合的に実行するシステムの設計について記述する。

## システム構成

### 1. 現在のスクリプト構成

#### 1.1 流れ場シミュレーション
- **スクリプト**: `run_90patterns_10steps.sh`
- **ソルバー**: simpleFoam
- **シミュレーション設定**: 
  - 終了時間: 10秒
  - 時間刻み: 1秒
  - 出力間隔: 1秒（11タイムステップ）

#### 1.2 匂い拡散シミュレーション  
- **スクリプト**: `run_90patterns_odor_simulation.sh`
- **ソルバー**: simpleFoam（流れ場） + scalarTransportFoam（匂い拡散）
- **特徴**: 流れ場と匂い拡散を一つのワークフローで実行

### 2. ワークフロー設計

#### 2.1 統合ワークフロー（推奨）

```
パターンN
├── STLファイル準備（完了/Users/takeuchidaiki/research/stepB_project/debris_pattern_01.stlここと同じ階層に他のもあります。）
├── メッシュ生成 (blockMesh + snappyHexMesh)
├── 流れ場計算 (simpleFoam, 10ステップ)
├── 流れ場結果検証
├── 匂い源セルゾーン作成 (topoSet)
├── 匂い拡散計算 (scalarTransportFoam, 10ステップ)
└── 結果保存
```

#### 2.2 分離ワークフロー（代替案）

```
Phase 1: 流れ場計算
├── 全90パターンの流れ場計算実行
└── 結果検証・保存

Phase 2: 匂い拡散計算  
├── 流れ場結果を読み込み
├── 匂い源設定
├── 匂い拡散計算実行
└── 結果保存
```

### 3. 技術仕様

#### 3.1 OpenFOAM設定

**流れ場計算 (simpleFoam)**
```
application: simpleFoam
endTime: 10
deltaT: 1
writeInterval: 1
境界条件:
- inlet: 固定速度 (0.2 m/s)
- outlet: ゼロ勾配
- ground/debris: 非滑り
- atmosphere/sides: 滑り
```

**匂い拡散計算 (scalarTransportFoam)**
```
application: scalarTransportFoam
endTime: 10
deltaT: 1
writeInterval: 1
拡散係数: 0.01 m²/s
匂い源: 球状セルゾーン (半径0.5m)
```

#### 3.2 ファイル構成

```
work_pattern_XX/
├── 0/
│   ├── U          # 速度場初期条件
│   ├── p          # 圧力場初期条件
│   └── T          # 濃度場初期条件
├── constant/
│   ├── physicalProperties  # 物性値設定
│   ├── momentumTransport   # 乱流モデル
│   └── triSurface/debris.stl
└── system/
    ├── controlDict         # 実行制御
    ├── fvSchemes          # 数値スキーム
    ├── fvSolution         # ソルバー設定
    ├── blockMeshDict      # 基本メッシュ
    ├── snappyHexMeshDict  # 複雑形状メッシュ
    ├── topoSetDict        # セルゾーン定義
    └── fvOptions          # 匂い源設定
```

### 4. 実行環境

#### 4.1 Docker設定
- **イメージ**: openfoam/openfoam10-paraview510
- **実行方法**: コンテナ内でOpenFOAMソルバーを順次実行
- **タイムアウト**: 各段階で適切なタイムアウト設定

#### 4.2 リソース管理
- **メモリ**: パターンあたり2-4GB程度
- **CPU**: シングルコア処理
- **ストレージ**: パターンあたり100-500MB

### 5. データフロー

#### 5.1 入力データ
- STLファイル: `debris_pattern_XX.stl` (90パターン)
- テンプレート設定: `final_debris_01/` ディレクトリ

#### 5.2 出力データ
```
simulation_results_90patterns_odor/
├── pattern_01/
│   ├── 0-10/     # 各タイムステップ
│   │   ├── U     # 速度場
│   │   ├── p     # 圧力場
│   │   ├── T     # 濃度場
│   │   └── phi   # 体積フラックス
│   ├── constant/ # 設定ファイル
│   ├── system/   # システム設定
│   └── log.*     # 実行ログ
├── pattern_02/
...
└── pattern_90/
```

### 6. 品質管理

#### 6.1 検証項目
1. **メッシュ品質**: checkMeshによる検証
2. **流れ場収束**: 残差値監視
3. **匂い拡散収束**: 濃度場の収束確認
4. **ファイル完全性**: 全タイムステップの出力確認

#### 6.2 エラーハンドリング
- FOAM FATALエラー検出
- タイムアウト処理
- 失敗パターンの記録・報告
- Dockerコンテナのクリーンアップ

### 7. 実行手順

#### 7.1 事前準備
```bash
# STLファイル確認
ls debris_pattern_*.stl | wc -l  # 90個確認

# テンプレートディレクトリ確認
ls -la final_debris_01/

# Dockerイメージ確認
docker images openfoam/openfoam10-paraview510
```

#### 7.2 実行コマンド
```bash
# 統合ワークフロー実行
chmod +x run_90patterns_odor_simulation.sh
./run_90patterns_odor_simulation.sh

# 実行状況監視
tail -f logs_90patterns_odor/pattern_XX_odor.log
```

#### 7.3 結果確認
```bash
# 成功パターン数確認
find simulation_results_90patterns_odor -name "10" -type d | wc -l

# 濃度場確認
ls simulation_results_90patterns_odor/pattern_*/10/T
```

### 8. パフォーマンス最適化

#### 8.1 並列化オプション
- 現在: 順次実行（安定性重視）
- 将来: 複数パターン並列実行（リソース許可時）

#### 8.2 ストレージ最適化
- 中間ファイルの適時削除
- 圧縮出力オプション
- 必要最小限のタイムステップ保存

### 9. 拡張性

#### 9.1 スケーラビリティ
- パターン数の拡張（90 → N個）
- 複数種類の匂い源対応
- 時間解像度の調整

#### 9.2 出力形式
- VTKフォーマット対応
- CSV形式での結果出力
- 可視化ツール連携

### 10. 運用指針

#### 10.1 推奨実行環境
- メモリ: 8GB以上
- ストレージ: 50GB以上の空き容量
- 実行時間: 約6-12時間（90パターン）

#### 10.2 監視ポイント
- システムリソース使用量
- Dockerコンテナの状態
- ログファイルのエラー
- 出力ファイルの完全性

---

## 結論

本システムは、OpenFOAMを用いた流れ場と匂い拡散の統合シミュレーションを効率的に実行するための包括的なワークフローを提供する。適切な品質管理とエラーハンドリングにより、90パターンの大規模シミュレーションを安定して実行可能である。