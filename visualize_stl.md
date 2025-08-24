# STLファイルの確認方法

## 1. Pythonスクリプトで確認（推奨）

作成した`stl_viewer.py`を使用：

```bash
# 単一ファイルを表示
python stl_viewer.py debris_01.stl

# すべての瓦礫パターンを一度に表示
python stl_viewer.py --all

# 2つのファイルを比較
python stl_viewer.py --compare debris_01.stl debris_02.stl
```

## 2. 無料の3Dビューアソフトウェア

### Mac向け
- **Ultimaker Cura** (無料): 3Dプリンター用スライサーだが優れたSTLビューア機能あり
  - https://ultimaker.com/software/ultimaker-cura
- **FreeCAD** (無料): オープンソースのCADソフト
  - https://www.freecadweb.org/
- **MeshLab** (無料): メッシュ処理専用ツール
  - https://www.meshlab.net/

### オンラインビューア（インストール不要）
- **ViewSTL**: https://www.viewstl.com/
- **3D Viewer Online**: https://3dviewer.net/
- **Autodesk Viewer**: https://viewer.autodesk.com/

### macOS標準機能
- **Quick Look**: FinderでSTLファイルを選択してスペースキーを押すと簡単にプレビュー可能

## 3. コマンドラインで基本情報を確認

```bash
# trimeshを使った簡単な情報表示
python -c "import trimesh; m = trimesh.load('debris_01.stl'); print(f'頂点数: {len(m.vertices)}, 面数: {len(m.faces)}, 体積: {m.volume:.3f}m³')"
```

## 4. Jupyter Notebookで確認

```python
import trimesh
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

# STLファイルを読み込み
mesh = trimesh.load('debris_01.stl')

# 3Dプロット
fig = plt.figure(figsize=(10, 8))
ax = fig.add_subplot(111, projection='3d')

# メッシュの頂点を取得
vertices = mesh.vertices
faces = mesh.faces

# ポリゴンを描画
ax.plot_trisurf(vertices[:, 0], vertices[:, 1], vertices[:, 2],
                triangles=faces, alpha=0.8, shade=True)

ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_zlabel('Z')
ax.set_title('Debris 3D Model')

plt.show()
```

## 推奨方法

1. **簡単な確認**: macOSのQuick Look（スペースキー）
2. **詳細な確認**: `python stl_viewer.py debris_01.stl`
3. **複数比較**: `python stl_viewer.py --all`
4. **プロ向け**: MeshLabやFreeCAD