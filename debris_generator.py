#!/usr/bin/env python3
"""
瓦礫環境シミュレーション用3Dモデル生成スクリプト
物理シミュレーションを使用して、リアルな瓦礫の山を自動生成しSTLファイルとしてエクスポートする
"""

import pybullet as p
import pybullet_data
import numpy as np
import trimesh
import random
from typing import List, Tuple, Optional

# ===========================================
# パラメータ設定部
# ===========================================
# 出力ファイル名
OUTPUT_FILENAME = 'debris_01.stl'

# オブジェクト数の設定
NUM_CUBES = 4  # 立方体の数
NUM_L_SHAPES = 0  # L字ブロックの数（まず立方体のみでテスト）

# 初期配置エリアの設定
SPAWN_AREA_SIZE = (2.0, 2.0)  # XY平面での初期配置範囲（メートル）
SPAWN_HEIGHT = 2.0  # 初期配置の高さ（メートル）

# オブジェクトサイズの範囲
OBJECT_SIZE_RANGE = (0.2, 0.5)  # 各オブジェクトの基本サイズ範囲（メートル）

# シミュレーション設定
SIMULATION_STEPS = 3000  # シミュレーションステップ数
TIME_STEP = 1/240.0  # タイムステップ（秒）
STABILITY_THRESHOLD = 0.001  # 安定判定の速度閾値（m/s）
STABILITY_CHECK_INTERVAL = 100  # 安定性チェックの間隔（ステップ）

# ランダムシード（再現性のため）
RANDOM_SEED = None  # Noneの場合はランダム、数値を設定すると再現可能


