# simpleFoam全パターン実装 要件定義・設計書

## 📋 プロジェクト概要

**目的**: 現在のscalarTransportFoamから、流体計算を含むsimpleFoamへの完全移行により、GNN学習用の高品質な流体場データを取得する

**対象**: 全90パターンの瓦礫配置シミュレーション

**期待効果**: 
- 物理的に妥当な速度場・圧力場の取得
- GNNによる流体場予測精度の大幅向上
- 流体-濃度連成現象の機械学習への応用

---

## 🎯 要件定義

### 機能要件

#### FR-01: ソルバー移行
- **要件**: 全90パターンをscalarTransportFoamからsimpleFoamへ変更
- **詳細**: 定常非圧縮流体計算による速度場・圧力場の算出
- **成功基準**: 全パターンで収束解が得られること

#### FR-02: 物理設定の追加
- **要件**: 流体計算に必要な物理パラメータの設定
- **詳細**: 
  - 動粘性係数 nu = 1e-05 m²/s （空気相当）
  - 既存の拡散係数 DT = 2e-05 m²/s は保持
- **成功基準**: Reynolds数が適切な範囲（Re ~ 1000-10000）

#### FR-03: 境界条件の最適化
- **要件**: 流体計算用の境界条件設定
- **詳細**:
  - inlet: 固定速度 (2,0,0) m/s
  - outlet: 固定圧力 p=0, 速度勾配なし
  - walls: no-slip条件
  - atmosphere: slip条件
- **成功基準**: 物理的に妥当な流れパターンの形成

#### FR-04: 計算設定の最適化
- **要件**: 収束性と精度のバランス
- **詳細**:
  - SIMPLE法による圧力-速度カップリング
  - 適切な離散化スキーム（upwind/linear）
  - 収束判定基準の設定
- **成功基準**: 残差10^-6以下での収束

### 非機能要件

#### NFR-01: 計算性能
- **要件**: 全90パターンの計算を現実的な時間で完了
- **詳細**: 
  - 1パターンあたり10-30分以内
  - 全体で最大45時間以内
- **制約**: 並列計算環境の活用

#### NFR-02: データ品質
- **要件**: GNN学習に適したデータ品質
- **詳細**:
  - 速度場の物理的妥当性
  - 圧力場の連続性
  - 濃度場との整合性
- **評価**: 可視化による定性的確認

#### NFR-03: 再現性
- **要件**: 計算結果の再現可能性
- **詳細**:
  - 設定ファイルの版管理
  - 計算環境の統一
  - ログの完全保存

---

## 🏗️ システム設計

### アーキテクチャ概要

```
┌─────────────────────────┐
│    元データ (90patterns) │
│   scalarTransportFoam   │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│   変換スクリプト         │
│  - ソルバー変更          │
│  - 設定ファイル更新      │
│  - 物理パラメータ追加    │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│  simpleFoam計算環境     │
│  - Docker OpenFOAM      │
│  - 並列計算対応         │
│  - 自動化スクリプト      │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│   結果データ             │
│  - 速度場 (U)           │
│  - 圧力場 (p)           │  
│  - 濃度場 (T)           │
│  - 収束ログ             │
└─────────────────────────┘
```

### データフロー設計

#### Phase 1: 準備フェーズ
1. **環境準備**
   ```bash
   # Docker OpenFOAM環境構築
   docker pull openfoam/openfoam10-paraview510
   
   # 作業ディレクトリ作成
   mkdir -p simpleFoam_results
   ```

2. **設定変換**
   ```bash
   # 各パターンの設定ファイル更新
   for i in {01..90}; do
       convert_to_simpleFoam.sh pattern_$i
   done
   ```

#### Phase 2: 計算フェーズ
3. **並列実行**
   ```bash
   # バッチ実行スクリプト
   run_all_simpleFoam.sh
   ```

4. **進捗監視**
   ```bash
   # リアルタイム監視
   monitor_progress.sh
   ```

#### Phase 3: 検証フェーズ
5. **結果検証**
   ```bash
   # 品質チェック
   validate_results.sh
   ```

---

## 🔧 実装仕様

### ファイル構成

```
project_root/
├── scripts/
│   ├── convert_to_simpleFoam.sh      # 設定変換スクリプト
│   ├── run_all_simpleFoam.sh         # 一括実行スクリプト
│   ├── monitor_progress.sh           # 進捗監視スクリプト
│   └── validate_results.sh           # 結果検証スクリプト
├── templates/
│   ├── controlDict.template          # simpleFoam用制御ファイル
│   ├── fvSolution.template           # ソルバー設定
│   ├── fvSchemes.template            # 離散化スキーム
│   └── physicalProperties.template   # 物理特性
├── config/
│   └── solver_config.yaml            # パラメータ設定
└── simpleFoam_results/
    ├── pattern_01/                   # 各パターン結果
    ├── pattern_02/
    └── ...
```

### 主要スクリプト設計

#### convert_to_simpleFoam.sh
```bash
#!/bin/bash
# 引数: pattern_XX
PATTERN=$1
SRC_DIR="simulation_results_90patterns/$PATTERN"
DST_DIR="simpleFoam_results/$PATTERN"

# ディレクトリ準備
cp -r "$SRC_DIR" "$DST_DIR"
cd "$DST_DIR"

# 設定ファイル更新
sed -i 's/scalarTransportFoam/simpleFoam/g' system/controlDict
cp ../../templates/fvSolution.template system/fvSolution
cp ../../templates/fvSchemes.template system/fvSchemes
cp ../../templates/physicalProperties.template constant/physicalProperties

# 初期化
rm -rf [0-9]* processor* log.* postProcessing/
```

