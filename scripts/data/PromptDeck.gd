class_name PromptDeck
extends RefCounted
## お題の抽選（設計書 4.3）。ショットごとにランダム。直前と同一のみ除外。
## 距離・成功度・パット状況で確率を変えない。採点には乱数を使わない（乱数はここだけ）。

var seed_value: int
var history: Array = []   # 出題した prompt_id の列（保存用）
var _pool: Array
var _rng := RandomNumberGenerator.new()
var _last := ""


func _init(pool_ids: Array, seed_in: int = 0) -> void:
	_pool = pool_ids
	if seed_in == 0:
		_rng.randomize()
		seed_value = int(_rng.seed)
	else:
		seed_value = seed_in
	_rng.seed = seed_value


func next_prompt_id() -> String:
	assert(not _pool.is_empty())
	var pick := ""
	if _pool.size() == 1:
		pick = _pool[0]
	else:
		pick = _pool[_rng.randi() % _pool.size()]
		while pick == _last:
			pick = _pool[_rng.randi() % _pool.size()]
	_last = pick
	history.append(pick)
	return pick
