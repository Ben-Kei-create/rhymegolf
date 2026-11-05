class_name CourseView
extends Node3D
## 仮の3Dコース・ボール・ゴルファーと、確定結果の演出（設計書 6.1）。物理演算は使わない。
## TrajectoryPresenter / CameraDirector / CharacterAnimator の役割を Phase 1 では本クラスに同居させる。
## 位置は CourseMapper（1unit = 4yd）経由。演出は確定済みの着地点へ必ず一致させ、距離や打数を変えない。

const BALL_RADIUS := 0.38
const CAM_BACK := 8.0
const CAM_HEIGHT := 3.2
const CAM_LOOK_AHEAD := 14.0
const SWING_BACK_DEG := 140.0
const SWING_THROUGH_DEG := -105.0
const FONT_PATH := "res://assets/fonts/DelaGothicOne-Regular.ttf"

var hole: Dictionary
var mapper: CourseMapper
var ball: MeshInstance3D
var cam: Camera3D
var golfer: Node3D
var club_pivot: Node3D
var flag: Node3D

var _dir := 1
var _cam_target_z := 0.0
var _following := false
var _font: Font


func setup(hole_def: Dictionary) -> void:
	hole = hole_def
	mapper = CourseMapper.new(hole_def)


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_environment()
	_build_course()
	_build_golfer()
	_build_ball()
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 600.0
	cam.current = true
	add_child(cam)
	place_ball(float(hole["start_s"]), 1)
	_snap_camera()


func _process(delta: float) -> void:
	if cam == null:
		return
	var rate := 6.0 if _following else 3.0
	var target_z := _cam_target_z - _dir * CAM_BACK
	cam.position = Vector3(0.0, CAM_HEIGHT, lerpf(cam.position.z, target_z, 1.0 - exp(-rate * delta)))
	cam.look_at(Vector3(0.0, 1.0, _cam_target_z + _dir * CAM_LOOK_AHEAD), Vector3.UP)


func _snap_camera() -> void:
	cam.position = Vector3(0.0, CAM_HEIGHT, _cam_target_z - _dir * CAM_BACK)
	cam.look_at(Vector3(0.0, 1.0, _cam_target_z + _dir * CAM_LOOK_AHEAD), Vector3.UP)


## ボールとゴルファーを s(yd) へ即時配置。dir はカップ方向（+1/-1）
func place_ball(s: float, dir: int) -> void:
	_dir = dir
	ball.position = mapper.s_to_pos(s, BALL_RADIUS)
	ball.scale = Vector3.ONE
	ball.rotation = Vector3.ZERO
	ball.visible = true
	golfer.position = Vector3(-1.05 * dir, 0.0, mapper.s_to_z(s) - dir * 0.1)
	golfer.rotation.y = 0.0 if dir > 0 else PI
	_cam_target_z = mapper.s_to_z(s)
	club_pivot.rotation_degrees.x = 0.0


