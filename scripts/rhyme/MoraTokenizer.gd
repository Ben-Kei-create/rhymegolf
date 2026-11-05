class_name MoraTokenizer
extends RefCounted
## 読み(ひらがな)→モーラ→母音列（A/I/U/E/O/N/Q）。設計書 5.1。
## 小書き仮名は直前と合わせて1モーラ。ん=N、っ=Q、長音ーは直前の母音を反復する1モーラ。
## tools/mora.py と同一規則（tests で全辞書の一致を検証）。

const ROWS := [
	"あいうえお", "かきくけこ", "がぎぐげご", "さしすせそ", "ざじずぜぞ", "たちつてと",
	"だぢづでど", "なにぬねの", "はひふへほ", "ばびぶべぼ", "ぱぴぷぺぽ", "まみむめも", "らりるれろ",
]
const V := "AIUEO"
const SMALL_Y := {"ゃ": "A", "ゅ": "U", "ょ": "O"}
const SMALL_V := {"ぁ": "A", "ぃ": "I", "ぅ": "U", "ぇ": "E", "ぉ": "O"}

static var _table: Dictionary = {}


static func _ensure() -> void:
	if not _table.is_empty():
		return
	for row in ROWS:
		for i in 5:
			_table[row[i]] = V[i]
	_table["や"] = "A"
	_table["ゆ"] = "U"
	_table["よ"] = "O"
	_table["わ"] = "A"
	_table["を"] = "O"
	_table["ゐ"] = "I"
	_table["ゑ"] = "E"
	_table["ゔ"] = "U"
	_table["ん"] = "N"
	_table["っ"] = "Q"


## モーラ配列 [{"kana": String, "v": String}]。変換不能な文字を含むと空配列。
static func tokenize(reading: String) -> Array:
	_ensure()
	var moras: Array = []
	var hira := KanaNormalizer.to_hiragana(reading)
	for i in hira.length():
		var ch := hira[i]
		if ch == "ー":
			if moras.is_empty():
				return []
			moras.append({"kana": "ー", "v": moras[-1]["v"]})
		elif SMALL_Y.has(ch) or SMALL_V.has(ch):
			if moras.is_empty():
				return []
			var m: Dictionary = moras[-1]
			m["kana"] += ch
			m["v"] = SMALL_Y[ch] if SMALL_Y.has(ch) else SMALL_V[ch]
		elif _table.has(ch):
			moras.append({"kana": ch, "v": _table[ch]})
		else:
			return []
	return moras


## 母音列 ["A","I","A","N"]。変換不能なら空配列。
static func vowels(reading: String) -> Array:
	var out: Array = []
	for m in tokenize(reading):
		out.append(m["v"])
	return out
