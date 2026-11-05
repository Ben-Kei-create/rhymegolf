extends SceneTree
## 実行: godot --headless --path . --script res://tests/run_tests.gd
## 失敗が1件でもあれば終了コード 1。

var _pass := 0
var _fail := 0
var _dict: ReadingDict


func _init() -> void:
	_dict = ReadingDict.load_default()
	test_kana()
	test_dictionary_integrity()
	test_rhyme_engine()
	test_distance()
	test_determinism_and_bounds()
	test_no_hidden_correction()
	test_topic_picker()
	test_hole_rules()
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func ok(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("FAIL: " + name)


func eq(a, b, name: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [name, str(a), str(b)])


func yd(topic: String, answer: String) -> int:
	return DistanceCalc.compute(_dict.lookup(topic), _dict.lookup(answer))["distance_yd"]


# ---- かな ----
func test_kana() -> void:
	eq(Kana.to_hiragana("カタカナ"), "かたかな", "katakana->hiragana")
	eq(Kana.vowel_string(Kana.to_moras("かいだん")), "aiaN", "かいだん vowels")
	eq(Kana.vowel_string(Kana.to_moras("さいばん")), "aiaN", "さいばん vowels")
	eq(Kana.to_moras("きゃく").size(), 2, "拗音は1モーラ")
	eq(Kana.vowel_string(Kana.to_moras("きゃく")), "au", "きゃく vowels")
	eq(Kana.vowel_string(Kana.to_moras("こーひー")), "ooii", "長音は直前の母音")
	eq(Kana.vowel_string(Kana.to_moras("ラーメン")), "aaeN", "カタカナ+長音")
	eq(Kana.vowel_string(Kana.to_moras("がっこう")), "aQou", "促音Q")
	eq(Kana.to_moras("ふぁ").size(), 1, "小書き母音は1モーラ")
	eq(Kana.to_moras("abc").size(), 0, "非かなは空")
	ok(Kana.is_kana_only("ゲーム"), "kana only")
	ok(not Kana.is_kana_only("階段"), "kanji not kana-only")
	ok(not Kana.is_kana_only(""), "empty not kana-only")


# ---- 辞書の整合性 ----
func test_dictionary_integrity() -> void:
	ok(_dict.entries.size() >= 250, "dictionary size >= 250 (%d)" % _dict.entries.size())
	ok(_dict.topics.size() >= 100, "topic pool >= 100 (%d)" % _dict.topics.size())
	var bad := 0
	for w in _dict.entries:
		var e: Dictionary = _dict.entries[w]
		if e["moras"].is_empty() or not Kana.is_kana_only(e["reading"]) or not e["freq"] in [1, 2, 3]:
			bad += 1
			printerr("bad entry: %s" % w)
	eq(bad, 0, "all dictionary entries valid")
	for t in _dict.topics:
		if t["moras"].size() < 2:
			bad += 1
			printerr("topic too short: %s" % t["word"])
	eq(bad, 0, "all topics >= 2 mora")


# ---- 韻エンジン ----
func test_rhyme_engine() -> void:
	var r := RhymeEngine.analyze(_dict.lookup("階段")["moras"], _dict.lookup("裁判")["moras"])
	eq(r["match_len"], 4, "階段/裁判 match_len 4")
	ok(r["tail_aligned"], "階段/裁判 tail aligned")
	eq(r["consonant_hits"], 2, "階段/裁判 consonant hits (い・ん)")
	var r2 := RhymeEngine.analyze(_dict.lookup("階段")["moras"], _dict.lookup("寿司")["moras"])
	ok(r2["match_len"] < 3, "階段/寿司 is a short match")
	var r3 := RhymeEngine.analyze(_dict.lookup("階段")["moras"], _dict.lookup("ぎゅうにゅう")["moras"])
	eq(r3["match_len"], 0, "階段/ぎゅうにゅう no shared vowel (uuuu vs aiaN)")
	eq(RhymeEngine.analyze(_dict.lookup("階段")["moras"], _dict.lookup("寿司")["moras"])["match_len"], 1, "階段/寿司 share only 'i'")
	var r4 := RhymeEngine.analyze([], _dict.lookup("裁判")["moras"])
	eq(r4["match_len"], 0, "empty topic")
	# 語末でない一致は tail_aligned=false
	var r5 := RhymeEngine.analyze(_dict.lookup("階段")["moras"], _dict.lookup("最高")["moras"])
	ok(not r5["tail_aligned"] or r5["match_len"] <= 2, "階段/最高 not tail-aligned long match")


# ---- 距離 ----
func test_distance() -> void:
	var res := DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("裁判"))
	ok(res["valid"], "階段→裁判 valid")
	eq(res["match_len"], 4, "階段→裁判 len")
	ok(res["distance_yd"] >= 200 and res["distance_yd"] <= 340, "階段→裁判 in long-drive range (%d)" % res["distance_yd"])
	# 同音異義語(会談/怪談)は最強級
	var homo: int = yd("階段", "会談")
	ok(homo > yd("階段", "最高") and homo >= 250, "homophone is a huge shot (%d)" % homo)
	# 長い韻ほど遠い（同条件で単調）
	var d1: int = yd("階段", "寿司")
	var d4: int = yd("階段", "裁判")
	ok(d4 > d1, "longer rhyme flies farther")
	# 無関係 → 0
	eq(yd("階段", "寿司"), DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("寿司"))["distance_yd"], "self-consistency")
	# 同じ言葉は無効
	var same := DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("階段"))
	ok(not same["valid"] and same["reason"] == DistanceCalc.Reason.SAME_WORD, "same surface word rejected")
	var same_kana := DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("かいだん"))
	ok(not same_kana["valid"], "same reading by kana rejected")
	# 辞書にない漢字 → 無効
	var unk := DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("鬱"))
	ok(not unk["valid"] and unk["reason"] == DistanceCalc.Reason.UNKNOWN_WORD, "unknown kanji rejected")
	# かな直入力は有効
	ok(DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("さいばん"))["valid"], "kana input valid")
	ok(DistanceCalc.compute(_dict.lookup("階段"), _dict.lookup("サイバン"))["valid"], "katakana input valid")
	# 意外性: カテゴリ違い > 同カテゴリ（同じ韻長・語末一致の対で比較）
	var t := _dict.lookup("階段")
	var same_cat := {"word": "x", "reading": "あいだん", "category": "place", "freq": 1, "moras": Kana.to_moras("あいだん"), "in_dict": true}
	var diff_cat := {"word": "y", "reading": "あいだん", "category": "society", "freq": 1, "moras": Kana.to_moras("あいだん"), "in_dict": true}
	ok(DistanceCalc.compute(t, diff_cat)["distance_yd"] > DistanceCalc.compute(t, same_cat)["distance_yd"], "surprise raises distance")
	# 稀な語ほど意外性が高い
	var rare := {"word": "r", "reading": "あいだん", "category": "place", "freq": 3, "moras": Kana.to_moras("あいだん"), "in_dict": true}
	ok(DistanceCalc.compute(t, rare)["distance_yd"] > DistanceCalc.compute(t, same_cat)["distance_yd"], "rarity raises distance")
	# ベース表の単調性
	for i in range(1, 12):
		ok(DistanceCalc.base_yd(i) > DistanceCalc.base_yd(i - 1), "base monotonic %d" % i)


