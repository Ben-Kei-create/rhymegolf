extends Node
## ゲーム画面（Phase 1 縦切り）: お題 → 回答 → 計算された yd → 3Dショット → 次のお題。
## 採点・ルールは GameManager に任せ、ここは表示と入力だけ。距離を一切変更しない。

const S := GameStateMachine.S
const FONT_PATH := "res://assets/fonts/DelaGothicOne-Regular.ttf"
const MARGIN := 40  # 横画面のノッチ/角丸を避ける左右余白（暫定。実機で調整）
const IME_SUBMIT_GUARD_MS := 150

const MIDNIGHT := Color("241637")
const GRAPE := Color("7440d9")
const YELLOW := Color("ffd93b")
const MINT := Color("8fe2b5")
const PINK := Color("f879c9")
const PAPER := Color("fcf9f4")

var gm: GameManager
var course: CourseView
var busy := false
var _font: Font
var _last_edit_ms := 0
var _giveup_armed := false

var ui: Control
var hud_hole: Label
var hud_remaining: Label
var hud_strokes: Label
var topic_label: Label
var reading_label: Label
var input: LineEdit
var shot_button: Button
var giveup_button: Button
var msg_label: Label
var banner: PanelContainer
var banner_title: Label
var banner_detail: Label
var banner_big: Label
var banner_result: Label
var end_overlay: Control
var end_title: Label
var end_detail: Label


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	gm = GameManager.new()
	var seed_arg := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_arg = int(a.substr(7))
	if not gm.setup(seed_arg):
		push_error("GameManager setup failed")
		return
	print("session seed=%d scoring=%s lexicon=%s" % [gm.deck.seed_value, gm.scorer.version(), gm.lexicon.lexicon_version])
	gm.start_hole(0)
	course = CourseView.new()
	course.setup(gm.rules.hole)
	add_child(course)
	_build_ui()
	_refresh_hole()
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay()


# ---------------- 進行 ----------------
func _refresh_hole() -> void:
	end_overlay.visible = false
	course.place_ball(gm.rules.ball_s, gm.rules.direction())
	hud_hole.text = "HOLE %02d   PAR %d" % [gm.hole_index + 1, gm.rules.par()]
	_update_hud()
	banner.visible = false
	_show_prompt()
	_set_input_enabled(true)


func _show_prompt() -> void:
	topic_label.text = "「%s」" % gm.prompt["surface"]
	reading_label.text = gm.prompt["reading_hira"]
	msg_label.text = ""
	topic_label.modulate.a = 0.0
	create_tween().tween_property(topic_label, "modulate:a", 1.0, 0.25)


func _update_hud() -> void:
	hud_remaining.text = "残り %.1f yd" % gm.rules.remaining_yd()
	hud_strokes.text = "打数 %d" % gm.rules.stroke_count


func _set_input_enabled(on: bool) -> void:
	input.editable = on
	shot_button.disabled = not on
	giveup_button.disabled = not on
	if on:
		input.clear()
		input.grab_focus()


## IME変換確定の Enter をショット確定と誤認しない（実機テスト必須: 設計書 7 / G07）
func _on_text_submitted(_t: String) -> void:
	if input.has_method("has_ime_text") and input.call("has_ime_text"):
		return
	if Time.get_ticks_msec() - _last_edit_ms < IME_SUBMIT_GUARD_MS:
		return
	_on_shot()


func _on_shot() -> void:
	if busy:
		return
	var res := gm.submit(input.text)
	if not res["ok"]:
		if res["reason"] != "busy":
			_show_msg(res["message"])
		return
	busy = true
	_set_input_enabled(false)
	msg_label.text = ""
	var rec: Dictionary = res["record"]
	_show_rhyme_banner(rec)
	# 採点は確定済み。以降は演出のみで、距離・打数は変えない。
	gm.begin_swing()
	await course.swing()
	gm.begin_flight()
	await course.fly(rec)
	gm.land()
	_update_hud()
	_show_outcome(rec)
	await course.resolve_visual(rec)
	var nxt := gm.after_landing()
	if nxt == "penalty":
		await get_tree().create_timer(0.5).timeout
		nxt = gm.after_penalty()
	await get_tree().create_timer(1.1).timeout
	banner.visible = false
	if nxt == "hole_result":
		_show_end()
	else:
		_show_prompt()
		_set_input_enabled(true)
	busy = false


func _on_giveup() -> void:
	if busy:
		return
	if not _giveup_armed:
		_giveup_armed = true
		giveup_button.text = "本当にギブアップ？"
		get_tree().create_timer(3.0).timeout.connect(_disarm_giveup)
		return
	_disarm_giveup()
	if gm.give_up():
		_update_hud()
		_show_end()


func _disarm_giveup() -> void:
	_giveup_armed = false
	giveup_button.text = "ギブアップ"


