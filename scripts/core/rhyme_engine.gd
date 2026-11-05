class_name RhymeEngine
extends RefCounted
## 韻の解析。2つのモーラ列から「最長の共通母音連続」を求める。決定論的。
##
## 母音 "ん"(N)・"っ"(Q) も 1 モーラとして一致判定に含める。
## 長音「ー」は直前の母音を引き継ぐ（Kana.to_moras 側で解決済み）。


## 戻り値:
## {match_len, tail_aligned, consonant_hits, topic_start, answer_start}
static func analyze(topic_moras: Array, answer_moras: Array) -> Dictionary:
	var n := topic_moras.size()
	var m := answer_moras.size()
	var best := {"match_len": 0, "tail_aligned": false, "consonant_hits": 0, "topic_start": -1, "answer_start": -1}
	var best_key := -1
	var prev: Array = []
	prev.resize(m + 1)
	prev.fill(0)
	for i in n:
		var cur: Array = []
		cur.resize(m + 1)
		cur.fill(0)
		for j in m:
			if topic_moras[i]["v"] == answer_moras[j]["v"]:
				var run: int = prev[j] + 1
				cur[j + 1] = run
				var ts := i - run + 1
				var as_ := j - run + 1
				var aligned := (i == n - 1 and j == m - 1)
				var hits := 0
				for k in run:
					if topic_moras[ts + k]["c"] == answer_moras[as_ + k]["c"]:
						hits += 1
				# 長さ > 末尾一致 > 子音一致 の順で優先
				var key := run * 10000 + (1000 if aligned else 0) + hits
				if key > best_key:
					best_key = key
					best = {
						"match_len": run,
						"tail_aligned": aligned,
						"consonant_hits": hits,
						"topic_start": ts,
						"answer_start": as_,
					}
		prev = cur
	return best
