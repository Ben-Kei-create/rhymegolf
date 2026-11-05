extends RefCounted

func run(t) -> void:
	# R01
	t.eq(t.entry("階段")["vowels"], ["A", "I", "A", "N"], "R01 階段 vowels")
	t.eq(t.entry("裁判")["vowels"], ["A", "I", "A", "N"], "R01 裁判 vowels")
	t.eq(RhymeScorer.matched_moras(t.entry("階段")["vowels"], t.entry("裁判")["vowels"]), 4, "R01 L=4")
	# R02（設計書の例。辞書にない語はトークナイザ直接）
	t.eq(MoraTokenizer.vowels("ぎんが"), ["I", "N", "A"], "R02 銀河")
	t.eq(MoraTokenizer.vowels("しんか"), ["I", "N", "A"], "R02 進化")
	t.eq(RhymeScorer.matched_moras(MoraTokenizer.vowels("ぎんが"), MoraTokenizer.vowels("しんか")), 3, "R02 L=3")
	# R03 拗音
	t.eq(MoraTokenizer.tokenize("きゃ").size(), 1, "R03 きゃ=1モーラ")
	t.eq(MoraTokenizer.vowels("きゃ"), ["A"], "R03 きゃ=A")
	t.eq(MoraTokenizer.vowels("しゃ"), ["A"], "R03 しゃ=A")
	t.eq(MoraTokenizer.vowels("ファ"), ["A"], "R03 ファ=A（小書き母音）")
	# R04 促音・長音
	t.eq(MoraTokenizer.vowels("がっこう"), ["A", "Q", "O", "U"], "R04 がっこう")
	t.eq(MoraTokenizer.vowels("こーひー"), ["O", "O", "I", "I"], "R04 長音=直前母音")
	t.eq(MoraTokenizer.vowels("らーめん"), ["A", "A", "E", "N"], "R04 らーめん")
	t.eq(MoraTokenizer.vowels("ラーメン"), ["A", "A", "E", "N"], "R04 カタカナ")
	t.eq(MoraTokenizer.tokenize("abc").size(), 0, "非かなは空")
	t.eq(MoraTokenizer.tokenize("ー").size(), 0, "先頭の長音は不正")
	# N/Q は母音と一致しない
	t.eq(RhymeScorer.matched_moras(["A", "N"], ["A", "A"]), 0, "N は A と一致しない")
	t.eq(RhymeScorer.matched_moras(["A", "Q"], ["A", "N"]), 0, "Q は N と一致しない")
	t.eq(RhymeScorer.matched_moras(["O", "N"], ["A", "O", "N"]), 2, "N 同士は一致")
	# R05 正規化
	t.eq(KanaNormalizer.normalize(" 階段 "), "階段", "R05 前後空白")
	t.eq(KanaNormalizer.normalize("ｻｲﾊﾞﾝ"), "サイバン", "R05 半角カナ+濁点")
	t.eq(KanaNormalizer.normalize("ﾊﾟﾝ"), "パン", "R05 半濁点")
	t.eq(KanaNormalizer.normalize("ｶﾞｯｺｳ"), "ガッコウ", "R05 半角 ｯ")
	t.eq(KanaNormalizer.normalize("ＡＢＣ１２３"), "abc123", "R05 全角英数→半角")
	t.eq(t.lex.resolve("ｻｲﾊﾞﾝ")["entry"]["surface"], "裁判", "R05 半角カナ→語彙解決")
	t.eq(t.lex.resolve(" さいばん　")["entry"]["surface"], "裁判", "R05 空白付きかな")
	t.eq(t.lex.resolve("サイバン")["entry"]["surface"], "裁判", "R05 カタカナ読み")
	t.eq(t.lex.resolve("")["status"], LexiconRepository.Status.EMPTY, "R06 空文字")
	t.eq(t.lex.resolve("    ")["status"], LexiconRepository.Status.EMPTY, "R06 空白のみ")
	t.eq(t.lex.resolve("ふんぎゃろ")["status"], LexiconRepository.Status.UNKNOWN, "R06 未登録語")
	t.eq(t.lex.resolve("かいだん")["status"], LexiconRepository.Status.AMBIGUOUS, "同音異義の読み入力は候補選択")
	t.eq(t.lex.resolve("かいだん")["candidates"].size(), 3, "かいだん=階段/会談/怪談")
	# 辞書の整合性（Python生成の vowels と GDScript トークナイザが一致）
	var bad := 0
	for id in t.lex.entries:
		var e: Dictionary = t.lex.entries[id]
		if MoraTokenizer.vowels(e["reading_hira"]) != e["vowels"] or e["vowels"].is_empty():
			bad += 1
			printerr("vowel mismatch: " + e["surface"])
	t.eq(bad, 0, "全辞書で GDScript と Python の母音列が一致")
	t.ok(t.lex.entries.size() >= 250, "辞書 250語以上 (%d)" % t.lex.entries.size())