func _show_end() -> void:
	_set_input_enabled(false)
	end_title.text = gm.rules.score_label()
	end_detail.text = "%d 打  (PAR %d)" % [gm.rules.stroke_count, gm.rules.par()]
	end_overlay.visible = true


func _on_again() -> void:
	if gm.next_after_result():
		gm.start_hole(gm.hole_index + 1)
	else:
		gm.retry_round()
	_refresh_hole()


# ---------------- 表示文言 ----------------
static func stars(ratio: float) -> String:
	var n := clampi(int(round(ratio * 5.0)), 0, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


static func rating(y: float) -> String:
	if y <= 0.0:
		return "空振り…"
	if y < 5.0:
		return "ちょこん"
	if y < 40.0:
		return "NICE"
	if y < 120.0:
		return "GOOD RHYME!"
	if y < 250.0:
		return "NICE RHYME!"
	return "PERFECT RHYME!!"


func _show_rhyme_banner(rec: Dictionary) -> void:
	var ev: Dictionary = rec["evaluation"]
	var y: float = rec["yards"]
	banner_title.text = rating(y)
	if rec["remaining_before"] <= 5.0 and y >= 100.0:
		banner_title.text = "残り%.0fydでこの飛距離!?" % rec["remaining_before"]
	var extra := ""
	if ev["homophone"]:
		extra += "\n同音異義語 ×0.25"
	if ev["reused"]:
		extra += "\n使い回し ×0.5"
	banner_detail.text = "%s → %s\n韻の一致 %s\n意外性   %s%s" % [
		rec["prompt_surface"], rec["answer_surface"], stars(ev["phonetic"]), stars(ev["surprise"]), extra]
	banner_big.text = ("%.1f yd!!" if y >= 100.0 else "%.1f yd!") % y
	banner_result.text = ""
	banner.visible = true
	banner.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_outcome(rec: Dictionary) -> void:
	match int(rec["outcome"]):
		GolfRules.Outcome.CUP_IN:
			banner_result.text = "CUP IN!!"
		GolfRules.Outcome.OB:
			banner_result.text = "やりすぎ！OB!!  +1罰打"
		GolfRules.Outcome.WATER:
			banner_result.text = "池ポチャ!!  +1罰打"
		GolfRules.Outcome.WHIFF:
			banner_result.text = "ボールは動かない…"
		GolfRules.Outcome.BUNKER:
			banner_result.text = "バンカー！  残り %.1f yd" % rec["remaining_after"]
		_:
			if rec["overshot"]:
				banner_result.text = "オーバー！  残り %.1f yd" % rec["remaining_after"]
			else:
				banner_result.text = "残り %.1f yd" % rec["remaining_after"]


func _show_msg(t: String) -> void:
	msg_label.text = t
	var tw := create_tween()
	tw.tween_property(msg_label, "modulate", PINK, 0.1)
	tw.tween_property(msg_label, "modulate", YELLOW, 0.4)


# ---------------- UI 構築 ----------------
func _box(c: Color, radius := 18, border := 0, border_c := PAPER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_c
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _label(text: String, size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", MIDNIGHT)
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _yellow_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", MIDNIGHT)
	b.add_theme_color_override("font_disabled_color", Color(MIDNIGHT, 0.5))
	b.add_theme_stylebox_override("normal", _box(YELLOW, 30))
	b.add_theme_stylebox_override("hover", _box(YELLOW.lightened(0.15), 30))
	b.add_theme_stylebox_override("pressed", _box(YELLOW.darkened(0.15), 30))
	b.add_theme_stylebox_override("disabled", _box(Color(YELLOW, 0.5), 30))
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = _font
	th.default_font_size = 26
	ui.theme = th
	layer.add_child(ui)

	var hud_l := PanelContainer.new()
	hud_l.add_theme_stylebox_override("panel", _box(Color(MIDNIGHT, 0.85), 14))
	hud_l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_l.offset_left = MARGIN
	hud_l.offset_top = 16
	hud_hole = _label("", 26, PAPER)
	hud_l.add_child(hud_hole)
	ui.add_child(hud_l)

	var hud_r := PanelContainer.new()
	hud_r.add_theme_stylebox_override("panel", _box(Color(MIDNIGHT, 0.85), 14))
	hud_r.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_r.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_r.offset_right = -MARGIN
	hud_r.offset_top = 16
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	hud_remaining = _label("", 26, YELLOW)
	hud_strokes = _label("", 26, PAPER)
	hb.add_child(hud_remaining)
	hb.add_child(hud_strokes)
	hud_r.add_child(hb)
	ui.add_child(hud_r)

	# 右パネル: お題・入力・ショット（iOS 横画面のキーボードで隠れないよう上寄せ）
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(GRAPE, 0.92), 24, 4, YELLOW))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -MARGIN
	panel.offset_top = 84
	panel.custom_minimum_size = Vector2(420, 0)
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("今回のお題は…", 22, PAPER))
	topic_label = _label("", 60, YELLOW, 10)
	vb.add_child(topic_label)
	reading_label = _label("", 20, Color(1, 1, 1, 0.75))
	vb.add_child(reading_label)
	vb.add_child(_label("この単語で韻を踏め！", 22, PAPER))
	input = LineEdit.new()
	input.placeholder_text = "言葉を入力"
	input.max_length = LexiconRepository.MAX_INPUT_CHARS
	input.add_theme_font_size_override("font_size", 34)
	input.add_theme_color_override("font_color", MIDNIGHT)
	input.add_theme_color_override("caret_color", GRAPE)
	input.add_theme_stylebox_override("normal", _box(PAPER, 30))
	input.add_theme_stylebox_override("focus", _box(PAPER, 30, 4, MINT))
	input.add_theme_stylebox_override("read_only", _box(Color(PAPER, 0.6), 30))
	input.text_changed.connect(func(_t: String): _last_edit_ms = Time.get_ticks_msec())
	input.text_submitted.connect(_on_text_submitted)
	vb.add_child(input)
	shot_button = _yellow_button("ショット！▶", 34)
	shot_button.pressed.connect(_on_shot)
	vb.add_child(shot_button)
	msg_label = _label("", 20, YELLOW)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(380, 0)
	vb.add_child(msg_label)
	giveup_button = Button.new()
	giveup_button.text = "ギブアップ"
	giveup_button.flat = true
	giveup_button.add_theme_font_size_override("font_size", 18)
	giveup_button.add_theme_color_override("font_color", Color(PAPER, 0.7))
	giveup_button.pressed.connect(_on_giveup)
	vb.add_child(giveup_button)

	# 結果バナー（左中央）
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _box(Color(MIDNIGHT, 0.82), 26, 4, PINK))
	banner.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	banner.offset_left = MARGIN
	banner.offset_top = -170
	banner.custom_minimum_size = Vector2(440, 0)
	banner.pivot_offset = Vector2(0, 170)
	ui.add_child(banner)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	banner.add_child(bv)
	banner_title = _label("", 38, MINT, 8)
	banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_detail = _label("", 24, PAPER)
	banner_big = _label("", 64, YELLOW, 12)
	banner_result = _label("", 32, PINK, 8)
	banner_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [banner_title, banner_detail, banner_big, banner_result]:
		bv.add_child(l)

	# ホール結果
	end_overlay = Control.new()
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(GRAPE, 30, 6, YELLOW))
	center.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	cv.add_child(_label("HOLE OUT", 28, MINT))
	end_title = _label("", 80, YELLOW, 12)
	cv.add_child(end_title)
	end_detail = _label("", 34, PAPER)
	cv.add_child(end_detail)
	var again := _yellow_button("もう一度 ▶", 34)
	again.pressed.connect(_on_again)
	cv.add_child(again)
	end_overlay.visible = false
	ui.add_child(end_overlay)


