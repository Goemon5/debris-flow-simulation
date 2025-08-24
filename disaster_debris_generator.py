#!/usr/bin/env python3
"""
災害瓦礫環境シミュレーション用3Dモデル生成スクリプト
建物崩壊を想定した、人が下敷きになるような現実的な瓦礫環境を生成
救助訓練、救助ロボット開発、災害シミュレーション用途を想定
"""

import pybullet as p
import pybullet_data
import numpy as np
import trimesh
import random
from typing import List, Tuple, Optional, Dict
from dataclasses import dataclass

# ===========================================
# パラメータ設定部（災害現場想定）
# ===========================================
# 出力ファイル名
OUTPUT_FILENAME = 'disaster_debris_01.stl'

# 建物構造材の数（実際の建物崩壊を想定）
NUM_WALL_FRAGMENTS = 8  # 壁片（大型コンクリート片）
NUM_BEAMS = 6  # 梁（鉄骨やコンクリート梁）
NUM_COLUMNS = 4  # 柱（支柱）
NUM_FLOOR_SLABS = 3  # 床スラブ（大型の平板）
NUM_SMALL_DEBRIS = 15  # 小瓦礫（家具、設備の破片など）

# 崩壊エリアの設定（実際の建物規模を想定）
COLLAPSE_AREA_SIZE = (8.0, 8.0)  # XY平面での崩壊範囲（メートル）
SPAWN_HEIGHT_MIN = 3.0  # 最小落下高さ（1階分の高さ）
SPAWN_HEIGHT_MAX = 9.0  # 最大落下高さ（3階分の高さ）

# 構造材サイズ範囲（実際の建築材料を想定）
WALL_SIZE_RANGE = ((2.0, 0.2, 1.5), (4.0, 0.3, 2.5))  # 壁片（幅×厚×高）
BEAM_SIZE_RANGE = ((3.0, 0.3, 0.3), (6.0, 0.5, 0.5))  # 梁（長×幅×高）
COLUMN_SIZE_RANGE = ((0.4, 0.4, 2.5), (0.6, 0.6, 3.5))  # 柱（幅×奥行×高）
FLOOR_SLAB_SIZE_RANGE = ((2.0, 2.0, 0.15), (4.0, 4.0, 0.25))  # 床スラブ
SMALL_DEBRIS_SIZE_RANGE = (0.2, 0.8)  # 小瓦礫

# 物理パラメータ（実際の材料特性を反映）
CONCRETE_DENSITY = 2400  # kg/m³（コンクリート）
STEEL_DENSITY = 7850  # kg/m³（鉄骨）
DEBRIS_DENSITY = 1500  # kg/m³（混合瓦礫）

# シミュレーション設定
SIMULATION_STEPS = 5000  # より長いシミュレーション時間
TIME_STEP = 1/240.0
STABILITY_THRESHOLD = 0.005
STABILITY_CHECK_INTERVAL = 200

# 生存空間検出設定
VOID_SPACE_MIN_SIZE = (0.6, 0.6, 0.4)  # 人が入れる最小空間（メートル）

# ランダムシード
RANDOM_SEED = None


@dataclass
class DebrisObject:
    """瓦礫オブジェクトのデータクラス"""
    body_id: int
    object_type: str
    size: Tuple[float, float, float]
    material: str
    mass: float


