class_name Kana
extends RefCounted
## かな正規化・モーラ分割・母音/子音の抽出。純粋関数のみ（乱数・状態なし）。
##
## モーラ表現: {"kana": String, "c": String, "v": String}
##   v: "a","i","u","e","o"（母音）/ "N"（ん）/ "Q"（っ）
##   c: 子音ローマ字（"k","sh" ではなく行の代表 "s" など。拗音は "ky" のように "y" を付す）

const ROWS := [
	["", "あいうえお"],
	["k", "かきくけこ"],
	["g", "がぎぐげご"],
	["s", "さしすせそ"],
	["z", "ざじずぜぞ"],
	["t", "たちつてと"],
	["d", "だぢづでど"],
	["n", "なにぬねの"],
	["h", "はひふへほ"],
	["b", "ばびぶべぼ"],
	["p", "ぱぴぷぺぽ"],
	["m", "まみむめも"],
	["r", "らりるれろ"],
]
const VOWELS := "aiueo"
const SMALL_Y := {"ゃ": "a", "ゅ": "u", "ょ": "o"}
const SMALL_V := {"ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"}

static var _table: Dictionary = {}  # base kana -> [consonant, vowel]


static func _ensure_table() -> void:
	if not _table.is_empty():
		return
	for row in ROWS:
		var cons: String = row[0]
		var chars: String = row[1]
		for i in chars.length():
			_table[chars[i]] = [cons, VOWELS[i]]
	_table["や"] = ["y", "a"]
	_table["ゆ"] = ["y", "u"]
	_table["よ"] = ["y", "o"]
	_table["わ"] = ["w", "a"]
	_table["を"] = ["w", "o"]
	_table["ゐ"] = ["w", "i"]
	_table["ゑ"] = ["w", "e"]
	_table["ゔ"] = ["b", "u"]
	_table["ん"] = ["", "N"]
	_table["っ"] = ["", "Q"]


## カタカナ→ひらがな。ひらがな・「ー」・その他はそのまま。
static func to_hiragana(s: String) -> String:
	var out := ""
	for i in s.length():
		var cp := s.unicode_at(i)
		if cp >= 0x30A1 and cp <= 0x30F6:
			out += char(cp - 0x60)
		else:
			out += s[i]
	return out


static func is_kana_char(ch: String) -> bool:
	if ch.is_empty():
		return false
	var cp := ch.unicode_at(0)
	return (cp >= 0x3041 and cp <= 0x3096) or (cp >= 0x30A1 and cp <= 0x30FA) or cp == 0x30FC


## 全文字がかな（ひらがな・カタカナ・長音）か。
static func is_kana_only(s: String) -> bool:
	if s.is_empty():
		return false
	for i in s.length():
		if not is_kana_char(s[i]):
			return false
	return true


## 読み(ひらがな)をモーラ配列へ。未知の文字を含む場合は空配列。
static func to_moras(reading: String) -> Array:
	_ensure_table()
	var hira := to_hiragana(reading)
	var moras: Array = []
	for i in hira.length():
		var ch := hira[i]
		if ch == "ー":
			if moras.is_empty():
				return []
			moras.append({"kana": "ー", "c": "", "v": moras[-1]["v"]})
		elif SMALL_Y.has(ch):
			if moras.is_empty():
				return []
			var prev: Dictionary = moras[-1]
			prev["kana"] += ch
			prev["c"] += "y"
			prev["v"] = SMALL_Y[ch]
		elif SMALL_V.has(ch):
			if moras.is_empty():
				return []
			var prev2: Dictionary = moras[-1]
			prev2["kana"] += ch
			prev2["v"] = SMALL_V[ch]
		elif _table.has(ch):
			var cv: Array = _table[ch]
			moras.append({"kana": ch, "c": cv[0], "v": cv[1]})
		else:
			return []
	return moras


## 母音列（"aiaN" のような文字列）。
static func vowel_string(moras: Array) -> String:
	var s := ""
	for m in moras:
		s += m["v"]
	return s
