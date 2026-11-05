extends Node
## RHYME GOLF Phase 0: 1ホールを通しで遊べるメインシーン。
## 流れ: お題表示 → 入力 → 韻から飛距離を計算 → スイング＆ボール演出 → 結果 → 次のお題。
## 飛距離は DistanceCalc.compute(お題, 入力) のみで決まる（クラブ・風・残り距離補正なし）。

const FONT_PATH := "res://assets/fonts/DelaGothicOne-Regular.ttf"
const MARGIN := 40  # 横画面のノッチ/角丸を避ける左右余白（暫定。実機で調整）

const PURPLE := Color("5b2a9e")
const PURPLE_DARK := Color("2a1352")
const YELLOW := Color("ffd21f")
const WHITE := Color("ffffff")
const PINK := Color("ff4fa3")
const CYAN := Color("3fd8ff")

var dict: ReadingDict
var picker: TopicPicker
var hole: HoleState
var topic: Dictionary = {}
var course: CourseView
var hole_no := 0
var busy := false
var _font: Font

# UI
var ui: Control
var hud_hole: Label
var hud_remaining: Label
var hud_strokes: Label
var topic_label: Label
var reading_label: Label
var input: LineEdit
var shot_button: Button
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
	dict = ReadingDict.load_default()
	picker = TopicPicker.new(dict.topics)
	course = CourseView.new()
	add_child(course)
	_build_ui()
	start_hole()
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay()


# ---------------- ホール進行 ----------------
func start_hole() -> void:
	hole_no += 1
	hole = HoleState.new()
	end_overlay.visible = false
	course.place_ball(0, 1)
	hud_hole.text = "HOLE %02d   PAR %d" % [hole_no, hole.par]
	_update_hud()
	_hide_banner()
	_next_topic()
	_set_input_enabled(true)


func _next_topic() -> void:
	topic = picker.next()
	topic_label.text = "「%s」" % topic["word"]
	reading_label.text = topic["reading"]
	msg_label.text = ""
	topic_label.modulate.a = 0.0
	create_tween().tween_property(topic_label, "modulate:a", 1.0, 0.25)


func _update_hud() -> void:
	hud_remaining.text = "残り %d yd" % hole.remaining_yd()
	hud_strokes.text = "打数 %d" % hole.strokes


func _set_input_enabled(on: bool) -> void:
	input.editable = on
	shot_button.disabled = not on
	if on:
		input.clear()
		input.grab_focus()


## 入力欄の内容でショットを打つ。無効入力は打数を消費しない。
func _on_shot() -> void:
	if busy or hole.finished:
		return
	var text := input.text.strip_edges()
	if text.is_empty():
		_show_msg("言葉を入力してね")
		return
	var answer := dict.lookup(text)
	var res := DistanceCalc.compute(topic, answer)
	if not res["valid"]:
		match res["reason"]:
			DistanceCalc.Reason.SAME_WORD:
				_show_msg("お題と同じ言葉はダメ！")
			_:
				_show_msg("「%s」は辞書にないよ。ひらがなで入れてみて" % text)
		return
	if hole.has_used(answer["word"]):
		_show_msg("この言葉はもう使ったよ")
		return
	await _do_shot(answer, res)


func _do_shot(answer: Dictionary, res: Dictionary) -> void:
	busy = true
	_set_input_enabled(false)
	msg_label.text = ""
	var dist: int = res["distance_yd"]
	var rec := hole.apply_shot(answer["word"], dist)
	_show_rhyme_banner(answer, res)
	await course.play_shot(rec)
	_update_hud()
	_show_outcome(rec)
	await get_tree().create_timer(1.5).timeout
	_hide_banner()
	if hole.finished:
		_show_end()
	else:
		_next_topic()
		_set_input_enabled(true)
	busy = false


func _show_end() -> void:
	end_title.text = hole.score_label()
	end_detail.text = "%d 打  (PAR %d)" % [hole.strokes, hole.par]
	end_overlay.visible = true


# ---------------- 表示文言 ----------------
static func stars(n: int) -> String:
	return "★".repeat(clampi(n, 0, 5)) + "☆".repeat(5 - clampi(n, 0, 5))