class DisasterDebrisGenerator:
    """災害瓦礫生成クラス"""
    
    def __init__(self):
        """コンストラクタ"""
        self.client = None
        self.debris_objects: List[DebrisObject] = []
        self.meshes = []
        self.void_spaces = []
        
        if RANDOM_SEED is not None:
            random.seed(RANDOM_SEED)
            np.random.seed(RANDOM_SEED)
    
    def setup_environment(self, use_gui: bool = False):
        """
        シミュレーション環境のセットアップ
        """
        # PyBulletの初期化
        if use_gui:
            self.client = p.connect(p.GUI)
            p.configureDebugVisualizer(p.COV_ENABLE_GUI, 0)
            p.configureDebugVisualizer(p.COV_ENABLE_SHADOWS, 1)
            # カメラ位置を設定
            p.resetDebugVisualizerCamera(
                cameraDistance=15,
                cameraYaw=45,
                cameraPitch=-30,
                cameraTargetPosition=[0, 0, 2]
            )
        else:
            self.client = p.connect(p.DIRECT)
        
        p.setAdditionalSearchPath(pybullet_data.getDataPath())
        p.setGravity(0, 0, -9.81)
        p.setTimeStep(TIME_STEP)
        
        # 地面の作成（コンクリート床を想定）
        plane_id = p.loadURDF("plane.urdf")
        p.changeDynamics(plane_id, -1, 
                        lateralFriction=0.9,
                        spinningFriction=0.2,
                        rollingFriction=0.1,
                        restitution=0.1)
    
    def create_wall_fragment(self, position: Tuple[float, float, float]) -> DebrisObject:
        """
        壁片（大型コンクリート片）の作成
        """
        # ランダムなサイズ生成
        size = [
            random.uniform(WALL_SIZE_RANGE[0][0], WALL_SIZE_RANGE[1][0]),
            random.uniform(WALL_SIZE_RANGE[0][1], WALL_SIZE_RANGE[1][1]),
            random.uniform(WALL_SIZE_RANGE[0][2], WALL_SIZE_RANGE[1][2])
        ]
        
        # ランダムな初期姿勢
        orientation = p.getQuaternionFromEuler([
            random.uniform(-np.pi/4, np.pi/4),
            random.uniform(-np.pi/4, np.pi/4),
            random.uniform(0, 2*np.pi)
        ])
        
        # 衝突・視覚形状の作成
        collision_shape = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size]
        )
        
        visual_shape = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size],
            rgbaColor=[0.6, 0.6, 0.6, 1.0]  # コンクリート色
        )
        
        # 質量計算
        volume = size[0] * size[1] * size[2]
        mass = volume * CONCRETE_DENSITY
        
        # ボディ作成
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        # 物理パラメータ設定（コンクリート特性）
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.8,
                        spinningFriction=0.15,
                        rollingFriction=0.1,
                        restitution=0.05)
        
        return DebrisObject(body_id, "wall", tuple(size), "concrete", mass)
    
    def create_beam(self, position: Tuple[float, float, float]) -> DebrisObject:
        """
        梁（鉄骨またはコンクリート梁）の作成
        """
        size = [
            random.uniform(BEAM_SIZE_RANGE[0][0], BEAM_SIZE_RANGE[1][0]),
            random.uniform(BEAM_SIZE_RANGE[0][1], BEAM_SIZE_RANGE[1][1]),
            random.uniform(BEAM_SIZE_RANGE[0][2], BEAM_SIZE_RANGE[1][2])
        ]
        
        orientation = p.getQuaternionFromEuler([
            random.uniform(0, np.pi/6),
            random.uniform(0, np.pi/6),
            random.uniform(0, 2*np.pi)
        ])
        
        # I型鋼のような形状を簡略化してボックスで表現
        collision_shape = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size]
        )
        
        # 鉄骨は暗い色
        visual_shape = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size],
            rgbaColor=[0.3, 0.3, 0.35, 1.0]
        )
        
        volume = size[0] * size[1] * size[2]
        mass = volume * STEEL_DENSITY * 0.3  # 中空構造を考慮
        
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.7,
                        spinningFriction=0.1,
                        rollingFriction=0.05,
                        restitution=0.1)
        
        return DebrisObject(body_id, "beam", tuple(size), "steel", mass)
    
    def create_column(self, position: Tuple[float, float, float]) -> DebrisObject:
        """
        柱（構造柱）の作成
        """
        size = [
            random.uniform(COLUMN_SIZE_RANGE[0][0], COLUMN_SIZE_RANGE[1][0]),
            random.uniform(COLUMN_SIZE_RANGE[0][1], COLUMN_SIZE_RANGE[1][1]),
            random.uniform(COLUMN_SIZE_RANGE[0][2], COLUMN_SIZE_RANGE[1][2])
        ]
        
        # 柱は倒れた状態で配置されることが多い
        orientation = p.getQuaternionFromEuler([
            random.uniform(0, np.pi/2),
            random.uniform(0, np.pi/2),
            random.uniform(0, 2*np.pi)
        ])
        
        collision_shape = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size]
        )
        
        visual_shape = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size],
            rgbaColor=[0.65, 0.65, 0.65, 1.0]
        )
        
        volume = size[0] * size[1] * size[2]
        mass = volume * CONCRETE_DENSITY
        
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.85,
                        spinningFriction=0.2,
                        rollingFriction=0.15,
                        restitution=0.05)
        
        return DebrisObject(body_id, "column", tuple(size), "concrete", mass)
    
    def create_floor_slab(self, position: Tuple[float, float, float]) -> DebrisObject:
        """
        床スラブ（大型平板）の作成
        """
        size = [
            random.uniform(FLOOR_SLAB_SIZE_RANGE[0][0], FLOOR_SLAB_SIZE_RANGE[1][0]),
            random.uniform(FLOOR_SLAB_SIZE_RANGE[0][1], FLOOR_SLAB_SIZE_RANGE[1][1]),
            random.uniform(FLOOR_SLAB_SIZE_RANGE[0][2], FLOOR_SLAB_SIZE_RANGE[1][2])
        ]
        
        # 床スラブは比較的水平に近い角度で落下
        orientation = p.getQuaternionFromEuler([
            random.uniform(-np.pi/8, np.pi/8),
            random.uniform(-np.pi/8, np.pi/8),
            random.uniform(0, 2*np.pi)
        ])
        
        collision_shape = p.createCollisionShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size]
        )
        
        visual_shape = p.createVisualShape(
            p.GEOM_BOX,
            halfExtents=[s/2 for s in size],
            rgbaColor=[0.7, 0.68, 0.65, 1.0]
        )
        
        volume = size[0] * size[1] * size[2]
        mass = volume * CONCRETE_DENSITY
        
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.9,
                        spinningFriction=0.25,
                        rollingFriction=0.2,
                        restitution=0.03)
        
        return DebrisObject(body_id, "floor_slab", tuple(size), "concrete", mass)
    
    def create_small_debris(self, position: Tuple[float, float, float]) -> DebrisObject:
        """
        小瓦礫（家具、設備の破片など）の作成
        """
        size = random.uniform(*SMALL_DEBRIS_SIZE_RANGE)
        shape_type = random.choice(["box", "irregular"])
        
        if shape_type == "box":
            # 直方体の小瓦礫
            aspect_ratios = [
                random.uniform(0.5, 2.0),
                random.uniform(0.5, 2.0),
                random.uniform(0.5, 2.0)
            ]
            actual_size = [size * ratio / np.mean(aspect_ratios) for ratio in aspect_ratios]
            
            collision_shape = p.createCollisionShape(
                p.GEOM_BOX,
                halfExtents=[s/2 for s in actual_size]
            )
            
            visual_shape = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=[s/2 for s in actual_size],
                rgbaColor=[
                    random.uniform(0.4, 0.7),
                    random.uniform(0.3, 0.6),
                    random.uniform(0.2, 0.5),
                    1.0
                ]
            )
        else:
            # 不規則な形状（球で簡略化）
            actual_size = [size, size, size]
            collision_shape = p.createCollisionShape(
                p.GEOM_SPHERE,
                radius=size/2
            )
            
            visual_shape = p.createVisualShape(
                p.GEOM_SPHERE,
                radius=size/2,
                rgbaColor=[
                    random.uniform(0.3, 0.6),
                    random.uniform(0.3, 0.6),
                    random.uniform(0.3, 0.6),
                    1.0
                ]
            )
        
        orientation = p.getQuaternionFromEuler([
            random.uniform(0, 2*np.pi),
            random.uniform(0, 2*np.pi),
            random.uniform(0, 2*np.pi)
        ])
        
        volume = actual_size[0] * actual_size[1] * actual_size[2]
        mass = volume * DEBRIS_DENSITY
        
        body_id = p.createMultiBody(
            mass,
            collision_shape,
            visual_shape,
            position,
            orientation
        )
        
        p.changeDynamics(body_id, -1,
                        lateralFriction=0.6,
                        spinningFriction=0.08,
                        rollingFriction=0.05,
                        restitution=0.15)
        
        return DebrisObject(body_id, "small_debris", tuple(actual_size), "mixed", mass)
    
    def generate_disaster_debris(self):
        """災害瓦礫の生成"""
        print("災害瓦礫の生成を開始します...")
        print(f"想定崩壊エリア: {COLLAPSE_AREA_SIZE[0]}m × {COLLAPSE_AREA_SIZE[1]}m")
        
        object_count = 0
        
        # 床スラブ（最初に配置して基礎層を作る）
        print(f"\n床スラブを配置中...")
        for i in range(NUM_FLOOR_SLABS):
            x = random.uniform(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2)
            y = random.uniform(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2)
            z = random.uniform(SPAWN_HEIGHT_MIN, SPAWN_HEIGHT_MIN + 2.0)
            
            debris = self.create_floor_slab((x, y, z))
            self.debris_objects.append(debris)
            object_count += 1
            print(f"  床スラブ {i+1}/{NUM_FLOOR_SLABS} (質量: {debris.mass:.0f}kg)")
        
        # 柱（構造材として重要）
        print(f"\n柱を配置中...")
        for i in range(NUM_COLUMNS):
            x = random.uniform(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2)
            y = random.uniform(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2)
            z = random.uniform(SPAWN_HEIGHT_MIN, SPAWN_HEIGHT_MAX)
            
            debris = self.create_column((x, y, z))
            self.debris_objects.append(debris)
            object_count += 1
            print(f"  柱 {i+1}/{NUM_COLUMNS} (質量: {debris.mass:.0f}kg)")
        
        # 梁
        print(f"\n梁を配置中...")
        for i in range(NUM_BEAMS):
            x = random.uniform(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2)
            y = random.uniform(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2)
            z = random.uniform(SPAWN_HEIGHT_MIN + 1.0, SPAWN_HEIGHT_MAX)
            
            debris = self.create_beam((x, y, z))
            self.debris_objects.append(debris)
            object_count += 1
            print(f"  梁 {i+1}/{NUM_BEAMS} (質量: {debris.mass:.0f}kg)")
        
        # 壁片
        print(f"\n壁片を配置中...")
        for i in range(NUM_WALL_FRAGMENTS):
            x = random.uniform(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2)
            y = random.uniform(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2)
            z = random.uniform(SPAWN_HEIGHT_MIN, SPAWN_HEIGHT_MAX)
            
            debris = self.create_wall_fragment((x, y, z))
            self.debris_objects.append(debris)
            object_count += 1
            print(f"  壁片 {i+1}/{NUM_WALL_FRAGMENTS} (質量: {debris.mass:.0f}kg)")
        
        # 小瓦礫
        print(f"\n小瓦礫を配置中...")
        for i in range(NUM_SMALL_DEBRIS):
            x = random.uniform(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2)
            y = random.uniform(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2)
            z = random.uniform(SPAWN_HEIGHT_MIN, SPAWN_HEIGHT_MAX + 2.0)
            
            debris = self.create_small_debris((x, y, z))
            self.debris_objects.append(debris)
            object_count += 1
        
        total_mass = sum(obj.mass for obj in self.debris_objects)
        print(f"\n生成完了: 合計 {object_count} 個のオブジェクト")
        print(f"総質量: {total_mass:.0f}kg ({total_mass/1000:.1f}トン)")
    
    def run_simulation(self):
        """シミュレーションの実行"""
        print("\n崩壊シミュレーションを実行中...")
        
        stable_count = 0
        max_kinetic_energy = 0
        
        for step in range(SIMULATION_STEPS):
            p.stepSimulation()
            
            # エネルギー計算（進捗表示用）
            if step % 100 == 0:
                kinetic_energy = self.calculate_total_kinetic_energy()
                max_kinetic_energy = max(max_kinetic_energy, kinetic_energy)
                
                if step % 500 == 0:
                    print(f"  ステップ: {step}/{SIMULATION_STEPS} (運動エネルギー: {kinetic_energy:.1f}J)")
            
            # 安定性チェック
            if step % STABILITY_CHECK_INTERVAL == 0 and step > 1000:
                if self.check_stability():
                    stable_count += 1
                    if stable_count >= 5:
                        print(f"  ステップ {step} で安定しました")
                        break
                else:
                    stable_count = 0
        
        print("崩壊シミュレーション完了")
        
        # 最終状態の分析
        self.analyze_final_state()
    
    def calculate_total_kinetic_energy(self) -> float:
        """総運動エネルギーの計算"""
        total_energy = 0
        for debris in self.debris_objects:
            velocity, angular_velocity = p.getBaseVelocity(debris.body_id)
            linear_energy = 0.5 * debris.mass * np.linalg.norm(velocity)**2
            # 簡略化のため回転エネルギーは省略
            total_energy += linear_energy
        return total_energy
    
    def check_stability(self) -> bool:
        """安定性チェック"""
        for debris in self.debris_objects:
            velocity, _ = p.getBaseVelocity(debris.body_id)
            if np.linalg.norm(velocity) > STABILITY_THRESHOLD:
                return False
        return True
    
    def analyze_final_state(self):
        """最終状態の分析（生存空間の検出など）"""
        print("\n最終状態の分析...")
        
        # 瓦礫の高さ分布を計算
        heights = []
        for debris in self.debris_objects:
            pos, _ = p.getBasePositionAndOrientation(debris.body_id)
            heights.append(pos[2])
        
        print(f"瓦礫の高さ範囲: {min(heights):.2f}m 〜 {max(heights):.2f}m")
        print(f"平均高さ: {np.mean(heights):.2f}m")
        
        # 潜在的な生存空間の検出（簡易版）
        self.detect_void_spaces()
    
    def detect_void_spaces(self):
        """生存空間（void space）の簡易検出"""
        print("\n潜在的な生存空間を検出中...")
        
        # グリッドベースの空間チェック
        grid_size = 0.5  # グリッドサイズ（メートル）
        x_range = np.arange(-COLLAPSE_AREA_SIZE[0]/2, COLLAPSE_AREA_SIZE[0]/2, grid_size)
        y_range = np.arange(-COLLAPSE_AREA_SIZE[1]/2, COLLAPSE_AREA_SIZE[1]/2, grid_size)
        z_range = np.arange(0, 3.0, grid_size)
        
        void_count = 0
        for x in x_range:
            for y in y_range:
                for z in z_range:
                    # レイキャストで空間をチェック
                    if self.check_void_at_position((x, y, z), grid_size):
                        void_count += 1
                        self.void_spaces.append((x, y, z))
        
        print(f"検出された潜在的空間: {void_count} グリッド")
        print(f"推定空間体積: {void_count * grid_size**3:.2f} m³")
    
    def check_void_at_position(self, position: Tuple[float, float, float], size: float) -> bool:
        """指定位置に空間があるかチェック"""
        # 6方向にレイキャストして障害物を確認
        directions = [
            (1, 0, 0), (-1, 0, 0),
            (0, 1, 0), (0, -1, 0),
            (0, 0, 1), (0, 0, -1)
        ]
        
        clear_count = 0
        for direction in directions:
            ray_from = position
            ray_to = tuple(position[i] + direction[i] * size for i in range(3))
            result = p.rayTest(ray_from, ray_to)
            
            if result[0][0] == -1:  # 障害物なし
                clear_count += 1
        
        # 半分以上の方向が開いていれば空間とみなす
        return clear_count >= 3
    
    def extract_meshes(self):
        """メッシュデータの抽出"""
        print("\nメッシュデータを抽出中...")
        
        for debris in self.debris_objects:
            pos, orn = p.getBasePositionAndOrientation(debris.body_id)
            visual_data = p.getVisualShapeData(debris.body_id)
            
            for visual in visual_data:
                geom_type = visual[2]
                dimensions = visual[3]
                
                if geom_type == p.GEOM_BOX:
                    box = trimesh.creation.box(extents=[
                        dimensions[0] * 2,
                        dimensions[1] * 2,
                        dimensions[2] * 2
                    ])
                    
                    transform_matrix = np.eye(4)
                    transform_matrix[:3, :3] = np.array(p.getMatrixFromQuaternion(orn)).reshape(3, 3)
                    transform_matrix[:3, 3] = pos
                    
                    box.apply_transform(transform_matrix)
                    self.meshes.append(box)
                    
                elif geom_type == p.GEOM_SPHERE:
                    sphere = trimesh.creation.icosphere(subdivisions=2, radius=dimensions[0])
                    sphere.apply_translation(pos)
                    self.meshes.append(sphere)
        
        print(f"  {len(self.meshes)} 個のメッシュを抽出しました")
    
    def export_to_stl(self, filename: str):
        """STLファイルとしてエクスポート"""
        print(f"\nSTLファイルをエクスポート中: {filename}")
        
        if not self.meshes:
            print("エクスポートするメッシュがありません")
            return
        
        combined_mesh = trimesh.util.concatenate(self.meshes)
        combined_mesh.export(filename)
        
        print(f"エクスポート完了:")
        print(f"  頂点数: {len(combined_mesh.vertices)}")
        print(f"  面数: {len(combined_mesh.faces)}")
        print(f"  バウンディングボックス: {combined_mesh.bounds}")
        print(f"  体積: {combined_mesh.volume:.2f} m³")
    
    def cleanup(self):
        """リソースのクリーンアップ"""
        if self.client is not None:
            p.disconnect()
    
    def run(self, output_filename: str = OUTPUT_FILENAME, use_gui: bool = False):
        """
        災害瓦礫生成の実行
        """
        try:
            self.setup_environment(use_gui=use_gui)
            self.generate_disaster_debris()
            self.run_simulation()
            self.extract_meshes()
            self.export_to_stl(output_filename)
        finally:
            self.cleanup()


def generate_disaster_scenarios(num_scenarios: int = 5, base_filename: str = "disaster_debris"):
    """
    複数の災害シナリオを生成
    
    Args:
        num_scenarios: 生成するシナリオ数
        base_filename: ベースファイル名
    """
    print(f"\n{num_scenarios} 個の災害瓦礫シナリオを生成します\n")
    
    for i in range(num_scenarios):
        print(f"="*60)
        print(f"災害シナリオ {i+1}/{num_scenarios}")
        print(f"="*60)
        
        filename = f"{base_filename}_{i+1:02d}.stl"
        generator = DisasterDebrisGenerator()
        generator.run(output_filename=filename, use_gui=False)
        
        print(f"\n完了: {filename}")
        print(f"推定生存空間: {len(generator.void_spaces)} グリッド\n")


if __name__ == "__main__":
    # 単一シナリオの生成（GUI表示可能）
    # generator = DisasterDebrisGenerator()
    # generator.run(use_gui=True)  # GUIで確認する場合
    
    # 複数シナリオの生成
    generate_disaster_scenarios(num_scenarios=5, base_filename="disaster_debris")