class DebrisGenerator:
    """瓦礫生成クラス"""
    
    def __init__(self):
        """コンストラクタ"""
        self.client = None
        self.object_ids = []
        self.meshes = []
        
        # ランダムシードの設定
        if RANDOM_SEED is not None:
            random.seed(RANDOM_SEED)
            np.random.seed(RANDOM_SEED)
    
    def setup_environment(self, use_gui: bool = False):
        """
        シミュレーション環境のセットアップ
        
        Args:
            use_gui: GUIを使用するかどうか（デバッグ用）
        """
        # PyBulletの初期化
        if use_gui:
            self.client = p.connect(p.GUI)
            p.configureDebugVisualizer(p.COV_ENABLE_GUI, 0)
        else:
            self.client = p.connect(p.DIRECT)
        
        # 追加のサーチパス設定
        p.setAdditionalSearchPath(pybullet_data.getDataPath())
        
        # 重力設定
        p.setGravity(0, 0, -9.81)
        
        # タイムステップ設定
        p.setTimeStep(TIME_STEP)
        
        # 地面の作成
        plane_id = p.loadURDF("plane.urdf")
        
        # 地面の摩擦係数を設定
        p.changeDynamics(plane_id, -1, 
                        lateralFriction=0.8,
                        spinningFriction=0.1,
                        rollingFriction=0.1,
                        restitution=0.2)
    
    def create_cube(self, size: float, position: Tuple[float, float, float], 
                   orientation: Optional[List[float]] = None) -> int:
        """
        立方体オブジェクトの作成
        
        Args:
            size: 立方体の一辺のサイズ
            position: 初期位置 (x, y, z)
            orientation: 初期姿勢（クォータニオン）
        
        Returns:
            作成されたオブジェクトのID
        """
        if orientation is None:
            orientation = p.getQuaternionFromEuler([
                random.uniform(0, 2*np.pi),
                random.uniform(0, 2*np.pi),
                random.uniform(0, 2*np.pi)
            ])
        
        # 衝突形状の作成
        collision_shape = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[size/2, size/2, size/2]
        )
        
        # 視覚形状の作成
        visual_shape = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[size/2, size/2, size/2],
            rgbaColor=[0.5, 0.5, 0.5, 1.0]
        )
        
        # マルチボディの作成
        mass = size**3 * 2500  # 密度を仮定（コンクリート相当）
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        # 物理パラメータの設定
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.6,
                        spinningFriction=0.05,
                        rollingFriction=0.05,
                        restitution=0.1)
        
        return body_id
    
    def create_l_shape(self, size: float, position: Tuple[float, float, float],
                      orientation: Optional[List[float]] = None) -> int:
        """
        L字ブロックの作成
        
        Args:
            size: 基本サイズ
            position: 初期位置 (x, y, z)
            orientation: 初期姿勢（クォータニオン）
        
        Returns:
            作成されたオブジェクトのID
        """
        if orientation is None:
            orientation = p.getQuaternionFromEuler([
                random.uniform(0, 2*np.pi),
                random.uniform(0, 2*np.pi),
                random.uniform(0, 2*np.pi)
            ])
        
        # L字形状を2つのボックスで構成
        # 長い部分
        long_box = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[size*0.8, size*0.3, size*0.3]
        )
        
        # 短い部分
        short_box = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[size*0.3, size*0.3, size*0.3]
        )
        
        # 視覚形状も同様に作成
        long_visual = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[size*0.8, size*0.3, size*0.3],
            rgbaColor=[0.6, 0.4, 0.3, 1.0]
        )
        
        short_visual = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[size*0.3, size*0.3, size*0.3],
            rgbaColor=[0.6, 0.4, 0.3, 1.0]
        )
        
        # 複合形状の作成
        mass = size**3 * 2000  # 密度を仮定
        
        # リンク位置（L字の接続部分）
        link_positions = [
            [0, 0, 0],  # ベースリンク（長い部分）
            [size*0.5, 0, size*0.6]  # 短い部分
        ]
        
        link_orientations = [
            [0, 0, 0, 1],
            [0, 0, 0, 1]
        ]
        
        link_masses = [mass * 0.7, mass * 0.3]
        link_collision_shapes = [long_box, short_box]
        link_visual_shapes = [long_visual, short_visual]
        
        # ベースの作成
        body_id = p.createMultiBody(
            baseMass=0,  # ベース質量は0にして、リンクに質量を持たせる
            baseCollisionShapeIndex=-1,
            baseVisualShapeIndex=-1,
            basePosition=position,
            baseOrientation=orientation,
            linkMasses=link_masses,
            linkCollisionShapeIndices=link_collision_shapes,
            linkVisualShapeIndices=link_visual_shapes,
            linkPositions=link_positions,
            linkOrientations=link_orientations,
            linkInertialFramePositions=[[0, 0, 0]] * 2,
            linkInertialFrameOrientations=[[0, 0, 0, 1]] * 2,
            linkParentIndices=[0, 0],
            linkJointTypes=[p.JOINT_FIXED, p.JOINT_FIXED],
            linkJointAxis=[[0, 0, 1]] * 2
        )
        
        # 物理パラメータの設定
        for link_id in range(-1, 2):
            p.changeDynamics(body_id, link_id,
                           lateralFriction=0.6,
                           spinningFriction=0.05,
                           rollingFriction=0.05,
                           restitution=0.1)
        
        return body_id
    
    def generate_debris(self):
        """瓦礫の生成とシミュレーション実行"""
        print("瓦礫の生成を開始します...")
        
        # 立方体の生成
        for i in range(NUM_CUBES):
            size = random.uniform(*OBJECT_SIZE_RANGE)
            x = random.uniform(-SPAWN_AREA_SIZE[0]/2, SPAWN_AREA_SIZE[0]/2)
            y = random.uniform(-SPAWN_AREA_SIZE[1]/2, SPAWN_AREA_SIZE[1]/2)
            z = SPAWN_HEIGHT + i * 0.5  # 高さをずらして配置
            
            cube_id = self.create_cube(size, (x, y, z))
            self.object_ids.append(cube_id)
            print(f"  立方体 {i+1}/{NUM_CUBES} を生成しました (サイズ: {size:.2f}m)")
        
        # L字ブロックの生成
        for i in range(NUM_L_SHAPES):
            size = random.uniform(*OBJECT_SIZE_RANGE)
            x = random.uniform(-SPAWN_AREA_SIZE[0]/2, SPAWN_AREA_SIZE[0]/2)
            y = random.uniform(-SPAWN_AREA_SIZE[1]/2, SPAWN_AREA_SIZE[1]/2)
            z = SPAWN_HEIGHT + (NUM_CUBES + i) * 0.5
            
            l_shape_id = self.create_l_shape(size, (x, y, z))
            self.object_ids.append(l_shape_id)
            print(f"  L字ブロック {i+1}/{NUM_L_SHAPES} を生成しました (サイズ: {size:.2f}m)")
    
    def run_simulation(self):
        """シミュレーションの実行と安定化待機"""
        print("\nシミュレーションを実行中...")
        
        stable_count = 0
        for step in range(SIMULATION_STEPS):
            p.stepSimulation()
            
            # 定期的に安定性をチェック
            if step % STABILITY_CHECK_INTERVAL == 0 and step > 500:
                if self.check_stability():
                    stable_count += 1
                    if stable_count >= 3:  # 3回連続で安定したら終了
                        print(f"  ステップ {step} で安定しました")
                        break
                else:
                    stable_count = 0
            
            # 進捗表示
            if step % 500 == 0:
                print(f"  ステップ: {step}/{SIMULATION_STEPS}")
        
        print("シミュレーション完了")
    
    def check_stability(self) -> bool:
        """
        全オブジェクトの安定性をチェック
        
        Returns:
            安定している場合True
        """
        for obj_id in self.object_ids:
            velocity, _ = p.getBaseVelocity(obj_id)
            speed = np.linalg.norm(velocity)
            if speed > STABILITY_THRESHOLD:
                return False
        return True
    
    def extract_meshes(self):
        """シミュレーション結果からメッシュデータを抽出"""
        print("\nメッシュデータを抽出中...")
        
        for i, obj_id in enumerate(self.object_ids):
            # オブジェクトの位置と姿勢を取得
            pos, orn = p.getBasePositionAndOrientation(obj_id)
            
            # 視覚形状データを取得
            visual_data = p.getVisualShapeData(obj_id)
            
            for visual in visual_data:
                # ジオメトリタイプを確認
                geom_type = visual[2]
                dimensions = visual[3]
                
                if geom_type == p.GEOM_BOX:
                    # ボックスメッシュの作成
                    box = trimesh.creation.box(extents=[
                        dimensions[0] * 2,
                        dimensions[1] * 2,
                        dimensions[2] * 2
                    ])
                    
                    # 変換行列の作成
                    transform_matrix = np.eye(4)
                    transform_matrix[:3, :3] = np.array(p.getMatrixFromQuaternion(orn)).reshape(3, 3)
                    transform_matrix[:3, 3] = pos
                    
                    # リンクがある場合の相対位置を考慮
                    link_index = visual[1]
                    if link_index >= 0:
                        link_state = p.getLinkState(obj_id, link_index)
                        link_pos = link_state[0]
                        link_orn = link_state[1]
                        
                        link_transform = np.eye(4)
                        link_transform[:3, :3] = np.array(p.getMatrixFromQuaternion(link_orn)).reshape(3, 3)
                        link_transform[:3, 3] = link_pos
                        transform_matrix = link_transform
                    
                    # 変換を適用
                    box.apply_transform(transform_matrix)
                    self.meshes.append(box)
        
        print(f"  {len(self.meshes)} 個のメッシュを抽出しました")
    
    def export_to_stl(self, filename: str):
        """
        メッシュデータをSTLファイルとしてエクスポート
        
        Args:
            filename: 出力ファイル名
        """
        print(f"\nSTLファイルをエクスポート中: {filename}")
        
        if not self.meshes:
            print("エクスポートするメッシュがありません")
            return
        
        # すべてのメッシュを結合
        combined_mesh = trimesh.util.concatenate(self.meshes)
        
        # STLファイルとして保存
        combined_mesh.export(filename)
        
        # メッシュ情報を表示
        print(f"エクスポート完了:")
        print(f"  頂点数: {len(combined_mesh.vertices)}")
        print(f"  面数: {len(combined_mesh.faces)}")
        print(f"  バウンディングボックス: {combined_mesh.bounds}")
    
    def cleanup(self):
        """リソースのクリーンアップ"""
        if self.client is not None:
            p.disconnect()
    
    def run(self, output_filename: str = OUTPUT_FILENAME, use_gui: bool = False):
        """
        瓦礫生成の実行
        
        Args:
            output_filename: 出力ファイル名
            use_gui: GUIを使用するかどうか
        """
        try:
            # 環境セットアップ
            self.setup_environment(use_gui=use_gui)
            
            # 瓦礫生成
            self.generate_debris()
            
            # シミュレーション実行
            self.run_simulation()
            
            # メッシュ抽出
            self.extract_meshes()
            
            # STLエクスポート
            self.export_to_stl(output_filename)
            
        finally:
            # クリーンアップ
            self.cleanup()


def generate_multiple_patterns(num_patterns: int = 10, base_filename: str = "debris"):
    """
    複数パターンの瓦礫を生成
    
    Args:
        num_patterns: 生成するパターン数
        base_filename: ベースとなるファイル名
    """
    print(f"\n{num_patterns} パターンの瓦礫を生成します\n")
    
    for i in range(num_patterns):
        print(f"="*50)
        print(f"パターン {i+1}/{num_patterns}")
        print(f"="*50)
        
        # ファイル名の生成
        filename = f"{base_filename}_{i+1:02d}.stl"
        
        # ジェネレータのインスタンス作成（毎回新しいランダムシードで）
        generator = DebrisGenerator()
        
        # 瓦礫生成実行
        generator.run(output_filename=filename, use_gui=False)
        
        print(f"\n完了: {filename}\n")


if __name__ == "__main__":
    # 単一パターンの生成（デフォルト）
    # generator = DebrisGenerator()
    # generator.run(use_gui=False)  # use_gui=TrueにするとGUIで確認可能
    
    # 複数パターンの生成
    generate_multiple_patterns(num_patterns=10, base_filename="debris")