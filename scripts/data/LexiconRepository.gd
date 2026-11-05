class_name LexiconRepository
extends RefCounted
## 辞書（lexicon_v1.json）・お題プール・カテゴリ距離の参照。表記ゆれ解決（設計書 4.2 / 8.1）。

const LEXICON_PATH := "res://data/lexicon_v1.json"
const POOL_PATH := "res://data/prompt_pool_v1.json"
const CATEGORY_PATH := "res://data/category_distance_v1.json"
const MAX_INPUT_CHARS := 24

enum Status { OK, EMPTY, UNKNOWN, AMBIGUOUS }

var lexicon_version := ""
var entries: Dictionary = {}      # entry_id -> entry
var prompt_ids: Array = []
var _by_surface: Dictionary = {}  # 正規化surface -> entry_id
var _by_alias: Dictionary = {}    # ひらがなキー -> [entry_id]
var _cat: Dictionary = {}
var _cat_group: Dictionary = {}   # category -> group


static func load_default() -> LexiconRepository:
	var r := LexiconRepository.new()
	if not r.load_files(LEXICON_PATH, POOL_PATH, CATEGORY_PATH):
		push_error("LexiconRepository: load failed")
	return r


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func load_files(lex_path: String, pool_path: String, cat_path: String) -> bool:
	var lex: Variant = _read_json(lex_path)
	var pool: Variant = _read_json(pool_path)
	var cat: Variant = _read_json(cat_path)
	if not (lex is Dictionary and pool is Dictionary and cat is Dictionary):
		return false
	lexicon_version = lex["lexicon_version"]
	_cat = cat
	for g in cat["groups"]:
		for c in cat["groups"][g]:
			_cat_group[c] = g
	entries.clear()
	_by_surface.clear()
	_by_alias.clear()
	for e in lex["entries"]:
		if not e.get("approved", false):
			continue  # 未審査語は出荷しない
		entries[e["entry_id"]] = e
		_by_surface[KanaNormalizer.normalize(e["surface"])] = e["entry_id"]
		var keys: Array = [KanaNormalizer.to_reading_key(e["reading_hira"])]
		for al in e.get("aliases", []):
			keys.append(KanaNormalizer.to_reading_key(al))
		for k in keys:
			if not _by_alias.has(k):
				_by_alias[k] = []
			if not _by_alias[k].has(e["entry_id"]):
				_by_alias[k].append(e["entry_id"])
	prompt_ids.clear()
	for id in pool["prompt_ids"]:
		if entries.has(id) and entries[id].get("prompt_eligible", false):
			prompt_ids.append(id)
	return true


func get_entry(id: String) -> Dictionary:
	return entries.get(id, {})


## 入力→辞書エントリ。戻り値: {status, entry, candidates}
## 表記一致を優先。読み(かな)入力は一意に決まる場合のみ受理。複数候補は選択を促す（無断推定しない）。
func resolve(input: String) -> Dictionary:
	var text := KanaNormalizer.normalize(input)
	if text.is_empty():
		return {"status": Status.EMPTY, "entry": {}, "candidates": []}
	if _by_surface.has(text):
		return {"status": Status.OK, "entry": entries[_by_surface[text]], "candidates": []}
	var key := KanaNormalizer.to_hiragana(text)
	if _by_alias.has(key):
		var ids: Array = _by_alias[key]
		if ids.size() == 1:
			return {"status": Status.OK, "entry": entries[ids[0]], "candidates": []}
		var cands: Array = []
		for id in ids:
			cands.append(entries[id])
		return {"status": Status.AMBIGUOUS, "entry": {}, "candidates": cands}
	return {"status": Status.UNKNOWN, "entry": {}, "candidates": []}


## 意味距離 0..1。同カテゴリ=same / 同グループ=near / 別グループ=far / 未定義=undefined。対称。
func semantic_distance(cat_a: String, cat_b: String) -> float:
	if not _cat_group.has(cat_a) or not _cat_group.has(cat_b):
		return _cat["undefined"]
	if cat_a == cat_b:
		return _cat["same"]
	if _cat_group[cat_a] == _cat_group[cat_b]:
		return _cat["near"]
	return _cat["far"]


## 珍しさ 0(頻出)..1(珍しい)。未整備は 0.5。
func rarity_of(entry: Dictionary) -> float:
	if not entry.has("frequency_percentile"):
		return 0.5
	return clampf(float(entry["frequency_percentile"]), 0.0, 1.0)
