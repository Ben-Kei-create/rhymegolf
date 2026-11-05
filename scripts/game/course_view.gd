class_name CourseView
extends Node3D
## 仮の3Dコースとボール・ゴルファーの演出。物理演算は使わず、確定した距離をアニメーションで再現するだけ。
## 座標: +Z がホール進行方向（1ユニット = 1yd）。ボール/ゴルファーはHoleStateのposition_ydに対応。

signal shot_animation_finished(rec: Dictionary)

const BALL_RADIUS := 0.7
const CAM_BACK := 15.0
const CAM_HEIGHT := 5.5
const CAM_LOOK_AHEAD := 20.0
const SWING_BACK_DEG := 140.0
const SWING_THROUGH_DEG := -105.0
const FONT_PATH := "res://assets/fonts/DelaGothicOne-Regular.ttf"

var total_yd: int = HoleState.TOTAL_YD
var ob_margin_yd: int = HoleState.OB_MARGIN_YD

var ball: MeshInstance3D
var cam: Camera3D
var golfer: Node3D
var club_pivot: Node3D
var flag: Node3D

var _dir := 1
var _cam_target_z := 0.0
var _following := false
var _font: Font


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_environment()
	_build_course()
	_build_golfer()
	_build_ball()
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 1500.0
	cam.current = true
	add_child(cam)
	place_ball(0, 1)
	_snap_camera()


func _process(delta: float) -> void:
	var rate := 6.0 if _following else 3.0
	var cz := cam.position.z
	var target_z := _cam_target_z - _dir * CAM_BACK
	cam.position = Vector3(0.0, CAM_HEIGHT, lerpf(cz, target_z, 1.0 - exp(-rate * delta)))
	cam.look_at(Vector3(0.0, 1.5, _cam_target_z + _dir * CAM_LOOK_AHEAD), Vector3.UP)


## ボール位置とゴルファーを即座に配置する。
func place_ball(pos_yd: int, dir: int) -> void:
	_dir = dir
	ball.position = Vector3(0.0, BALL_RADIUS, float(pos_yd))
	ball.scale = Vector3.ONE
	ball.visible = true
	golfer.position = Vector3(-1.9, 0.0, float(pos_yd) - dir * 0.2)
	golfer.rotation.y = 0.0 if dir > 0 else PI
	if dir < 0:
		golfer.position.x = 1.9
	_cam_target_z = float(pos_yd)


func _snap_camera() -> void:
	cam.position = Vector3(0.0, CAM_HEIGHT, _cam_target_z - _dir * CAM_BACK)
	cam.look_at(Vector3(0.0, 1.5, _cam_target_z + _dir * CAM_LOOK_AHEAD), Vector3.UP)


## HoleState.apply_shot の戻り値を受け取って演出する。完了で shot_animation_finished を発火。
func play_shot(rec: Dictionary) -> void:
	var from_z := float(rec["from_yd"])
	var dir: int = rec["direction"]
	var dist: int = rec["distance_yd"]
	var outcome: int = rec["outcome"]
	_dir = dir
	_cam_target_z = from_z
	_following = false

	# 1) スイング
	await _swing()
	if dist <= 0:
		await _whiff_wobble()
		shot_animation_finished.emit(rec)
		return

	# 2) 打ち出し〜着地
	var land_z := from_z + dir * float(dist)
	if outcome == HoleState.Outcome.CUP_IN:
		land_z = float(total_yd)
	_following = true
	await _fly(from_z, land_z, dist)
	_following = false

	# 3) 結果ごとの後処理
	match outcome:
		HoleState.Outcome.CUP_IN:
			await _cup_in()
		HoleState.Outcome.OB:
			await _ob_return(land_z, from_z)
		_:
			_cam_target_z = float(rec["to_yd"])
	# ゴルファーを次のボール位置へ
	var next_dir: int = 1 if rec["to_yd"] <= total_yd else -1
	if outcome != HoleState.Outcome.CUP_IN:
		place_ball(rec["to_yd"], next_dir)
	shot_animation_finished.emit(rec)