#### run_all_simpleFoam.sh
```bash
#!/bin/bash
# Docker環境での並列実行

CONTAINER_NAME="openfoam-runner"
MAX_PARALLEL=4  # 同時実行数

# 並列実行制御
for i in {01..90}; do
    while [ $(docker ps --filter name="foam-$i" | wc -l) -ge $MAX_PARALLEL ]; do
        sleep 30
    done
    
    # バックグラウンド実行
    run_single_pattern.sh $i &
done

wait  # 全完了待機
```

### 設定テンプレート

#### fvSolution.template
```openfoam
FoamFile { format ascii; class dictionary; location "system"; object fvSolution; }

solvers
{
    p
    {
        solver          GAMG;
        smoother        GaussSeidel;
        tolerance       1e-06;
        relTol          0.1;
    }
    
    U
    {
        solver          smoothSolver;
        smoother        GaussSeidel;  
        tolerance       1e-05;
        relTol          0.1;
    }
    
    T
    {
        solver          GAMG;
        smoother        GaussSeidel;
        tolerance       1e-06;
        relTol          0.1;
    }
}

SIMPLE
{
    nNonOrthogonalCorrectors 0;
    consistent              yes;
    
    residualControl
    {
        p               1e-6;
        U               1e-6;
        T               1e-6;
    }
}

relaxationFactors
{
    fields
    {
        p               0.3;
    }
    equations  
    {
        U               0.7;
        T               0.9;
    }
}
```

---

## ⚠️ リスク分析と対策

### 高リスク項目

#### R-01: 収束性問題
- **リスク**: 複雑な瓦礫形状により計算が発散
- **対策**: 
  - 緩和係数の調整
  - メッシュ品質チェック
  - 段階的収束（低Re数から開始）
- **緊急対応**: 非収束ケースの個別調整

#### R-02: 計算時間超過
- **リスク**: 想定以上の計算時間
- **対策**:
  - 並列度の最適化
  - 計算リソースの増強
  - 段階的実行（優先度別）
- **緊急対応**: 代表ケースのみ先行実行

#### R-03: メモリ不足
- **リスク**: 大規模メッシュによるメモリ枯渇
- **対策**:
  - メモリ使用量監視
  - スワップ領域確保
  - ケース別メッシュサイズ確認
- **緊急対応**: メッシュ粗化

### 中リスク項目

#### R-04: データ品質問題
- **リスク**: 物理的に不自然な流れパターン
- **対策**:
  - 可視化による定期確認
  - 典型ケースとの比較
  - 境界条件の段階的調整

#### R-05: 環境依存問題
- **リスク**: Docker環境での実行トラブル
- **対策**:
  - 事前テスト充実
  - 複数環境での動作確認
  - ログの詳細記録

---

## 📊 実装スケジュール

### マイルストーン

#### Week 1: 準備フェーズ
- Day 1-2: 環境構築・テンプレート作成
- Day 3-4: 変換スクリプト開発・テスト
- Day 5-7: 5パターンでのパイロット実行

#### Week 2-3: 実行フェーズ  
- Day 8-14: 全90パターンの一括変換
- Day 15-21: simpleFoam計算実行（監視・調整含む）

#### Week 4: 検証フェーズ
- Day 22-24: 結果検証・品質確認
- Day 25-28: データ整理・ドキュメント化

### 進捗管理指標

```yaml
KPI:
  conversion_rate: "変換完了率 (90パターン)"
  execution_rate: "計算完了率"
  convergence_rate: "収束成功率 (目標: >95%)"
  quality_score: "データ品質スコア"
  
Milestones:
  pilot_complete: "パイロット5パターン完了"
  conversion_complete: "全パターン変換完了" 
  execution_50pct: "計算50%完了"
  execution_complete: "全計算完了"
  validation_complete: "結果検証完了"
```

---

## 🎯 成功基準

### 定量的基準
- **実行完了率**: 90パターン中85パターン以上（94%以上）
- **収束達成率**: 完了パターン中95%以上が適切な残差で収束
- **データ完整性**: 速度・圧力・濃度場すべてが出力される

### 定性的基準  
- **物理妥当性**: 可視化で確認される自然な流れパターン
- **GNN適用性**: 既存の機械学習パイプラインとの互換性
- **再現性**: 同一条件での計算結果の一致

### 最低限基準（プロジェクト継続判断）
- **実行完了率**: 70%以上
- **代表的パターン**: 少なくとも30パターンで高品質データ取得
- **技術実証**: simpleFoamベースの手法確立

---

## 📈 効果測定計画

### GNN学習への影響評価
1. **ベースライン**: 現在のscalarTransportFoamデータでの学習結果
2. **改善後**: simpleFoamデータでの学習結果比較
3. **評価指標**: 
   - 速度場予測精度（R², MSE）
   - 圧力場予測精度
   - 濃度場予測精度（改善度）

### 物理現象の理解向上
- 瓦礫周りの流れパターン解析
- 濃度拡散と流体場の相関分析
- 災害時の物質輸送現象の理解深化

---

## 💡 将来展開

### 短期発展（3ヶ月）
- 非定常計算（pimpleFoam）への拡張
- 乱流モデルの導入
- より高解像度メッシュでの計算

### 中期発展（6ヶ月）  
- 多相流計算への拡張
- 化学反応を含む輸送現象
- リアルタイム予測システム

### 長期発展（1年）
- AI支援による計算条件最適化
- 大規模災害シミュレーション
- 実証実験との連携

---

**作成日**: 2025-10-13  
**版数**: v1.0  
**承認**: [承認者名]  
**次回更新予定**: パイロット実行後（1週間後）