# ---- 演出（GameManager の状態に合わせて main が順に呼ぶ）----
## インパクトまで。完了時点でクラブは真下（インパクト）。
func swing() -> void:
	_following = false
	var t := create_tween()
	t.tween_property(club_pivot, "rotation_degrees:x", SWING_BACK_DEG, 0.45).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_property(club_pivot, "rotation_degrees:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	var t2 := create_tween()
	t2.tween_property(club_pivot, "rotation_degrees:x", SWING_THROUGH_DEG, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 確定済みの着地点 rec["landing_s"] まで飛ばす。空振りはボールが少し揺れるだけ。
func fly(rec: Dictionary) -> void:
	var yards: float = rec["yards"]
	_dir = rec["direction"]
	if yards <= 0.0:
		var w := create_tween()
		w.tween_property(ball, "rotation_degrees:z", 12.0, 0.08)
		w.tween_property(ball, "rotation_degrees:z", -12.0, 0.12)
		w.tween_property(ball, "rotation_degrees:z", 0.0, 0.08)
		await w.finished
		await get_tree().create_timer(0.3).timeout
		return
	var from_z := mapper.s_to_z(rec["from_s"])
	var to_z := mapper.s_to_z(rec["landing_s"])
	_following = true
	var tw := create_tween()
	tw.tween_method(_fly_step.bind(from_z, to_z, CourseMapper.arc_height(yards)), 0.0, 1.0, CourseMapper.flight_seconds(yards))
	await tw.finished
	ball.position = Vector3(0.0, BALL_RADIUS, to_z)  # 確定着地点へ必ず一致
	_dust(Vector3(0.0, 0.1, to_z))
	_following = false


func _fly_step(u: float, from_z: float, to_z: float, apex: float) -> void:
	ball.position = Vector3(0.0, BALL_RADIUS + apex * 4.0 * u * (1.0 - u), lerpf(from_z, to_z, u))
	ball.rotation.x += 0.35
	_cam_target_z = ball.position.z


## 着地後の見せ場（カップイン / OB・池で元の位置へ戻す）。通常ショットは次のボール位置へ移動。
func resolve_visual(rec: Dictionary) -> void:
	var outcome: int = rec["outcome"]
	match outcome:
		GolfRules.Outcome.CUP_IN:
			var t := create_tween().set_parallel(true)
			t.tween_property(ball, "scale", Vector3.ONE * 0.05, 0.35)
			t.tween_property(ball, "position:y", -0.2, 0.35)
			var fl := create_tween()
			fl.tween_property(flag, "rotation_degrees:y", 25.0, 0.1)
			fl.tween_property(flag, "rotation_degrees:y", -25.0, 0.2)
			fl.tween_property(flag, "rotation_degrees:y", 0.0, 0.1)
			await t.finished
			ball.visible = false
			await get_tree().create_timer(0.3).timeout
		GolfRules.Outcome.OB, GolfRules.Outcome.WATER:
			await get_tree().create_timer(0.6).timeout
			var back := mapper.s_to_z(rec["from_s"])
			_cam_target_z = back
			var start := ball.position
			var end := Vector3(0.0, BALL_RADIUS, back)
			var t2 := create_tween()
			t2.tween_method(_hop_step.bind(start, end), 0.0, 1.0, 0.9)
			await t2.finished
			place_ball(rec["new_ball_s"], rec["direction"])
		_:
			var next_dir := 1 if rec["new_ball_s"] <= float(hole["cup_s"]) else -1
			place_ball(rec["new_ball_s"], next_dir)


func _hop_step(u: float, start: Vector3, end: Vector3) -> void:
	ball.position = start.lerp(end, u) + Vector3(0.0, 3.0 * 4.0 * u * (1.0 - u), 0.0)


func _dust(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9, 0)
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)


func _band(kind_color: Color, from_s: float, to_s: float, width: float, y: float, shape_cyl := false) -> void:
	var z0 := mapper.s_to_z(from_s)
	var z1 := mapper.s_to_z(to_s)
	if shape_cyl:
		var cyl := CylinderMesh.new()
		cyl.top_radius = width * 0.5
		cyl.bottom_radius = width * 0.5
		cyl.height = 0.06
		var mi := _mesh(cyl, kind_color, self, Vector3(0, y, (z0 + z1) * 0.5))
		mi.scale = Vector3(1.0, 1.0, maxf(0.2, (z1 - z0) / width))
	else:
		var box := BoxMesh.new()
		box.size = Vector3(width, 0.06, z1 - z0)
		_mesh(box, kind_color, self, Vector3(0, y, (z0 + z1) * 0.5))


func _build_course() -> void:
	var min_z := mapper.s_to_z(float(hole["min_s"]))
	var max_z := mapper.s_to_z(float(hole["max_s"]))
	var cup_z := mapper.s_to_z(float(hole["cup_s"]))
	var span := max_z - min_z
	# ラフ・フェアウェイ・ティー・グリーン
	var rough := BoxMesh.new()
	rough.size = Vector3(160.0, 0.1, span + 100.0)
	_mesh(rough, Color(0.36, 0.62, 0.30), self, Vector3(0, -0.1, (min_z + max_z) * 0.5))
	_band(Color(0.52, 0.8, 0.34), float(hole["min_s"]), float(hole["max_s"]), 13.0, -0.04)
	_band(Color(0.62, 0.88, 0.42), -20.0, 10.0, 5.0, 0.0)
	var green := CylinderMesh.new()
	green.top_radius = 4.5
	green.bottom_radius = 4.5
	green.height = 0.08
	_mesh(green, Color(0.66, 0.92, 0.45), self, Vector3(0, 0.02, cup_z))
	var cup := CylinderMesh.new()
	cup.top_radius = 0.45
	cup.bottom_radius = 0.45
	cup.height = 0.1
	_mesh(cup, Color(0.05, 0.05, 0.08), self, Vector3(0, 0.07, cup_z))
	# 旗
	flag = Node3D.new()
	flag.position = Vector3(0, 0, cup_z)
	add_child(flag)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 6.0
	_mesh(pole, Color(0.95, 0.95, 0.95), flag, Vector3(0, 3.0, 0))
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.05, 1.3, 2.0)
	_mesh(cloth, Color(1.0, 0.85, 0.23), flag, Vector3(0, 5.3, 1.0))
	# ハザード（設計書 9: hazards）。バンカーは見た目のみ、池は着地でペナルティ
	for h in hole["hazards"]:
		if h["kind"] == "water":
			_band(Color(0.25, 0.6, 0.95), float(h["from_s"]), float(h["to_s"]), 13.0, 0.0)
		else:
			_band(Color(1.0, 0.8, 0.35), float(h["from_s"]), float(h["to_s"]), 7.0, 0.0, true)
	# OBライン（min_s / max_s）と白杭
	for s in [float(hole["min_s"]), float(hole["max_s"])]:
		var z := mapper.s_to_z(s)
		var line := BoxMesh.new()
		line.size = Vector3(26.0, 0.1, 0.25)
		_mesh(line, Color(1, 1, 1), self, Vector3(0, 0.05, z))
		for sx in [-13.0, 13.0]:
			var stake := CylinderMesh.new()
			stake.top_radius = 0.1
			stake.bottom_radius = 0.1
			stake.height = 1.4
			_mesh(stake, Color(1, 1, 1), self, Vector3(sx, 0.7, z))
		_label3d("OB", Vector3(0, 3.0, z), 3.0, Color(1, 0.4, 0.5))
	# 距離表示 100/200/300（カップからの残りではなく tee からの s）
	for d in [100, 200, 300]:
		var zz := mapper.s_to_z(float(d))
		_label3d("%d" % d, Vector3(-7.5, 1.8, zz), 2.2, Color(1, 1, 1))
	# 木々（固定シードで再現可能）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	var z := min_z
	while z < max_z + 20.0:
		for side in [-1.0, 1.0]:
			_tree(Vector3(side * rng.randf_range(9.0, 24.0), 0, z + rng.randf_range(-2.0, 2.0)), rng.randf_range(0.5, 0.9), rng.randi() % 3)
		z += rng.randf_range(4.0, 8.0)


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
	var leaf_colors := [Color("f879c9"), Color(0.3, 0.65, 0.3), Color("7440d9")]
	var crown := SphereMesh.new()
	crown.radius = 3.6
	crown.height = 6.4
	_mesh(crown, leaf_colors[kind], root, Vector3(0, 6.5, 0))


