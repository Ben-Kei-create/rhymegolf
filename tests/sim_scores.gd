extends SceneTree
## 飛距離バランス確認用（設計書 11.2: 1モーラ一致でパットが成立するか／大韻で遠く飛ぶか）。
## 実行: godot --headless --path . --script res://tests/sim_scores.gd

func _init() -> void:
	var lex := LexiconRepository.load_default()
	var sc := RhymeScorer.load_default(lex)
	var buckets := {}
	var by_len := {}
	var total := 0
	var top: Array = []
	for pid in lex.prompt_ids:
		var p: Dictionary = lex.entries[pid]
		for aid in lex.entries:
			if aid == pid:
				continue
			var ev := sc.evaluate(p, lex.entries[aid])
			total += 1
			var y: float = ev["shot_yards"]
			var b := int(y / 20.0) * 20
			buckets[b] = buckets.get(b, 0) + 1
			by_len[ev["matching_moras"]] = by_len.get(ev["matching_moras"], 0) + 1
			if y >= 150.0:
				top.append([y, p["surface"], lex.entries[aid]["surface"], ev["matching_moras"]])
	print("pairs: %d" % total)
	var keys := buckets.keys()
	keys.sort()
	for k in keys:
		print("%3d-%3d yd : %6d (%.1f%%)" % [k, k + 19, buckets[k], 100.0 * buckets[k] / total])
	var lk := by_len.keys()
	lk.sort()
	for k in lk:
		print("L=%d : %6d (%.1f%%)" % [k, by_len[k], 100.0 * by_len[k] / total])
	top.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(10, top.size()):
		print("%.1f yd  %s -> %s (L=%d)" % [top[i][0], top[i][1], top[i][2], top[i][3]])
	quit()
