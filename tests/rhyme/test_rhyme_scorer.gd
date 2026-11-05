extends RefCounted

# 設計書 5.5 のフィクスチャ: semantic_distance=1.0, rarity=0.5
func _fx(t, p_len: int, a_len: int, matched: int) -> float:
	var p: Array = []
	var a: Array = []
	for i in p_len:
		p.append("A" if i >= p_len - matched else "I")
	for i in a_len:
		a.append("A" if i >= a_len - matched else "U")
	return t.scorer.calculate_yards(p, a, 1.0, 0.5)


func run(t) -> void:
	# R11–R14
	t.near(_fx(t, 4, 4, 4), 174.8, "R11 m=4 L=4 → 174.8yd", 0.001)
	t.near(_fx(t, 4, 4, 2), 21.9, "R12 m=4 L=2 → 21.9yd", 0.001)
	t.near(_fx(t, 4, 4, 1), 1.3, "R13 m=4 L=1 → 1.3yd", 0.001)
	t.near(_fx(t, 4, 4, 0), 0.0, "R10 L=0 → 0.0yd", 0.0)
	t.near(_fx(t, 6, 6, 6), 337.7, "R14 m=6 L=6 → 337.7yd", 0.001)
	# 上限
	t.ok(_fx(t, 12, 12, 12) <= 360.0, "上限360yd")
	# phonetic
	t.near(t.scorer.phonetic_of(4, 4), 0.76, "phonetic(4/4)=0.76")
	t.near(t.scorer.surprise_of(1.0, 0.5), 0.825, "surprise(1.0,0.5)=0.825")
	t.eq(t.scorer.phonetic_of(0, 4), 0.0, "L=0 → phonetic 0")
	# 単調性: L が長いほど遠い
	var prev := -1.0
	for l in range(0, 7):
		var y := _fx(t, 6, 6, l)
		t.ok(y >= prev, "L=%d で単調増加" % l)
		prev = y
	# 0.1yd丸め
	var y2 := _fx(t, 5, 5, 3)
	t.near(y2 * 10.0, roundf(y2 * 10.0), "0.1yd 単位", 0.0001)

	# evaluate: 実辞書（階段 → 裁判）
	var ev: Dictionary = t.scorer.evaluate(t.entry("階段"), t.entry("裁判"))
	t.eq(ev["matching_moras"], 4, "階段→裁判 L=4")
	t.eq(ev["scoring_version"], "1.0.0", "scoring_version を記録")
	t.eq(ev["lexicon_version"], t.lex.lexicon_version, "lexicon_version を記録")
	t.ok(ev["shot_yards"] > 100.0 and ev["shot_yards"] <= 360.0, "階段→裁判 は長打 (%s)" % ev["shot_yards"])
	for k in ["matching_moras", "phonetic", "semantic_distance", "rarity", "surprise", "multiplier", "shot_yards", "scoring_version"]:
		t.ok(ev.has(k), "ShotEvaluation に %s" % k)
	# R08 同音異義語 ×0.25
	var normal: float = t.scorer.evaluate(t.entry("階段"), t.entry("最後"))["shot_yards"]
	var homo: Dictionary = t.scorer.evaluate(t.entry("階段"), t.entry("会談"))
	t.ok(homo["homophone"], "R08 会談 は同音異義語")
	t.near(homo["multiplier"], 0.25, "R08 倍率 0.25")
	var homo_full: float = t.scorer.calculate_yards(t.entry("階段")["vowels"], t.entry("会談")["vowels"],
		homo["semantic_distance"], homo["rarity"], 1.0)
	t.ok(homo["shot_yards"] < homo_full, "R08 同音異義語は減衰")
	# R09 再利用 ×0.5
	var first: Dictionary = t.scorer.evaluate(t.entry("階段"), t.entry("裁判"), false)
	var again: Dictionary = t.scorer.evaluate(t.entry("階段"), t.entry("裁判"), true)
	t.near(again["multiplier"], 0.5, "R09 再利用 0.5")
	t.ok(again["shot_yards"] < first["shot_yards"], "R09 再利用は短い")
	var both: Dictionary = t.scorer.evaluate(t.entry("階段"), t.entry("会談"), true)
	t.near(both["multiplier"], 0.125, "補正は積算 0.25×0.5")
	# R10 L=0 でも評価は有効で 0.0yd
	var zero := _find_zero(t)
	t.eq(zero, 0.0, "R10 韻なし → 0.0yd")
	# R15 決定論: 全ペアで2回計算して一致
	var nondet := 0
	var out_of_range := 0
	var max_seen := 0.0
	var ids: Array = t.lex.entries.keys()
	for pid in t.lex.prompt_ids:
		for aid in ids:
			if pid == aid:
				continue
			var a: Dictionary = t.scorer.evaluate(t.lex.entries[pid], t.lex.entries[aid])
			var b: Dictionary = t.scorer.evaluate(t.lex.entries[pid], t.lex.entries[aid])
			if a != b:
				nondet += 1
			var y: float = a["shot_yards"]
			max_seen = maxf(max_seen, y)
			if y < 0.0 or y > 360.0:
				out_of_range += 1
	t.eq(nondet, 0, "R15 全ペアで決定論")
	t.eq(out_of_range, 0, "全距離 0..360")
	t.ok(max_seen > 100.0, "大きな韻が存在 (max %s)" % max_seen)
	# 意外性: 離れたカテゴリ > 同カテゴリ
	t.ok(t.lex.semantic_distance("place", "society") > t.lex.semantic_distance("place", "place"), "意味距離 far > same")
	t.eq(t.lex.semantic_distance("place", "society"), t.lex.semantic_distance("society", "place"), "意味距離は対称")
	t.eq(t.lex.semantic_distance("place", "unknown_cat"), 0.5, "関係未定義=0.5")
	t.eq(t.lex.rarity_of({}), 0.5, "頻度未整備=0.5")


func _find_zero(t) -> float:
	# 階段(AIAN) に対し、末尾が N でない語は L=0
	for id in t.lex.entries:
		var e: Dictionary = t.lex.entries[id]
		if e["vowels"][-1] != "N" and e["entry_id"] != t.entry("階段")["entry_id"]:
			return t.scorer.evaluate(t.entry("階段"), e)["shot_yards"]
	return -1.0