static func rating(d: int) -> String:
	if d <= 0:
		return "空振り…"
	if d < 20:
		return "ちょこん"
	if d < 80:
		return "NICE"
	if d < 200:
		return "GOOD RHYME!"
	if d < 300:
		return "NICE RHYME!"
	return "PERFECT RHYME!!"


func _show_rhyme_banner(answer: Dictionary, res: Dictionary) -> void:
	banner_title.text = rating(res["distance_yd"])
	banner_detail.text = "%s → %s\n韻の一致 %s\n意外性   %s" % [
		topic["word"], answer["word"], stars(res["stars_match"]), stars(res["stars_surprise"])]
	banner_big.text = "%dyd!" % res["distance_yd"]
	banner_result.text = ""
	banner.modulate.a = 1.0
	banner.visible = true
	banner.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_outcome(rec: Dictionary) -> void:
	var outcome: int = rec["outcome"]
	match outcome:
		HoleState.Outcome.CUP_IN:
			banner_result.text = "CUP IN!!"
		HoleState.Outcome.OVER:
			banner_result.text = "OVER! %dyd オーバー" % rec["overshoot_yd"]
		HoleState.Outcome.OB:
			banner_result.text = "OB! +1打  打ち直し"
		HoleState.Outcome.WHIFF:
			banner_result.text = "ボールは動かない…"
		_:
			banner_result.text = "残り %d yd" % rec["remaining_yd"]


func _hide_banner() -> void:
	banner.visible = false


func _show_msg(t: String) -> void:
	msg_label.text = t
	msg_label.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(msg_label, "modulate", PINK, 0.1)
	tw.tween_property(msg_label, "modulate", YELLOW, 0.4)