# ---- 演出パーツ ----
func _swing() -> void:
	var t := create_tween()
	t.tween_property(club_pivot, "rotation_degrees:x", SWING_BACK_DEG, 0.45).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_property(club_pivot, "rotation_degrees:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished  # この時点がインパクト（club = 真下）
	var t2 := create_tween()
	t2.tween_property(club_pivot, "rotation_degrees:x", SWING_THROUGH_DEG, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# フォロースルーはボール発射と並行して進める（awaitしない）
	t2.finished.connect(func(): _reset_club_later())


func _reset_club_later() -> void:
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(club_pivot, "rotation_degrees:x", 0.0, 0.3)


func _whiff_wobble() -> void:
	var t := create_tween()
	t.tween_property(ball, "rotation_degrees:z", 12.0, 0.08)
	t.tween_property(ball, "rotation_degrees:z", -12.0, 0.12)
	t.tween_property(ball, "rotation_degrees:z", 0.0, 0.08)
	await t.finished
	await get_tree().create_timer(0.4).timeout


func _fly(from_z: float, to_z: float, dist: int) -> void:
	var dur := clampf(0.9 + float(dist) / 140.0, 0.9, 3.4)
	var apex := clampf(float(dist) * 0.2, 1.2, 55.0)
	var tw := create_tween()
	tw.tween_method(_fly_step.bind(from_z, to_z, apex), 0.0, 1.0, dur)
	await tw.finished
	_dust(Vector3(0.0, 0.2, to_z))


func _fly_step(u: float, from_z: float, to_z: float, apex: float) -> void:
	var z := lerpf(from_z, to_z, u)
	ball.position = Vector3(0.0, BALL_RADIUS + apex * 4.0 * u * (1.0 - u), z)
	ball.rotation.x += 0.35
	_cam_target_z = z


func _hop_step(u: float, start: Vector3, end: Vector3) -> void:
	ball.position = start.lerp(end, u) + Vector3(0.0, 12.0 * 4.0 * u * (1.0 - u), 0.0)


func _cup_in() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * 0.05, 0.35)
	t.tween_property(ball, "position:y", -0.4, 0.35)
	var fl := create_tween()
	fl.tween_property(flag, "rotation_degrees:y", 25.0, 0.1)
	fl.tween_property(flag, "rotation_degrees:y", -25.0, 0.2)
	fl.tween_property(flag, "rotation_degrees:y", 0.0, 0.1)
	await t.finished
	ball.visible = false
	await get_tree().create_timer(0.3).timeout


func _ob_return(from_land_z: float, back_z: float) -> void:
	await get_tree().create_timer(0.7).timeout
	_cam_target_z = back_z
	var t := create_tween()
	t.tween_method(_hop_step.bind(Vector3(0.0, BALL_RADIUS, from_land_z), Vector3(0.0, BALL_RADIUS, back_z)), 0.0, 1.0, 0.9)
	await t.finished


func _dust(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -14, 0)
	var m := SphereMesh.new()
	m.radius = 0.25
	m.height = 0.5
	m.material = _mat(Color(0.95, 0.9, 0.7))
	p.mesh = m
	p.position = pos
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# ---- シーン構築 ----
func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, c: Color, parent: Node3D, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.55, 0.95)
	sky_mat.sky_horizon_color = Color(0.75, 0.9, 1.0)
	sky_mat.ground_horizon_color = Color(0.7, 0.88, 0.8)
	sky_mat.ground_bottom_color = Color(0.4, 0.65, 0.45)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.92, 1.0)
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)


