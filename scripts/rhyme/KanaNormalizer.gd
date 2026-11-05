class_name KanaNormalizer
extends RefCounted
## 入力文字列の正規化（設計書 4.2）。全角/半角の揺れ・空白・半角カナ・カタカナ→ひらがな。

const HALF := "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝｧｨｩｪｫｬｭｮｯｰ"
const FULL := "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンァィゥェォャュョッー"
const DAKUTEN_BASE := "カキクケコサシスセソタチツテトハヒフヘホ"
const HANDAKU_BASE := "ハヒフヘホ"


## 表記の正規化（辞書の surface 照合用）。ひらがな化はしない。
static func normalize(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		var cp := s.unicode_at(i)
		if ch == "　" or ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			continue
		if cp >= 0xFF01 and cp <= 0xFF5E:  # 全角ASCII → 半角
			out += char(cp - 0xFEE0)
		elif ch == "ﾞ" or ch == "ﾟ":
			if out.is_empty():
				continue
			var prev := out[out.length() - 1]
			var composed := _compose(prev, ch == "ﾟ")
			if composed.is_empty():
				out += ch
			else:
				out = out.substr(0, out.length() - 1) + composed
		else:
			var idx := HALF.find(ch)
			out += FULL[idx] if idx >= 0 else ch
	return out.to_lower()


static func _compose(prev: String, handaku: bool) -> String:
	if handaku:
		if HANDAKU_BASE.contains(prev):
			return char(prev.unicode_at(0) + 2)
		return ""
	if prev == "ウ":
		return "ヴ"
	if DAKUTEN_BASE.contains(prev):
		return char(prev.unicode_at(0) + 1)
	return ""


## ひらがな読みキー（別名照合用）。
static func to_hiragana(s: String) -> String:
	var out := ""
	for i in s.length():
		var cp := s.unicode_at(i)
		if cp >= 0x30A1 and cp <= 0x30F6:
			out += char(cp - 0x60)
		else:
			out += s[i]
	return out


static func to_reading_key(s: String) -> String:
	return to_hiragana(normalize(s))