# ---------------- UI 構築 ----------------
func _box(c: Color, radius := 18, border := 0, border_c := WHITE) -> StyleBoxFlat:
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
		l.add_theme_color_override("font_outline_color", PURPLE_DARK)
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


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

	# HUD 左上 / 右上
	var hud_l := PanelContainer.new()
	hud_l.add_theme_stylebox_override("panel", _box(Color(PURPLE_DARK, 0.85), 14))
	hud_l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_l.offset_left = MARGIN
	hud_l.offset_top = 16
	hud_hole = _label("HOLE 01   PAR 4", 26, WHITE)
	hud_l.add_child(hud_hole)
	ui.add_child(hud_l)

	var hud_r := PanelContainer.new()
	hud_r.add_theme_stylebox_override("panel", _box(Color(PURPLE_DARK, 0.85), 14))
	hud_r.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_r.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_r.offset_right = -MARGIN
	hud_r.offset_top = 16
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	hud_remaining = _label("残り 380 yd", 26, YELLOW)
	hud_strokes = _label("打数 0", 26, WHITE)
	hb.add_child(hud_remaining)
	hb.add_child(hud_strokes)
	hud_r.add_child(hb)
	ui.add_child(hud_r)

	# 右パネル: お題・入力・ショット（iOSの横画面キーボードで隠れないよう上寄せ）
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(PURPLE, 0.92), 24, 4, YELLOW))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -MARGIN
	panel.offset_top = 84
	panel.custom_minimum_size = Vector2(420, 0)
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("今回のお題は…", 22, WHITE))
	topic_label = _label("「」", 60, YELLOW, 10)
	vb.add_child(topic_label)
	reading_label = _label("", 20, Color(1, 1, 1, 0.75))
	vb.add_child(reading_label)
	vb.add_child(_label("この単語で韻を踏め！", 22, WHITE))
	input = LineEdit.new()
	input.placeholder_text = "言葉を入力"
	input.max_length = 20
	input.add_theme_font_size_override("font_size", 34)
	input.add_theme_color_override("font_color", PURPLE_DARK)
	input.add_theme_color_override("caret_color", PURPLE)
	input.add_theme_stylebox_override("normal", _box(WHITE, 30))
	input.add_theme_stylebox_override("focus", _box(WHITE, 30, 4, CYAN))
	input.add_theme_stylebox_override("read_only", _box(Color(1, 1, 1, 0.6), 30))
	input.text_submitted.connect(func(_t: String): _on_shot())
	vb.add_child(input)
	shot_button = Button.new()
	shot_button.text = "ショット！▶"
	shot_button.add_theme_font_size_override("font_size", 34)
	shot_button.add_theme_color_override("font_color", PURPLE_DARK)
	shot_button.add_theme_color_override("font_disabled_color", Color(PURPLE_DARK, 0.5))
	shot_button.add_theme_stylebox_override("normal", _box(YELLOW, 30, 0))
	shot_button.add_theme_stylebox_override("hover", _box(YELLOW.lightened(0.15), 30))
	shot_button.add_theme_stylebox_override("pressed", _box(YELLOW.darkened(0.15), 30))
	shot_button.add_theme_stylebox_override("disabled", _box(Color(YELLOW, 0.5), 30))
	shot_button.pressed.connect(_on_shot)
	vb.add_child(shot_button)
	msg_label = _label("", 20, YELLOW)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(380, 0)
	vb.add_child(msg_label)

	# 結果バナー（左中央）
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _box(Color(PURPLE_DARK, 0.82), 26, 4, PINK))
	banner.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	banner.offset_left = MARGIN
	banner.offset_top = -170
	banner.custom_minimum_size = Vector2(420, 0)
	banner.pivot_offset = Vector2(0, 170)
	ui.add_child(banner)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	banner.add_child(bv)
	banner_title = _label("", 40, CYAN, 8)
	banner_detail = _label("", 24, WHITE)
	banner_big = _label("", 76, YELLOW, 12)
	banner_result = _label("", 34, PINK, 8)
	for l in [banner_title, banner_detail, banner_big, banner_result]:
		bv.add_child(l)

	# ホール終了オーバーレイ
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
	card.add_theme_stylebox_override("panel", _box(PURPLE, 30, 6, YELLOW))
	center.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	cv.add_child(_label("HOLE OUT", 28, CYAN))
	end_title = _label("", 80, YELLOW, 12)
	cv.add_child(end_title)
	end_detail = _label("", 34, WHITE)
	cv.add_child(end_detail)
	var again := Button.new()
	again.text = "もう一度 ▶"
	again.add_theme_font_size_override("font_size", 34)
	again.add_theme_color_override("font_color", PURPLE_DARK)
	again.add_theme_stylebox_override("normal", _box(YELLOW, 30))
	again.add_theme_stylebox_override("hover", _box(YELLOW.lightened(0.15), 30))
	again.add_theme_stylebox_override("pressed", _box(YELLOW.darkened(0.15), 30))
	again.pressed.connect(start_hole)
	cv.add_child(again)
	end_overlay.visible = false
	ui.add_child(end_overlay)


# ---------------- 自動プレイ（ヘッドレス e2e 検証用）----------------
## godot --headless --path . -- --autoplay
## 毎ターン、辞書から「残り距離に最も近く、超えない」回答を選んで1ホール通す。
func _autoplay() -> void:
	Engine.time_scale = 6.0
	await get_tree().process_frame
	var turn := 0
	while not hole.finished and turn < 40:
		turn += 1
		var remaining := hole.remaining_yd()
		var best_word := ""
		var best_gap := 99999
		for w in dict.entries:
			if hole.has_used(w):
				continue
			var r := DistanceCalc.compute(topic, dict.entries[w])
			if not r["valid"]:
				continue
			var d: int = r["distance_yd"]
			var gap := absi(d - remaining)
			if hole.direction() > 0 and d > remaining + HoleState.CUP_TOLERANCE_YD:
				gap += 1000  # 超過は避ける
			if d > 0 and gap < best_gap:
				best_gap = gap
				best_word = w
		var t_word: String = topic["word"]
		input.text = best_word
		await _on_shot()
		var last: Dictionary = hole.history[-1]
		print("SHOT %d: %s -> %s  %dyd  outcome=%d  remaining=%d  strokes=%d" % [
			turn, t_word, best_word, last["distance_yd"], last["outcome"], last["remaining_yd"], last["strokes"]])
	print("AUTOPLAY DONE: %s (%d strokes)" % [hole.score_label(), hole.strokes])
	get_tree().quit(0 if hole.finished else 1)