func _build_course() -> void:
	var len_total := float(total_yd) + 220.0
	var z0 := -60.0
	var zc := z0 + len_total / 2.0
	# ラフ
	var rough := BoxMesh.new()
	rough.size = Vector3(400.0, 0.1, len_total)
	_mesh(rough, Color(0.36, 0.62, 0.30), self, Vector3(0, -0.1, zc))
	# フェアウェイ
	var fw := BoxMesh.new()
	fw.size = Vector3(34.0, 0.12, len_total - 70.0)
	_mesh(fw, Color(0.52, 0.8, 0.34), self, Vector3(0, -0.02, z0 + (len_total - 70.0) / 2.0 + 10.0))
	# ティーイング
	var tee := BoxMesh.new()
	tee.size = Vector3(10.0, 0.18, 14.0)
	_mesh(tee, Color(0.62, 0.88, 0.42), self, Vector3(0, 0.0, -2.0))
	# グリーン
	var green := CylinderMesh.new()
	green.top_radius = 15.0
	green.bottom_radius = 15.0
	green.height = 0.2
	_mesh(green, Color(0.66, 0.92, 0.45), self, Vector3(0, 0.02, float(total_yd)))
	# カップ
	var cup := CylinderMesh.new()
	cup.top_radius = 1.0
	cup.bottom_radius = 1.0
	cup.height = 0.25
	_mesh(cup, Color(0.05, 0.05, 0.08), self, Vector3(0, 0.13, float(total_yd)))
	# 旗
	flag = Node3D.new()
	flag.position = Vector3(0, 0, float(total_yd))
	add_child(flag)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.12
	pole.height = 16.0
	_mesh(pole, Color(0.95, 0.95, 0.95), flag, Vector3(0, 8.0, 0))
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.1, 3.2, 5.0)
	_mesh(cloth, Color(1.0, 0.82, 0.12), flag, Vector3(0, 14.2, 2.6))
	# OBゾーン（カップ+OB_MARGIN より先）と白杭
	var ob_z := float(total_yd + ob_margin_yd)
	var ob := BoxMesh.new()
	ob.size = Vector3(400.0, 0.14, 120.0)
	_mesh(ob, Color(0.45, 0.3, 0.2), self, Vector3(0, -0.01, ob_z + 60.0))
	var line := BoxMesh.new()
	line.size = Vector3(60.0, 0.2, 0.8)
	_mesh(line, Color(1, 1, 1), self, Vector3(0, 0.1, ob_z))
	for sx in [-30.0, 30.0]:
		var stake := CylinderMesh.new()
		stake.top_radius = 0.25
		stake.bottom_radius = 0.25
		stake.height = 3.0
		_mesh(stake, Color(1, 1, 1), self, Vector3(sx, 1.5, ob_z))
	_label3d("OB", Vector3(0, 6.0, ob_z), 14.0, Color(1, 0.3, 0.3))
	# 距離表示
	for d in [100, 200, 300]:
		var zz := float(total_yd - d)
		var marker := BoxMesh.new()
		marker.size = Vector3(1.2, 0.2, 1.2)
		_mesh(marker, Color(1, 0.82, 0.12), self, Vector3(-17.5, 0.1, zz))
		_label3d("%d" % d, Vector3(-17.5, 3.4, zz), 7.0, Color(1, 1, 1))
	# 木々（固定シードで再現可能）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	var z := -30.0
	while z < float(total_yd) + 90.0:
		for side in [-1.0, 1.0]:
			var x: float = side * rng.randf_range(22.0, 60.0)
			_tree(Vector3(x, 0, z + rng.randf_range(-6.0, 6.0)), rng.randf_range(0.8, 1.6), rng.randi() % 3)
		z += rng.randf_range(12.0, 22.0)


