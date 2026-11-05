class_name CourseMapper
extends RefCounted
## ゲーム論理座標 s(yd) と 3D 座標の対応（設計書 4.4 / 6.1）。ロジックは必ず yd で扱う。
## Phase 1 は直線コース（+Z 方向）。曲線コースは Curve3D の sample_baked で置換予定。

var units_per_yd: float


func _init(hole_def: Dictionary) -> void:
	units_per_yd = float(hole_def["course_units_per_yd"])


func s_to_z(s: float) -> float:
	return s * units_per_yd


func s_to_pos(s: float, y: float = 0.0) -> Vector3:
	return Vector3(0.0, y, s_to_z(s))


func units(yd: float) -> float:
	return yd * units_per_yd


## 演出用の弾道高さ（3D unit）。設計書 6.1: min(12.0, 1.0 + yards / 22.0)。0〜5ydは低い転がり。
static func arc_height(yards: float) -> float:
	if yards <= 5.0:
		return 0.15 * yards / 5.0
	return minf(12.0, 1.0 + yards / 22.0)


## 演出時間 約0.5〜2.5秒
static func flight_seconds(yards: float) -> float:
	return clampf(0.5 + yards / 180.0, 0.5, 2.5)
