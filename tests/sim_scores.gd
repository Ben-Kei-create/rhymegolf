extends SceneTree
## 飛距離バランス確認用。全お題×全単語の組合せで分布を出す（調整の叩き台）。
## 実行: godot --headless --path . --script res://tests/sim_scores.gd

func _init() -> void:
	var dict := ReadingDict.load_default()
	var buckets := {}  # 20yd刻み
	var by_len := {}
	var total := 0
	var best := []
	for t in dict.topics:
		for w in dict.entries:
			var a: Dictionary = dict.entries[w]
			var r := DistanceCalc.compute(t, a)
			if not r["valid"]:
				continue
			total += 1
			var d: int = r["distance_yd"]
			var b := (d / 20) * 20
			buckets[b] = buckets.get(b, 0) + 1
			by_len[r["match_len"]] = by_len.get(r["match_len"], 0) + 1
			if d >= 200:
				best.append([d, t["word"], w])
	print("pairs: %d" % total)
	print("--- distance histogram (20yd) ---")
	var keys := buckets.keys()
	keys.sort()
	for k in keys:
		print("%3d-%3d : %5d  %s" % [k, k + 19, buckets[k], "#".repeat(mini(60, int(60.0 * buckets[k] / total * 4.0)))])
	print("--- match length ---")
	var lk := by_len.keys()
	lk.sort()
	for k in lk:
		print("len %d : %d (%.1f%%)" % [k, by_len[k], 100.0 * by_len[k] / total])
	best.sort_custom(func(x, y): return x[0] > y[0])
	print("--- top 12 ---")
	for i in mini(12, best.size()):
		print("%d yd  %s -> %s" % [best[i][0], best[i][1], best[i][2]])
	# 短い距離(1..30yd)の出やすさ = パターの面白さ
	var putt := 0
	for k in keys:
		if k <= 20:
			putt += buckets[k]
	print("short shots (<=39yd incl. 0): %.1f%%" % (100.0 * putt / total))
	quit()
