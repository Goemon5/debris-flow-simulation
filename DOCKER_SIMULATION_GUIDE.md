# OpenFOAMシミュレーション Docker実行ガイド

## 📋 必要な環境

- Docker Desktop for Mac がインストール済み
- ターミナル（Terminal.app または iTerm2など）
- 作業ディレクトリ: `/Users/takeuchidaiki/research/stepB_project`

## 🚀 クイックスタート

### 1. ターミナルを開いて作業ディレクトリに移動

```bash
cd /Users/takeuchidaiki/research/stepB_project
```

### 2. 自動実行スクリプトを使用（推奨）

```bash
./run_simulation_docker.sh
```

メニューが表示されるので、以下から選択：
- `1`: テストシミュレーション（pattern_01のみ、約5-10分）
- `2`: 全パターンシミュレーション（40パターン、数時間）
- `3`: コンテナにログインして手動実行

## 📖 手動実行方法（詳細制御が必要な場合）

### ステップ1: Dockerコンテナの起動

```bash
# 既存コンテナがあれば削除
docker rm -f stepa_project

# 新しいコンテナを起動
docker run -dit \
    --name stepa_project \
    -v $(pwd):/work \
    -w /work \
    openfoam-cfd:latest \
    /bin/bash
```

### ステップ2: コンテナにログイン

```bash
docker exec -it stepa_project bash
```

### ステップ3: OpenFOAM環境の設定

コンテナ内で以下を実行：

```bash
# OpenFOAM環境変数を設定
source /opt/openfoam11/etc/bashrc

# 作業ディレクトリに移動
cd /work
```

### ステップ4: シミュレーション実行

#### テストシミュレーション（1パターンのみ）

```bash
./test_single_odor_simulation.sh
```

#### 全パターンシミュレーション

```bash
./run_all_odor_simulations.sh
```

### ステップ5: ログの確認

新しいターミナルウィンドウ/タブを開いて：

```bash
cd /Users/takeuchidaiki/research/stepB_project

# テストシミュレーションのログ
tail -f test_pattern_01_center.log
tail -f test_pattern_01_upwind.log
tail -f test_pattern_01_side.log

# 全パターンのログ
tail -f odor_sim_pattern_*.log
```

## 📊 実行状況のモニタリング

### リアルタイムログ監視

```bash
# 最新のログファイルを自動的に監視
watch -n 1 'ls -lt *.log | head -5'

# 特定のログをリアルタイム監視
tail -f test_pattern_01_center.log
```

### プロセス状況確認

```bash
# コンテナ内のプロセスを確認
docker exec stepa_project ps aux | grep -E "(foam|simple)"
```

### ディスク使用量確認

```bash
# 結果ディレクトリのサイズ
du -sh test_odor_results/
du -sh odor_simulation_results/
```

## 🛠️ トラブルシューティング

### エラー: "cannot find file 0/nut"

乱流モデルファイルが不足しています。修正済みのスクリプトを使用してください。

### エラー: "docker: command not found"

Docker Desktopが起動していません。Docker Desktopを起動してください。

### エラー: "solver not specified"

OpenFOAM11では`simpleFoam`が`foamRun -solver incompressibleFluid`に変更されています。
スクリプトは自動的に対応しています。

### コンテナが起動しない

```bash
# Dockerの状態確認
docker ps -a

# 問題のあるコンテナを削除
docker rm -f stepa_project

# Docker再起動
# Docker Desktop のメニューから Restart を選択
```

## 📁 結果の確認

### 結果ファイルの場所

- テスト結果: `test_odor_results/`
- 全パターン結果: `odor_simulation_results/`

### VTKファイルへの変換（可視化用）

```bash
docker exec stepa_project bash -c "
    source /opt/openfoam11/etc/bashrc
    cd /work/test_odor_results/pattern_01_center
    foamToVTK
"
```

### ParaViewでの可視化

1. ParaViewを起動
2. File > Open でVTKディレクトリを選択
3. データを読み込んで可視化

## 💡 便利なコマンド

### コンテナの状態確認

```bash
# 実行中のコンテナ
docker ps

# すべてのコンテナ（停止中も含む）
docker ps -a
```

### コンテナの削除

```bash
docker rm -f stepa_project
```

### ログファイルのクリア

```bash
rm -f *.log
```

### 結果のバックアップ

```bash
tar -czf results_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
    test_odor_results/ \
    odor_simulation_results/ \
    *.log
```

## 🔄 定期実行

cronで定期実行する場合：

```bash
# crontab -e で以下を追加
0 2 * * * cd /Users/takeuchidaiki/research/stepB_project && ./run_simulation_docker.sh
```

## 📞 サポート

問題が発生した場合は、以下の情報と共に報告してください：

1. エラーメッセージ（ログファイルの内容）
2. 実行したコマンド
3. `docker version` の出力
4. `ls -la` の出力