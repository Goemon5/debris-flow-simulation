# 最適GNNデータセット構築計画

## 🎯 データセット構成戦略

### **最終目標データセット**
```
90パターン × 高品質物理場データ = 最適GNN学習環境
```

---

## 📊 データ品質比較分析

### **現状の課題と解決策**

| 物理場 | 現在（scalarTransportFoam） | 改善後（分離戦略） | 品質向上 |
|--------|---------------------------|------------------|----------|
| **速度場(U)** | ❌ 一様流 `(2,0,0)` | ✅ 物理的非一様分布 | **劇的改善** |
| **圧力場(p)** | ❌ 全て `0` | ✅ 現実的圧力勾配 | **劇的改善** |
| **濃度場(T)** | ✅ 高品質拡散パターン | ✅ そのまま活用 | **維持** |

---

## 🗂️ 新データセット構造設計

### **階層データ構造**
```
optimal_gnn_dataset/
├── metadata/
│   ├── pattern_info.json          # 各パターンの瓦礫配置情報
│   ├── simulation_params.yaml     # 物理パラメータ
│   └── quality_metrics.csv        # データ品質指標
├── mesh_data/
│   ├── pattern_01/
│   │   ├── points                  # メッシュ節点
│   │   ├── cells                   # メッシュセル
│   │   └── boundaries              # 境界情報
│   └── ...
├── fluid_fields/                   # 新規：simpleFoam結果
│   ├── pattern_01/
│   │   ├── velocity_field.npy      # U場（3D vector）
│   │   ├── pressure_field.npy      # p場（scalar）
│   │   └── convergence_log.txt     # 収束履歴
│   └── ...
├── scalar_fields/                  # 既存：scalarTransportFoam結果
│   ├── pattern_01/
│   │   ├── concentration_field.npy # T場（scalar）
│   │   └── diffusion_log.txt       # 拡散計算ログ
│   └── ...
└── integrated_data/               # GNN学習用統合データ
    ├── train_dataset.h5            # 訓練用データ
    ├── val_dataset.h5              # 検証用データ
    ├── test_dataset.h5             # テスト用データ
    └── dataset_stats.json          # データセット統計
```

### **データ形式標準化**

#### **メッシュデータ**
```python
mesh_data = {
    'nodes': np.array([N, 3]),          # 節点座標
    'cells': np.array([C, 4]),          # テトラメッシュ
    'boundaries': {
        'inlet': node_indices,
        'outlet': node_indices, 
        'walls': node_indices,
        'debris': node_indices
    },
    'cell_centers': np.array([C, 3]),   # セル中心座標
    'cell_volumes': np.array([C]),      # セル体積
}
```

#### **物理場データ**
```python
physics_data = {
    'pattern_id': str,                  # パターンID
    'debris_config': debris_geometry,   # 瓦礫配置
    
    # 流体場（新規・高品質）
    'velocity': {
        'data': np.array([C, 3]),       # 速度ベクトル
        'magnitude': np.array([C]),     # 速度大きさ
        'streamlines': streamline_data, # 流線情報
    },
    'pressure': {
        'data': np.array([C]),          # 圧力値
        'gradient': np.array([C, 3]),   # 圧力勾配
    },
    
    # 濃度場（既存・活用）
    'concentration': {
        'data': np.array([C]),          # 濃度値
        'gradient': np.array([C, 3]),   # 濃度勾配
        'source_location': np.array([3]), # 放出点座標
    }
}
```

---

## 🔄 データ処理パイプライン

### **Step 1: 原データ変換**
```python
# OpenFOAMデータ → NumPy配列変換
def convert_openfoam_to_numpy():
    for pattern in range(1, 91):
        # 流体場データ変換
        U_data = read_openfoam_field(f'simpleFoam_results/pattern_{pattern:02d}/1/U')
        p_data = read_openfoam_field(f'simpleFoam_results/pattern_{pattern:02d}/1/p')
        
        # 濃度場データ変換  
        T_data = read_openfoam_field(f'simulation_results_90patterns/pattern_{pattern:02d}/5/T')
        
        save_processed_data(pattern, U_data, p_data, T_data)
```

### **Step 2: 品質検証**
```python
def validate_data_quality():
    quality_metrics = {}
    for pattern in patterns:
        # 物理的妥当性チェック
        metrics = {
            'velocity_range': check_velocity_bounds(U_data),
            'pressure_continuity': check_pressure_continuity(p_data),
            'mass_conservation': check_divergence(U_data),
            'concentration_conservation': check_total_mass(T_data),
        }
        quality_metrics[pattern] = metrics
    return quality_metrics
```