func _tree(pos: Vector3, s: float, kind: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * s
	add_child(root)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.6
	trunk.bottom_radius = 0.8
	trunk.height = 4.0
	_mesh(trunk, Color(0.45, 0.28, 0.18), root, Vector3(0, 2.0, 0))
	var leaf_colors := [Color(1.0, 0.65, 0.8), Color(0.3, 0.65, 0.3), Color(0.62, 0.4, 0.85)]
	var crown := SphereMesh.new()
	crown.radius = 4.2
	crown.height = 7.4
	_mesh(crown, leaf_colors[kind], root, Vector3(0, 7.0, 0))


func _label3d(text: String, pos: Vector3, size: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.pixel_size = size / 64.0 / 2.0
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = pos
	add_child(l)


func _build_ball() -> void:
	var sph := SphereMesh.new()
	sph.radius = BALL_RADIUS
	sph.height = BALL_RADIUS * 2.0
	ball = _mesh(sph, Color(1, 1, 1), self)
	# 紫の王冠マーク代わりのバンド
	var band := TorusMesh.new()
	band.inner_radius = BALL_RADIUS * 0.98
	band.outer_radius = BALL_RADIUS * 1.08
	_mesh(band, Color(0.45, 0.2, 0.8), ball)
	# ティー
	var tee := CylinderMesh.new()
	tee.top_radius = 0.18
	tee.bottom_radius = 0.1
	tee.height = 0.4


func _build_golfer() -> void:
	golfer = Node3D.new()
	add_child(golfer)
	var purple := Color(0.4, 0.17, 0.65)
	var dark := Color(0.12, 0.1, 0.15)
	var skin := Color(1.0, 0.78, 0.62)
	var gold := Color(1.0, 0.82, 0.12)
	# ダボダボのパンツ＋靴
	for lx in [-0.4, 0.4]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.5
		leg.height = 2.0
		_mesh(leg, dark, golfer, Vector3(lx, 1.0, 0))
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.8, 0.4, 1.3)
		_mesh(shoe, Color(0.85, 0.8, 0.95), golfer, Vector3(lx, 0.2, 0.2))
	# ジャケット
	var torso := CapsuleMesh.new()
	torso.radius = 0.85
	torso.height = 2.2
	_mesh(torso, purple, golfer, Vector3(0, 2.5, 0))
	# 頭・髪・キャップ・王冠
	var head := SphereMesh.new()
	head.radius = 0.8
	head.height = 1.6
	_mesh(head, skin, golfer, Vector3(0, 4.1, 0))
	var hair := SphereMesh.new()
	hair.radius = 0.88
	hair.height = 1.5
	_mesh(hair, Color(0.93, 0.9, 0.85), golfer, Vector3(0, 4.2, -0.1))
	var cap := SphereMesh.new()
	cap.radius = 0.9
	cap.height = 1.1
	_mesh(cap, dark, golfer, Vector3(0, 4.55, 0.0))
	var brim := BoxMesh.new()
	brim.size = Vector3(1.0, 0.1, 0.8)
	_mesh(brim, dark, golfer, Vector3(0, 4.4, 0.85))
	var crown := BoxMesh.new()
	crown.size = Vector3(0.5, 0.35, 0.1)
	_mesh(crown, gold, golfer, Vector3(0, 4.7, 0.92))
	# ヘッドホン（首）
	var hp := TorusMesh.new()
	hp.inner_radius = 0.55
	hp.outer_radius = 0.85
	_mesh(hp, gold, golfer, Vector3(0, 3.55, 0))
	# 腕＋クラブ（肩を支点に回転）
	club_pivot = Node3D.new()
	club_pivot.position = Vector3(1.0, 3.2, 0)
	golfer.add_child(club_pivot)
	var arm := CapsuleMesh.new()
	arm.radius = 0.28
	arm.height = 1.9
	_mesh(arm, purple, club_pivot, Vector3(0, -0.8, 0))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.07
	shaft.bottom_radius = 0.07
	shaft.height = 3.0
	_mesh(shaft, Color(0.15, 0.15, 0.2), club_pivot, Vector3(0, -1.5, 0))
	var head_c := BoxMesh.new()
	head_c.size = Vector3(0.5, 0.5, 1.1)
	_mesh(head_c, Color(0.1, 0.1, 0.15), club_pivot, Vector3(0, -3.1, 0.35))
