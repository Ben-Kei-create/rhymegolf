class_name GameManager
extends RefCounted
## 各サービスの統合（設計書 8.1）。UIとは無関係。ショットは submit() で1回だけ確定する。

var lexicon: LexiconRepository
var scorer: RhymeScorer
var deck: PromptDeck
var resolver := ShotResolver.new()
var sm := GameStateMachine.new()
var courses: Array = []
var rules: GolfRules
var mapper: CourseMapper
var hole_index := 0
var prompt: Dictionary = {}
var used_answer_ids: Array = []
var last_record: Dictionary = {}

const COURSES_PATH := "res://data/courses_v1.json"


func setup(seed_value: int = 0) -> bool:
	lexicon = LexiconRepository.load_default()
	if lexicon.entries.is_empty() or lexicon.prompt_ids.is_empty():
		return false
	scorer = RhymeScorer.load_default(lexicon)
	deck = PromptDeck.new(lexicon.prompt_ids, seed_value)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURSES_PATH))
	if not (data is Dictionary):
		return false
	courses = data["holes"]
	sm.go(GameStateMachine.S.HOLE_LOADING)
	return true


func start_hole(index: int) -> void:
	hole_index = index
	if sm.state != GameStateMachine.S.HOLE_LOADING:
		sm.go(GameStateMachine.S.HOLE_LOADING)
	rules = GolfRules.new(courses[index])
	mapper = CourseMapper.new(courses[index])
	used_answer_ids.clear()
	last_record = {}
	_new_prompt()
	sm.go(GameStateMachine.S.PROMPT_READY)


func _new_prompt() -> void:
	prompt = lexicon.get_entry(deck.next_prompt_id())


## 入力を検証し、有効なら採点・着地を確定する。戻り値:
## {ok, reason(String), message(String), candidates(Array), record(Dictionary)}
func submit(text: String) -> Dictionary:
	if sm.state != GameStateMachine.S.PROMPT_READY or rules.finished:
		return {"ok": false, "reason": "busy", "message": "", "candidates": [], "record": {}}
	sm.go(GameStateMachine.S.INPUT_VALIDATE)
	var r := lexicon.resolve(text)
	var msg := ""
	var reason := ""
	match r["status"]:
		LexiconRepository.Status.EMPTY:
			reason = "empty"
			msg = "言葉を入力してね"
		LexiconRepository.Status.UNKNOWN:
			reason = "unknown"
			msg = "辞書にない言葉です。別の言葉で試して！"
		LexiconRepository.Status.AMBIGUOUS:
			reason = "ambiguous"
			var names: Array = []
			for c in r["candidates"]:
				names.append(c["surface"])
			msg = "同じ読みが複数あるよ。漢字で入力してね（%s）" % "／".join(names)
		_:
			if text.length() > LexiconRepository.MAX_INPUT_CHARS:
				reason = "too_long"
				msg = "%d文字までだよ" % LexiconRepository.MAX_INPUT_CHARS
			elif r["entry"]["entry_id"] == prompt["entry_id"]:
				reason = "same_as_prompt"
				msg = "お題そのものはダメ！"
	if reason != "":
		sm.go(GameStateMachine.S.PROMPT_READY)  # 打数は消費しない
		return {"ok": false, "reason": reason, "message": msg, "candidates": r["candidates"], "record": {}}
	var answer: Dictionary = r["entry"]
	var rec := resolver.commit(scorer, rules, prompt, answer, used_answer_ids)
	if not used_answer_ids.has(answer["entry_id"]):
		used_answer_ids.append(answer["entry_id"])
	last_record = rec
	sm.go(GameStateMachine.S.SHOT_LOCKED)
	return {"ok": true, "reason": "", "message": "", "candidates": [], "record": rec}


## 演出側が段階ごとに呼ぶ（SHOT_LOCKED → SWING → FLIGHT → LANDING）
func begin_swing() -> bool:
	return sm.go(GameStateMachine.S.SWING_ANIMATION)


func begin_flight() -> bool:
	return sm.go(GameStateMachine.S.BALL_FLIGHT)


func land() -> bool:
	return sm.go(GameStateMachine.S.LANDING_RESOLVE)


## 着地後の遷移を決める。戻り値: "penalty" | "hole_result" | "continue"
func after_landing() -> String:
	if last_record["penalty"] > 0 and not rules.finished:
		sm.go(GameStateMachine.S.PENALTY_ANIMATION)
		return "penalty"
	return _advance()


func after_penalty() -> String:
	return _advance()


func _advance() -> String:
	if rules.finished:
		sm.go(GameStateMachine.S.HOLE_RESULT)
		return "hole_result"
	_new_prompt()  # 毎ショット新しいお題
	sm.go(GameStateMachine.S.PROMPT_READY)
	return "continue"


func give_up() -> bool:
	if sm.state != GameStateMachine.S.PROMPT_READY:
		return false
	rules.give_up()
	return sm.go(GameStateMachine.S.HOLE_RESULT)


## ホール結果後: 次ホールがあれば true（HOLE_LOADING）、なければ ROUND_RESULT
func next_after_result() -> bool:
	if hole_index + 1 < courses.size():
		sm.go(GameStateMachine.S.HOLE_LOADING)
		return true
	sm.go(GameStateMachine.S.ROUND_RESULT)
	return false


func retry_round() -> void:
	sm.go(GameStateMachine.S.HOLE_LOADING)
	start_hole(0)