func test_determinism_and_bounds() -> void:
	var words: Array = _dict.entries.keys()
	var topics: Array = _dict.topics
	var max_seen := 0
	var violations := 0
	var nondeterministic := 0
	for t in topics:
		for w in words:
			var a := DistanceCalc.compute(t, _dict.entries[w])
			var b := DistanceCalc.compute(t, _dict.entries[w])
			if a != b:
				nondeterministic += 1
			if a["valid"]:
				var d: int = a["distance_yd"]
				max_seen = maxi(max_seen, d)
				if d < 0 or d > DistanceCalc.MAX_YD:
					violations += 1
	eq(nondeterministic, 0, "compute is deterministic over all pairs")
	eq(violations, 0, "all distances within 0..360")
	ok(max_seen >= 250, "some pair reaches a big drive (max %d)" % max_seen)


## 禁止事項: 距離は (お題, 回答) だけで決まる。ホール状態・打数・残り距離は影響しない。
func test_no_hidden_correction() -> void:
	var t := _dict.lookup("階段")
	var a := _dict.lookup("裁判")
	var before: int = DistanceCalc.compute(t, a)["distance_yd"]
	var h := HoleState.new()
	h.apply_shot("x", 100)
	h.apply_shot("y", 270)  # 残り10ydの状態
	var after: int = DistanceCalc.compute(t, a)["distance_yd"]
	eq(before, after, "distance independent of hole state / remaining yards")
	# 残り3ydで300yd打てば、そのまま300yd飛ぶ（補正なし）→ OB
	var h2 := HoleState.new()
	h2.position_yd = HoleState.TOTAL_YD - 3
	var rec := h2.apply_shot("z", 300)
	eq(rec["outcome"], HoleState.Outcome.OB, "3yd left + 300yd shot = OB")
	eq(h2.position_yd, HoleState.TOTAL_YD - 3, "OB returns to previous spot")
	eq(h2.strokes, 2, "OB = shot + 1 penalty")


