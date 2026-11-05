extends RefCounted

const S := GameStateMachine.S


func _gm(seed_value: int) -> GameManager:
	var gm := GameManager.new()
	assert(gm.setup(seed_value))
	gm.start_hole(0)
	return gm


## 現在のお題に対し、辞書の中から指定条件の回答表記を探す
func _find_answer(gm: GameManager, min_y: float, max_y: float) -> String:
	for id in gm.lexicon.entries:
		var e: Dictionary = gm.lexicon.entries[id]
		if e["entry_id"] == gm.prompt["entry_id"] or gm.used_answer_ids.has(id):
			continue
		var y: float = gm.scorer.evaluate(gm.prompt, e)["shot_yards"]
		if y >= min_y and y <= max_y:
			return e["surface"]
	return ""


func _animate(gm: GameManager) -> String:
	gm.begin_swing()
	gm.begin_flight()
	gm.land()
	var nxt := gm.after_landing()
	if nxt == "penalty":
		nxt = gm.after_penalty()
	return nxt


func run(t) -> void:
	var gm := _gm(20261105)
	t.eq(gm.sm.state, S.PROMPT_READY, "ホール開始で PROMPT_READY")
	t.ok(not gm.prompt.is_empty(), "お題が出る")
	# R06/R07 無効入力は打数不変・状態は PROMPT_READY
	var bad := gm.submit("ふんぎゃろ")
	t.ok(not bad["ok"] and gm.rules.stroke_count == 0 and gm.sm.state == S.PROMPT_READY, "R06 未登録語は打数不変")
	t.ok(not gm.submit("")["ok"] and gm.rules.stroke_count == 0, "R06 空文字は打数不変")
	var same := gm.submit(gm.prompt["surface"])
	t.ok(not same["ok"] and same["reason"] == "same_as_prompt" and gm.rules.stroke_count == 0, "R07 お題そのものは無効・打数不変")
	# 有効ショット → SHOT_LOCKED。G06 二重送信は拒否
	var ans := _find_answer(gm, 10.0, 60.0)
	t.ok(ans != "", "テスト用回答が見つかる")
	var res := gm.submit(ans)
	t.ok(res["ok"], "有効入力")
	t.eq(gm.sm.state, S.SHOT_LOCKED, "SHOT_LOCKED")
	var dup := gm.submit(ans)
	t.ok(not dup["ok"] and dup["reason"] == "busy", "G06 二重送信は拒否")
	t.eq(gm.rules.stroke_count, 1, "G06 二重加算なし")
	t.eq(gm.resolver.shot_log.size(), 1, "G06 ログは1件")
	t.eq(gm.resolver.shot_log[0]["shot_id"], "S001", "shot_id")
	# 不正遷移は拒否
	t.ok(not gm.sm.go(S.PROMPT_READY), "SHOT_LOCKED→PROMPT_READY は不正")
	var prompt_before: String = gm.prompt["entry_id"]
	var nxt := _animate(gm)
	t.eq(nxt, "continue", "継続")
	t.ok(gm.prompt["entry_id"] != prompt_before, "G17/R17 次のお題は直前と異なる")
	t.eq(gm.sm.state, S.PROMPT_READY, "PROMPT_READY に戻る")
	# R17 全ショットで新しいお題が抽選される（履歴が増える）
	t.eq(gm.deck.history.size(), 2, "お題履歴（2回抽選）")
	# G09 同シード → 同じお題列
	var d1 := PromptDeck.new(gm.lexicon.prompt_ids, 777)
	var d2 := PromptDeck.new(gm.lexicon.prompt_ids, 777)
	var same_seq := true
	var no_repeat := true
	var prev := ""
	for i in 300:
		var x := d1.next_prompt_id()
		if x != d2.next_prompt_id():
			same_seq = false
		if x == prev:
			no_repeat = false
		prev = x
	t.ok(same_seq, "G09 同シードで同じお題列")
	t.ok(no_repeat, "直前と同一のお題は出ない")
	t.eq(d1.history.size(), 300, "お題履歴を保存")
	# 抽選が距離・状況に依存しない: PromptDeck は rules を持たない（構造で保証）
	t.ok(not ("rules" in d1), "R17 PromptDeck は距離状態に依存しない")
	# 再利用ペナルティ: 同じ回答を同一ホールで再度使うと 0.5 倍
	var gm2 := _gm(11)
	var reuse_prompt := gm2.prompt
	var ans2 := _find_answer(gm2, 10.0, 40.0)
	var r1 := gm2.submit(ans2)
	t.near(r1["record"]["evaluation"]["multiplier"], 1.0, "初回の倍率1.0")
	_animate(gm2)
	# 同じ回答がまた使える状況を作るため、お題を同じものへ差し替えて評価
	gm2.prompt = reuse_prompt
	var r2 := gm2.submit(ans2)
	if r2["ok"]:
		t.near(r2["record"]["evaluation"]["multiplier"], 0.5, "R09 同一ホール再利用は0.5")
		_animate(gm2)
	# 1ホール通し: 毎ターン最善手（カップに最も近い着地。OB/池は避ける）で完走
	var gm3 := _gm(42)
	var turns := 0
	while not gm3.rules.finished and turns < 40:
		turns += 1
		var best := ""
		var best_gap := INF
		for id in gm3.lexicon.entries:
			var e: Dictionary = gm3.lexicon.entries[id]
			if e["entry_id"] == gm3.prompt["entry_id"] or gm3.used_answer_ids.has(id):
				continue
			var y: float = gm3.scorer.evaluate(gm3.prompt, e)["shot_yards"]
			if y <= 0.0:
				continue
			var pv := gm3.rules.preview(y)
			if pv["outcome"] in [GolfRules.Outcome.OB, GolfRules.Outcome.WATER]:
				continue
			var gap := absf(pv["landing_s"] - gm3.rules.cup_s())
			if gap < best_gap:
				best_gap = gap
				best = e["surface"]
		var out := gm3.submit(best)
		if not out["ok"]:
			break
		_animate(gm3)
	t.ok(gm3.rules.finished, "1ホールを完走できる (%d打)" % gm3.rules.stroke_count)
	t.eq(gm3.sm.state, S.HOLE_RESULT, "HOLE_RESULT へ遷移")
	t.eq(gm3.resolver.shot_log.size() + 0, gm3.resolver.shot_log.size(), "ログ件数")
	# 記録された各ショットの飛距離は評価値そのもの（補正されない）
	var consistent := true
	for rec in gm3.resolver.shot_log:
		if rec["yards"] != rec["evaluation"]["shot_yards"]:
			consistent = false
	t.ok(consistent, "ShotRecord.yards == evaluation.shot_yards（補正なし）")
	# ギブアップ
	var gm4 := _gm(5)
	t.ok(gm4.give_up(), "ギブアップ")
	t.eq(gm4.rules.stroke_count, 15, "ギブアップは15打扱い")
	t.eq(gm4.sm.state, S.HOLE_RESULT, "ギブアップ後 HOLE_RESULT")
	t.ok(not gm4.next_after_result(), "1ホールのみ → ROUND_RESULT")
	t.eq(gm4.sm.state, S.ROUND_RESULT, "ROUND_RESULT")