func _label3d(text: String, pos: Vector3, size: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)


func _build_ball() -> void:
	var sph := SphereMesh.new()
	sph.radius = BALL_RADIUS
	sph.height = BALL_RADIUS * 2.0
	ball = _mesh(sph, Color(1, 1, 1), self)
	var band := TorusMesh.new()
	band.inner_radius = BALL_RADIUS * 0.98
	band.outer_radius = BALL_RADIUS * 1.08
	_mesh(band, Color("7440d9"), ball)


func _build_golfer() -> void:
	golfer = Node3D.new()
	golfer.scale = Vector3.ONE * 0.55
	add_child(golfer)
	var grape := Color("7440d9")
	var dark := Color("241637")
	var skin := Color(1.0, 0.78, 0.62)
	var gold := Color("ffd93b")
	for lx in [-0.4, 0.4]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.5
		leg.height = 2.0
		_mesh(leg, dark, golfer, Vector3(lx, 1.0, 0))
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.8, 0.4, 1.3)
		_mesh(shoe, Color("fcf9f4"), golfer, Vector3(lx, 0.2, 0.2))
	var torso := CapsuleMesh.new()
	torso.radius = 0.85
	torso.height = 2.2
	_mesh(torso, grape, golfer, Vector3(0, 2.5, 0))
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
	var hp := TorusMesh.new()
	hp.inner_radius = 0.55
	hp.outer_radius = 0.85
	_mesh(hp, gold, golfer, Vector3(0, 3.55, 0))
	club_pivot = Node3D.new()
	club_pivot.position = Vector3(1.0, 3.2, 0)
	golfer.add_child(club_pivot)
	var arm := CapsuleMesh.new()
	arm.radius = 0.28
	arm.height = 1.9
	_mesh(arm, grape, club_pivot, Vector3(0, -0.8, 0))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.07
	shaft.bottom_radius = 0.07
	shaft.height = 3.0
	_mesh(shaft, dark, club_pivot, Vector3(0, -1.5, 0))
	var head_c := BoxMesh.new()
	head_c.size = Vector3(0.5, 0.5, 1.1)
	_mesh(head_c, dark, club_pivot, Vector3(0, -3.1, 0.35))
