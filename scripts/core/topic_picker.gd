class_name TopicPicker
extends RefCounted
## 毎ショットのお題抽選。直近 RECENT_BLOCK 件は除外（連続・近接の重複を防ぐ）。

const RECENT_BLOCK := 8

var _pool: Array
var _rng: RandomNumberGenerator
var _recent: Array = []


func _init(pool: Array, rng: RandomNumberGenerator = null) -> void:
	_pool = pool
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


## 次のお題エントリを返す。
func next() -> Dictionary:
	assert(not _pool.is_empty())
	var block := mini(RECENT_BLOCK, _pool.size() - 1)
	var candidates: Array = []
	for e in _pool:
		if not _recent.has(e["word"]):
			candidates.append(e)
	var pick: Dictionary = candidates[_rng.randi() % candidates.size()]
	_recent.append(pick["word"])
	while _recent.size() > block:
		_recent.pop_front()
	return pick
