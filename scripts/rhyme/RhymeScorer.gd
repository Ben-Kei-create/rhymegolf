class_name RhymeScorer
extends RefCounted
## 飛距離の採点（設計書 5.2–5.5）。純粋計算・完全決定論。乱数・UI・3D・ゴルフ状態への参照禁止。
## 距離は (お題, 回答, 同一ホール再利用か) だけで決まる。残り距離・打数・クラブ・風は入力に存在しない。

const DEFAULT_CONFIG_PATH := "res://data/scoring_config_v1.json"

var config: Dictionary
var lexicon: LexiconRepository


static func load_default(lex: LexiconRepository) -> RhymeScorer:
	var s := RhymeScorer.new()
	s.lexicon = lex
	s.config = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_CONFIG_PATH))
	assert(s.config is Dictionary)
	return s


func version() -> String:
	return config["scoring_version"]


## 語末からの連続一致モーラ数 L。N/Q は同種同士のみ一致（ベクトル比較で自然に満たされる）。
static func matched_moras(p: Array, a: Array) -> int:
	var m := mini(p.size(), a.size())
	var matched := 0
	for i in range(1, m + 1):
		if p[p.size() - i] != a[a.size() - i]:
			break
		matched += 1
	return matched


func phonetic_of(matched: int, m: int) -> float:
	if matched <= 0 or m <= 0:
		return 0.0
	var length_component := clampf(float(matched - 1) / float(config["length_component_divisor"]), 0.0, 1.0)
	var coverage_component := float(matched) / float(m)
	return config["phonetic_length_weight"] * length_component + config["phonetic_coverage_weight"] * coverage_component


func surprise_of(semantic_distance: float, rarity: float) -> float:
	return config["surprise_semantic_weight"] * clampf(semantic_distance, 0.0, 1.0) \
		+ config["surprise_rarity_weight"] * clampf(rarity, 0.0, 1.0)


## 設計書 10 の calculate_yards に対応。語彙辞書に依存しない純粋計算（フィクスチャ検証用）。
func calculate_yards(p_vowels: Array, a_vowels: Array, semantic_distance: float, rarity: float, multiplier: float = 1.0) -> float:
	return float(_evaluate_core(p_vowels, a_vowels, semantic_distance, rarity, multiplier)["shot_yards"])


func _evaluate_core(p: Array, a: Array, semantic_distance: float, rarity: float, multiplier: float) -> Dictionary:
	var m := mini(p.size(), a.size())
	var matched := matched_moras(p, a)
	var phonetic := phonetic_of(matched, m)
	var surprise := surprise_of(semantic_distance, rarity)
	var yards := 0.0
	if matched > 0:
		var base_ratio: float = phonetic * (config["base_ratio_floor"] + config["base_ratio_surprise_gain"] * surprise)
		var raw: float = config["max_yards"] * pow(base_ratio, config["exponent"]) * multiplier
		yards = floorf(clampf(raw, 0.0, config["max_yards"]) * 10.0 + 0.5) / 10.0
	return {
		"matching_moras": matched, "phonetic": phonetic, "semantic_distance": semantic_distance,
		"rarity": rarity, "surprise": surprise, "multiplier": multiplier, "shot_yards": yards,
	}


## ShotEvaluation（設計書 9/5.6）。prompt/answer は辞書エントリ。
## 補正の順序は固定: 語彙判定 → 母音 → 意外性 → 飛距離 → ペナルティ → 0.1yd丸め。
func evaluate(prompt: Dictionary, answer: Dictionary, reused_in_hole: bool = false) -> Dictionary:
	var mult := 1.0
	var homophone: bool = answer["entry_id"] != prompt["entry_id"] and answer["reading_hira"] == prompt["reading_hira"]
	if homophone:
		mult *= float(config["homophone_multiplier"])
	if reused_in_hole:
		mult *= float(config["reuse_multiplier"])
	var sem := lexicon.semantic_distance(prompt["semantic_category"], answer["semantic_category"])
	var rarity := lexicon.rarity_of(answer)
	var ev := _evaluate_core(prompt["vowels"], answer["vowels"], sem, rarity, mult)
	ev["prompt_id"] = prompt["entry_id"]
	ev["answer_id"] = answer["entry_id"]
	ev["prompt_reading"] = prompt["reading_hira"]
	ev["answer_reading"] = answer["reading_hira"]
	ev["homophone"] = homophone
	ev["reused"] = reused_in_hole
	ev["tail_match"] = ev["matching_moras"]
	ev["scoring_version"] = version()
	ev["lexicon_version"] = lexicon.lexicon_version
	return ev
