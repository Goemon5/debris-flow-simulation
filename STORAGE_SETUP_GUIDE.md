# OpenFOAM シミュレーション容量管理ガイド

## 問題の概要
シミュレーション結果が大量になり、ディスク容量不足でシミュレーションが停止する問題を解決するため、自動的にGoogle Driveに結果をバックアップして容量を管理するシステムを実装しました。

## 現在の状況
- **使用中**: 190.9 GB / 228.3 GB (83.6%)
- **空き容量**: 4.6 GB
- **大容量ディレクトリ**:
  - simulation_results_90cases: 4.0 GB
  - simulation_results_gnn: 1.8 GB
  - odor_simulation_results: 0.5 GB

## 実装した解決策

### 1. 自動バックアップスクリプト (`backup_to_gdrive.py`)
- 大容量のシミュレーション結果を自動的にGoogle Driveにアップロード
- ZIP圧縮してからアップロード（帯域とストレージの節約）
- アップロード成功後、ローカルファイルを自動削除

### 2. ストレージ監視システム (`storage_manager.py`)
- リアルタイムでディスク使用量を監視
- 容量不足時の自動アラートとクリーンアップ
- 一時ファイルの自動削除

### 3. 統合実行スクリプト (`run_with_storage_management.sh`)
- シミュレーション実行前後の容量チェック
- リアルタイム容量監視
- 自動バックアップ実行

## セットアップ手順

### 1. Google Drive CLI のインストール
```bash
# Homebrew経由でインストール（macOS）
brew install gdrive

# 認証
gdrive about
```

### 2. 必要なPythonライブラリのインストール
```bash
pip3 install psutil
```

### 3. 使用方法

#### 手動でバックアップを実行
```bash
# 現在の容量状況を確認
python3 storage_manager.py

# 手動バックアップ実行（dry-run）
python3 backup_to_gdrive.py --dry-run

# 実際にバックアップ実行
python3 backup_to_gdrive.py
```

#### 自動容量管理でシミュレーション実行
```bash
# 既存のシミュレーションスクリプトを自動容量管理で実行
./run_with_storage_management.sh run_scent_with_openfoam10.sh

# またはデフォルトスクリプトで実行
./run_with_storage_management.sh
```

## 主な機能

### 自動バックアップ (`backup_to_gdrive.py`)
- **容量閾値**: デフォルト5GB未満で自動実行
- **対象ディレクトリ**: simulation_results_*, odor_simulation_results, debrisCase等
- **圧縮**: ZIP形式で圧縮後アップロード
- **クリーンアップ**: アップロード成功後ローカルファイル削除

### ストレージ監視 (`storage_manager.py`)
- **リアルタイム監視**: 5分間隔で容量チェック
- **緊急クリーンアップ**: 容量2GB未満で古い結果を自動削除
- **一時ファイル削除**: *.tmp, *.log, core.*等を自動削除

### 統合実行 (`run_with_storage_management.sh`)
- **事前チェック**: シミュレーション開始前の容量確認
- **リアルタイム監視**: 実行中の容量監視
- **事後処理**: 完了後の自動バックアップ

## 設定可能パラメータ

### backup_to_gdrive.py
- `--threshold`: バックアップ実行の閾値（GB）
- `--dry-run`: 実際の変更なしで確認

### storage_manager.py
- `--min-free`: 最小空き容量（デフォルト: 5GB）
- `--monitor`: 連続監視モード
- `--cleanup`: 緊急クリーンアップ実行

### run_with_storage_management.sh
- `MIN_FREE_GB`: 最小必要空き容量（デフォルト: 5.0GB）
- `BACKUP_THRESHOLD_GB`: バックアップ実行閾値（デフォルト: 10.0GB）

## Google Drive の構造
バックアップされたファイルは以下の構造で保存されます：
```
Google Drive/
└── OpenFOAM_Results/
    ├── simulation_results_90cases_20250908_143022.zip
    ├── simulation_results_gnn_20250908_143025.zip
    └── odor_simulation_results_20250908_143028.zip
```

## トラブルシューティング

### Google Drive認証エラー
```bash
gdrive about
# ブラウザで認証手順を完了
```

### 容量不足でシミュレーションが停止
```bash
# 緊急クリーンアップ実行
python3 storage_manager.py --cleanup

# 手動バックアップ実行
python3 backup_to_gdrive.py --threshold 15.0
```

### バックアップの復元
Google Driveから手動でファイルをダウンロードして解凍：
```bash
# Google Driveからダウンロード後
unzip simulation_results_90cases_20250908_143022.zip
```

## 推奨運用

1. **定期実行**: シミュレーション開始前に必ず `python3 storage_manager.py` で容量確認
2. **自動化**: 新しいシミュレーションは `run_with_storage_management.sh` を使用
3. **定期バックアップ**: 重要な結果は手動でも定期的にバックアップ
4. **容量監視**: 週1回程度、手動で容量状況を確認

このシステムにより、容量不足によるシミュレーション停止を防ぎ、重要なデータを安全にGoogle Driveに保管できます。