# ---------------- 自動プレイ（ヘッドレス e2e 検証）----------------
## godot --headless --path . -- --autoplay [--seed=N]
## 毎ターン、カップに最も近く着地する回答（OB/池は避ける）を辞書から選んで1ホール通す。
func _autoplay() -> void:
	Engine.time_scale = 6.0
	await get_tree().process_frame
	var turn := 0
	while not gm.rules.finished and turn < 40:
		turn += 1
		var best := ""
		var best_gap := INF
		for id in gm.lexicon.entries:
			var e: Dictionary = gm.lexicon.entries[id]
			if e["entry_id"] == gm.prompt["entry_id"] or gm.used_answer_ids.has(id):
				continue
			var y: float = gm.scorer.evaluate(gm.prompt, e)["shot_yards"]
			if y <= 0.0:
				continue
			var pv := gm.rules.preview(y)
			if pv["outcome"] in [GolfRules.Outcome.OB, GolfRules.Outcome.WATER]:
				continue
			var gap := absf(pv["landing_s"] - gm.rules.cup_s())
			if gap < best_gap:
				best_gap = gap
				best = e["surface"]
		var prompt_surface: String = gm.prompt["surface"]
		input.text = best
		await _on_shot()
		var last: Dictionary = gm.last_record
		print("SHOT %d: %s -> %s  %.1fyd  outcome=%d  remaining=%.1f  strokes=%d" % [
			turn, prompt_surface, best, last["yards"], last["outcome"], last["remaining_after"], last["stroke_count"]])
	print("AUTOPLAY DONE: %s (%d strokes) state=%s" % [gm.rules.score_label(), gm.rules.stroke_count, gm.sm.name_of(gm.sm.state)])
	get_tree().quit(0 if gm.rules.finished else 1)
