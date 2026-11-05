class_name ReadingDict
extends RefCounted
## 単語→読み・カテゴリ・頻度の辞書。res://data/words.tsv を読み込む（オフライン・同梱）。
##
## エントリ: {"word", "reading"(ひらがな), "category", "freq"(1=一般,3=稀), "topic"(bool), "moras"(Array), "in_dict"(bool)}

const DEFAULT_PATH := "res://data/words.tsv"
const UNKNOWN_CATEGORY := "?"
const KANA_INPUT_FREQ := 2

var entries: Dictionary = {}  # word -> entry
var topics: Array = []        # topic entries


static func load_default() -> ReadingDict:
	var d := ReadingDict.new()
	d.load_file(DEFAULT_PATH)
	return d


func load_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ReadingDict: cannot open %s" % path)
		return 0
	return load_text(f.get_as_text())


func load_text(text: String) -> int:
	entries.clear()
	topics.clear()
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols := line.split("\t")
		if cols.size() < 5:
			push_warning("ReadingDict: bad line: %s" % line)
			continue
		var reading := Kana.to_hiragana(cols[1])
		var moras := Kana.to_moras(reading)
		if moras.is_empty():
			push_warning("ReadingDict: bad reading: %s" % line)
			continue
		var e := {
			"word": cols[0],
			"reading": reading,
			"category": cols[2],
			"freq": int(cols[3]),
			"topic": cols[4] == "1",
			"moras": moras,
			"in_dict": true,
		}
		entries[cols[0]] = e
		if e["topic"]:
			topics.append(e)
	return entries.size()


## 入力文字列を辞書引き。辞書にあればそのエントリ、
## かな(ひらがな/カタカナ)のみなら読み＝入力として仮エントリを返す。それ以外は空Dictionary。
func lookup(input: String) -> Dictionary:
	var w := input.strip_edges()
	if w.is_empty():
		return {}
	if entries.has(w):
		return entries[w]
	if Kana.is_kana_only(w):
		var reading := Kana.to_hiragana(w)
		var moras := Kana.to_moras(reading)
		if moras.is_empty():
			return {}
		return {
			"word": w,
			"reading": reading,
			"category": UNKNOWN_CATEGORY,
			"freq": KANA_INPUT_FREQ,
			"topic": false,
			"moras": moras,
			"in_dict": false,
		}
	return {}
