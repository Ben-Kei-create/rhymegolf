"""MoraTokenizer(GDScript)と同一規則の Python 実装。辞書生成・検証用（開発時のみ）。"""
ROWS = [
    ("あいうえお", "AIUEO"), ("かきくけこ", "AIUEO"), ("がぎぐげご", "AIUEO"),
    ("さしすせそ", "AIUEO"), ("ざじずぜぞ", "AIUEO"), ("たちつてと", "AIUEO"),
    ("だぢづでど", "AIUEO"), ("なにぬねの", "AIUEO"), ("はひふへほ", "AIUEO"),
    ("ばびぶべぼ", "AIUEO"), ("ぱぴぷぺぽ", "AIUEO"), ("まみむめも", "AIUEO"),
    ("らりるれろ", "AIUEO"),
]
TABLE = {}
for chars, vs in ROWS:
    for ch, v in zip(chars, vs):
        TABLE[ch] = v
TABLE.update({"や": "A", "ゆ": "U", "よ": "O", "わ": "A", "を": "O", "ゐ": "I", "ゑ": "E", "ゔ": "U", "ん": "N", "っ": "Q"})
SMALL_Y = {"ゃ": "A", "ゅ": "U", "ょ": "O"}
SMALL_V = {"ぁ": "A", "ぃ": "I", "ぅ": "U", "ぇ": "E", "ぉ": "O"}


def to_hira(s):
    return "".join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in s)


def vowels(reading):
    out = []
    for ch in to_hira(reading):
        if ch == "ー":
            if not out:
                return None
            out.append(out[-1])
        elif ch in SMALL_Y or ch in SMALL_V:
            if not out:
                return None
            out[-1] = SMALL_Y.get(ch) or SMALL_V[ch]
        elif ch in TABLE:
            out.append(TABLE[ch])
        else:
            return None
    return out
