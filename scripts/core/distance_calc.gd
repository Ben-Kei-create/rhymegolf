class_name DistanceCalc
extends RefCounted
## 韻から飛距離(yd)を計算する。完全に決定論的。乱数・クラブ・風・残り距離補正は一切なし。
##
## 【暫定式】ゲームバランスの完成値ではない。tests/sim_scores.gd で分布を見て調整する。
##   distance = BASE[match_len] × 位置係数 × 純度係数 × 意外性係数  (0〜MAX_YD に丸め、整数yd)

const MAX_YD := 360
const BASE_YD := [0.0, 10.0, 55.0, 145.0, 250.0, 305.0, 340.0, 355.0]
const BASE_EXTRA_PER_MORA := 4.0           # 7モーラ超の1モーラあたり加算
const MISALIGNED_MULT := 0.8               # 語末が揃っていない韻の係数
const PURITY_MIN := 0.85                   # 子音が全く一致しない時の係数
const PURITY_BONUS := 0.15                 # 子音が全て一致すると +0.15
const SURPRISE_BONUS := 0.30               # 意外性 1.0 で +30%
const SURPRISE_W_CATEGORY := 0.6
const SURPRISE_W_RARITY := 0.4

enum Reason { OK, EMPTY, UNKNOWN_WORD, SAME_WORD }


## topic / answer は ReadingDict のエントリ。
static func compute(topic: Dictionary, answer: Dictionary) -> Dictionary:
	if answer.is_empty():
		return _invalid(Reason.UNKNOWN_WORD)
	if _is_same_word(topic, answer):
		return _invalid(Reason.SAME_WORD)

	var r := RhymeEngine.analyze(topic["moras"], answer["moras"])
	var len_: int = r["match_len"]
	if len_ == 0:
		return _result(0, r, 0.0, 0.0, 0.0, 0.0)

	var base := base_yd(len_)
	var aligned_mult := 1.0 if r["tail_aligned"] else MISALIGNED_MULT
	var purity := PURITY_MIN + PURITY_BONUS * float(r["consonant_hits"]) / float(len_)
	var surprise := surprise_of(topic, answer)
	var surprise_mult := 1.0 + SURPRISE_BONUS * surprise
	var yd := clampi(int(round(base * aligned_mult * purity * surprise_mult)), 0, MAX_YD)
	return _result(yd, r, aligned_mult, purity, surprise, surprise_mult)


static func base_yd(match_len: int) -> float:
	if match_len < BASE_YD.size():
		return BASE_YD[match_len]
	return BASE_YD[-1] + BASE_EXTRA_PER_MORA * (match_len - (BASE_YD.size() - 1))


## 意外性 0..1。カテゴリが違うほど、単語が稀なほど高い。
static func surprise_of(topic: Dictionary, answer: Dictionary) -> float:
	var cat_dist := 1.0
	if answer["category"] == ReadingDict.UNKNOWN_CATEGORY or topic["category"] == ReadingDict.UNKNOWN_CATEGORY:
		cat_dist = 0.5
	elif answer["category"] == topic["category"]:
		cat_dist = 0.0
	var rarity := clampf((float(answer["freq"]) - 1.0) / 2.0, 0.0, 1.0)
	return SURPRISE_W_CATEGORY * cat_dist + SURPRISE_W_RARITY * rarity


static func _is_same_word(topic: Dictionary, answer: Dictionary) -> bool:
	if topic["word"] == answer["word"]:
		return true
	# かな直入力で、お題と同じ読みなら同じ言葉扱い（辞書上の別単語＝同音異義語は有効）
	return not answer["in_dict"] and answer["reading"] == topic["reading"]


static func _invalid(reason: int) -> Dictionary:
	return {
		"valid": false, "reason": reason, "distance_yd": 0, "match_len": 0,
		"tail_aligned": false, "consonant_hits": 0, "surprise": 0.0,
		"stars_match": 0, "stars_surprise": 0,
	}


static func _result(yd: int, r: Dictionary, aligned_mult: float, purity: float, surprise: float, surprise_mult: float) -> Dictionary:
	var ml: int = r["match_len"]
	return {
		"valid": true,
		"reason": Reason.OK,
		"distance_yd": yd,
		"match_len": ml,
		"tail_aligned": r["tail_aligned"],
		"consonant_hits": r["consonant_hits"],
		"surprise": surprise,
		"aligned_mult": aligned_mult,
		"purity_mult": purity,
		"surprise_mult": surprise_mult,
		"stars_match": clampi(ml, 0, 5),
		"stars_surprise": clampi(int(round(surprise * 5.0)), 0, 5) if ml > 0 else 0,
	}
