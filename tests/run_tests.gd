extends SceneTree
## 実行: godot --headless --path . --script res://tests/run_tests.gd   （失敗があれば終了コード1）

var _pass := 0
var _fail := 0
var lex: LexiconRepository
var scorer: RhymeScorer


func _init() -> void:
	lex = LexiconRepository.load_default()
	scorer = RhymeScorer.load_default(lex)
	for path in [
		"res://tests/rhyme/test_mora_tokenizer.gd",
		"res://tests/rhyme/test_rhyme_scorer.gd",
		"res://tests/golf/test_golf_rules.gd",
		"res://tests/integration/test_round_flow.gd",
	]:
		print("-- " + path.get_file())
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			_fail += 1
			printerr("FAIL: cannot load " + path)
			continue
		script.new().run(self)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func ok(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("FAIL: " + name)


func eq(a, b, name: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [name, str(a), str(b)])


func near(a: float, b: float, name: String, eps := 0.0001) -> void:
	ok(absf(a - b) <= eps, "%s (got %s, expected %s)" % [name, str(a), str(b)])


## 表記からエントリ（テスト用）
func entry(surface: String) -> Dictionary:
	var r := lex.resolve(surface)
	assert(r["status"] == LexiconRepository.Status.OK, "test word missing: " + surface)
	return r["entry"]