### **Step 3: GNN学習形式変換**
```python
def create_gnn_dataset():
    # グラフ構造生成
    graph_data = []
    for pattern in patterns:
        # ノード特徴量
        node_features = np.concatenate([
            mesh_coordinates,      # 空間位置 [x, y, z]
            debris_indicators,     # 瓦礫の有無 [0/1]
            boundary_types,        # 境界タイプ [inlet/outlet/wall/debris]
        ])
        
        # エッジ情報
        edge_indices = build_mesh_connectivity()
        edge_features = compute_edge_features()
        
        # ターゲット（物理場）
        targets = {
            'velocity': U_data,
            'pressure': p_data, 
            'concentration': T_data,
        }
        
        graph_data.append({
            'x': node_features,
            'edge_index': edge_indices,
            'edge_attr': edge_features,
            'y': targets,
        })
    
    return graph_data
```

---

## 📈 品質管理指標

### **データ完整性指標**
```yaml
completeness_metrics:
  pattern_coverage: 90/90      # 全パターンカバー率
  field_coverage:              # 各物理場のデータ完整性
    velocity: 100%
    pressure: 100% 
    concentration: 100%
  mesh_quality:                # メッシュ品質
    min_cell_volume: > 1e-10
    max_aspect_ratio: < 100
    mesh_orthogonality: > 0.1
```

### **物理妥当性指標**
```yaml
physics_validation:
  velocity_field:
    max_velocity: < 10.0       # 物理的上限
    divergence_error: < 1e-3   # 非圧縮性
    boundary_condition: valid   # 境界条件満足
  pressure_field:
    pressure_range: [-1000, 1000]  # 合理的範囲
    gradient_continuity: > 0.95     # 連続性
  concentration_field:
    mass_conservation: 0.999    # 質量保存
    non_negative: 100%          # 非負値
    diffusion_physics: valid    # 拡散法則
```

---

## 🎯 GNN学習最適化

### **学習データ分割戦略**
```python
data_split = {
    'train': patterns[0:72],    # 80% - 72パターン
    'val': patterns[72:81],     # 10% - 9パターン  
    'test': patterns[81:90],    # 10% - 9パターン
}

# 戦略的分割（瓦礫パターンの多様性を保証）
stratified_split = {
    'simple_patterns': [1, 10, 20, ...],     # 単純形状
    'complex_patterns': [30, 50, 70, ...],   # 複雑形状
    'extreme_patterns': [45, 65, 85, ...],   # 極端形状
}
```

### **マルチタスク学習設計**
```python
class MultiPhysicsGNN(nn.Module):
    def __init__(self):
        self.encoder = GraphEncoder()
        self.fluid_head = FluidPredictor()      # U, p予測
        self.scalar_head = ScalarPredictor()    # T予測
        self.joint_head = JointPredictor()      # 連成予測
    
    def forward(self, graph_data):
        # 共通特徴抽出
        features = self.encoder(graph_data)
        
        # 各物理場予測
        velocity, pressure = self.fluid_head(features)
        concentration = self.scalar_head(features, velocity)  # 流体場依存
        
        return {
            'velocity': velocity,
            'pressure': pressure,
            'concentration': concentration,
        }
```

---

## ⚡ 実装ロードマップ

### **Week 1: データ生成**
- [x] SimpleFoam全90パターン実行（JAISTスパコン）
- [ ] 流体場データ品質検証
- [ ] データ形式標準化・変換

### **Week 2: データセット構築** 
- [ ] 統合データセット作成
- [ ] 品質指標計算・検証
- [ ] GNN学習形式変換

### **Week 3: 学習パイプライン**
- [ ] マルチタスク学習実装
- [ ] ベースライン比較実験
- [ ] 性能評価・分析

### **Week 4: 最適化・応用**
- [ ] ハイパーパラメータ調整
- [ ] 実用アプリケーション検討
- [ ] 論文・発表準備

---

この計画により、**既存の高品質濃度場データ**と**新規の物理的流体場データ**を組み合わせた、最適なGNN学習環境を構築できます！

---
**作成日**: 2025-10-13  
**目標**: 最高品質GNN学習データセット構築  
**期待成果**: 流体・濃度場予測精度の劇的向上