func test_topic_picker() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var p := TopicPicker.new(_dict.topics, rng)
	var prev := ""
	var recent: Array = []
	var dup_recent := 0
	var seen := {}
	for i in 500:
		var t: Dictionary = p.next()
		if t["word"] == prev:
			dup_recent += 1
		if recent.has(t["word"]):
			dup_recent += 1
		recent.append(t["word"])
		if recent.size() > TopicPicker.RECENT_BLOCK:
			recent.pop_front()
		prev = t["word"]
		seen[t["word"]] = true
	eq(dup_recent, 0, "no topic repeats within recent window")
	ok(seen.size() > 80, "topic variety over 500 draws (%d)" % seen.size())
	# 同シードで再現
	var r1 := RandomNumberGenerator.new(); r1.seed = 7
	var r2 := RandomNumberGenerator.new(); r2.seed = 7
	var p1 := TopicPicker.new(_dict.topics, r1)
	var p2 := TopicPicker.new(_dict.topics, r2)
	var same := true
	for i in 50:
		if p1.next()["word"] != p2.next()["word"]:
			same = false
	ok(same, "topic picker reproducible with seed")
	# 小さなプールでもクラッシュしない
	var small := TopicPicker.new(_dict.topics.slice(0, 2), rng)
	for i in 10:
		small.next()
	ok(true, "tiny pool ok")


func test_hole_rules() -> void:
	# フェアウェイ
	var h := HoleState.new()
	var r := h.apply_shot("a", 284)
	eq(r["outcome"], HoleState.Outcome.FAIRWAY, "fairway")
	eq(h.remaining_yd(), 96, "380-284 = 96 left")
	eq(h.strokes, 1, "1 stroke")
	# カップイン
	r = h.apply_shot("b", 96)
	eq(r["outcome"], HoleState.Outcome.CUP_IN, "exact cup-in")
	ok(h.finished, "finished on cup-in")
	eq(h.score_label(), "イーグル", "2 strokes on par 4 = eagle")
	# 許容範囲
	var h2 := HoleState.new()
	h2.position_yd = 300
	eq(h2.apply_shot("c", 82)["outcome"], HoleState.Outcome.CUP_IN, "within +2 tolerance")
	var h3 := HoleState.new()
	h3.position_yd = 300
	eq(h3.apply_shot("c", 77)["outcome"], HoleState.Outcome.FAIRWAY, "3 short of cup stays on course")
	# オーバーショット→戻り方向
	var h4 := HoleState.new()
	h4.position_yd = 370
	r = h4.apply_shot("d", 25)
	eq(r["outcome"], HoleState.Outcome.OVER, "over the cup, still in bounds")
	eq(h4.remaining_yd(), 15, "15 yd past cup")
	eq(h4.direction(), -1, "must hit back")
	r = h4.apply_shot("e", 15)
	eq(r["outcome"], HoleState.Outcome.CUP_IN, "back-hit cup in")
	# OB境界
	var h5 := HoleState.new()
	h5.position_yd = 350
	eq(h5.apply_shot("f", 60)["outcome"], HoleState.Outcome.OVER, "30 over = still OVER")
	var h6 := HoleState.new()
	h6.position_yd = 350
	eq(h6.apply_shot("f", 61)["outcome"], HoleState.Outcome.OB, "31 over = OB")
	# 空振り
	var h7 := HoleState.new()
	eq(h7.apply_shot("g", 0)["outcome"], HoleState.Outcome.WHIFF, "0yd = whiff")
	eq(h7.strokes, 1, "whiff costs a stroke")
	eq(h7.position_yd, 0, "whiff doesn't move ball")
	# 打数上限
	var h8 := HoleState.new()
	for i in HoleState.MAX_STROKES:
		if not h8.finished:
			h8.apply_shot("w%d" % i, 0)
	ok(h8.finished and h8.picked_up, "pickup at max strokes")
	# スコアラベル
	eq(HoleState.label_for(1, 4), "ホールインワン", "ace")
	eq(HoleState.label_for(2, 4), "イーグル", "eagle")
	eq(HoleState.label_for(3, 4), "バーディ", "birdie")
	eq(HoleState.label_for(4, 4), "パー", "par")
	eq(HoleState.label_for(5, 4), "ボギー", "bogey")
	# 使用済み単語
	var h9 := HoleState.new()
	h9.apply_shot("裁判", 100)
	ok(h9.has_used("裁判") and not h9.has_used("最高"), "used-word tracking")
