extends RefCounted

func _hole() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/courses_v1.json"))["holes"][0]


func _rules_at(s: float) -> GolfRules:
	var r := GolfRules.new(_hole())
	r.ball_s = s
	return r


func run(t) -> void:
	var O := GolfRules.Outcome
	# 経路: 320yd 地点のカップ。212–230 バンカー、260–280 池、min -25、max 390
	var r := GolfRules.new(_hole())
	var a := r.resolve(174.8)
	t.eq(a["outcome"], O.FAIRWAY, "フェアウェイ")
	t.near(r.ball_s, 174.8, "ball_s 更新")
	t.eq(r.stroke_count, 1, "1打")
	t.near(r.remaining_yd(), 145.2, "残り 145.2yd", 0.0001)
	# G02 カップ0.8yd以内
	var r2 := _rules_at(300.0)
	t.eq(r2.resolve(20.8)["outcome"], O.CUP_IN, "G02 +0.8yd 境界でカップイン")
	t.ok(r2.finished, "終了")
	var r3 := _rules_at(300.0)
	t.eq(r3.resolve(19.2)["outcome"], O.CUP_IN, "G02 -0.8yd 境界でカップイン")
	var r4 := _rules_at(300.0)
	t.eq(r4.resolve(19.1)["outcome"], O.FAIRWAY, "G02 0.9yd 手前は入らない")
	var r5 := _rules_at(300.0)
	t.eq(r5.resolve(20.9)["outcome"], O.FAIRWAY, "G02 0.9yd 奥は入らない")
	# G01 オーバーショット：次は反対方向
	var g1 := _rules_at(317.0)
	var o := g1.resolve(100.0)  # 417 > max_s → OB なので別ケース
	t.eq(o["outcome"], O.OB, "G01 残り3yd で100yd → max_s 超過で OB")
	var g1b := _rules_at(317.0)
	var o2 := g1b.resolve(40.0)  # 357 は範囲内
	t.eq(o2["outcome"], O.FAIRWAY, "G01 オーバーショット（範囲内）")
	t.ok(o2["overshot"], "overshot フラグ")
	t.eq(g1b.direction(), -1, "G01 次はカップ方向が逆")
	var back := g1b.resolve(37.0)
	t.eq(back["outcome"], O.CUP_IN, "G01 戻り方向に打ってカップイン")
	# G03 カップを通過しても遠くに着地すれば入らない
	var g3 := _rules_at(310.0)
	t.eq(g3.resolve(30.0)["outcome"], O.FAIRWAY, "G03 通過しただけでは入らない (340)")
	t.ok(not g3.finished, "G03 未完了")
	# G04 OB / 池
	var ob := _rules_at(100.0)
	var ob_rec := ob.resolve(300.0)  # 400 > 390
	t.eq(ob_rec["outcome"], O.OB, "G04 OB")
	t.eq(ob.stroke_count, 2, "G04 OB = 1打 + 罰打1")
	t.near(ob.ball_s, 100.0, "G04 打つ前の位置に戻る")
	var w := _rules_at(100.0)
	var w_rec := w.resolve(170.0)  # 270 は池
	t.eq(w_rec["outcome"], O.WATER, "G04 池")
	t.eq(w.stroke_count, 2, "G04 池 = 1打 + 罰打1")
	t.near(w.ball_s, 100.0, "G04 池 元の位置")
	var back_ob := _rules_at(0.0)
	t.eq(back_ob.resolve(-0.0)["outcome"], O.WHIFF, "0yd は空振り")
	# min_s 側OB（カップを越えて戻る方向の大振り）
	var mo := _rules_at(350.0)
	t.eq(mo.resolve(400.0)["outcome"], O.OB, "戻り方向の大振り = min_s 外 OB")
	# G05 バンカーはタグのみ（位置・距離は変わらない）
	var b := _rules_at(100.0)
	var br := b.resolve(120.0)  # 220 = バンカー
	t.eq(br["outcome"], O.BUNKER, "G05 バンカータグ")
	t.near(b.ball_s, 220.0, "G05 位置は通常どおり着地")
	t.eq(b.stroke_count, 1, "G05 罰打なし")
	# R16 GolfRules は距離を補正しない: 残り3ydでも 300yd は 300yd 先へ（OB）
	var c := _rules_at(317.0)
	t.near(c.preview(300.0)["landing_s"], 617.0, "R16 残り3ydでも飛距離300yd（補正なし）")
	t.near(r5.hole["cup_s"], 320.0, "H01 cup_s=320")
	# 打数 15 でピックアップ/ギブアップ
	var cap := GolfRules.new(_hole())
	for i in 20:
		if not cap.finished:
			cap.resolve(0.0)
	t.ok(cap.finished and cap.gave_up, "15打で終了")
	t.eq(cap.stroke_count, 15, "スコアは15")
	var gu := GolfRules.new(_hole())
	gu.give_up()
	t.eq(gu.stroke_count, 15, "ギブアップは15扱い")
	# ラベル
	t.eq(GolfRules.label_for(1, 4), "ホールインワン", "ace")
	t.eq(GolfRules.label_for(2, 4), "イーグル", "eagle")
	t.eq(GolfRules.label_for(3, 4), "バーディ", "birdie")
	t.eq(GolfRules.label_for(4, 4), "パー", "par")
	t.eq(GolfRules.label_for(5, 4), "ボギー", "bogey")
	t.eq(GolfRules.label_for(9, 4), "+5", "+5")
	# 演出ヘルパ（設計書 6.1）
	t.near(CourseMapper.arc_height(220.0), 11.0, "arc_height(220)=1+10=11")
	t.near(CourseMapper.arc_height(360.0), 12.0, "arc_height 上限12")
	t.ok(CourseMapper.arc_height(3.0) < 0.2, "0〜5yd は低い転がり")
	t.ok(CourseMapper.flight_seconds(0.0) >= 0.5 and CourseMapper.flight_seconds(360.0) <= 2.5, "演出 0.5〜2.5秒")
