class_name ShotResolver
extends RefCounted
## 1回のショット確定処理（設計書 8.1 / 10）。採点→着地確定→不変のShotRecord追記。
## 同一ショットIDの二重確定は不可。再採点は行わない。

var shot_log: Array = []
var _counter := 0
var _committed_ids := {}


## prompt/answer は辞書エントリ。used_answer_ids は同一ホール内の既使用回答。
func commit(scorer: RhymeScorer, rules: GolfRules, prompt: Dictionary, answer: Dictionary, used_answer_ids: Array) -> Dictionary:
	_counter += 1
	var shot_id := "S%03d" % _counter
	assert(not _committed_ids.has(shot_id))
	_committed_ids[shot_id] = true
	var ev := scorer.evaluate(prompt, answer, used_answer_ids.has(answer["entry_id"]))
	var landing := rules.resolve(ev["shot_yards"])
	var rec := {
		"shot_id": shot_id,
		"hole_id": rules.hole["hole_id"],
		"prompt_id": prompt["entry_id"],
		"answer_id": answer["entry_id"],
		"prompt_surface": prompt["surface"],
		"answer_surface": answer["surface"],
		"yards": ev["shot_yards"],
		"evaluation": ev,
	}
	rec.merge(landing)
	shot_log.append(rec)
	return rec
