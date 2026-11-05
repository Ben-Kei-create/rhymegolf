class_name HoleState
extends RefCounted
## 1ホールの状態とルール。ここに「飛距離は入力された韻のみで決まる」以外の補正は存在しない。
##
## 座標: tee=0、cup=total_yd。position_yd はボールのtee基準位置（カップを越えた場合は total_yd 超）。

const PAR := 4
const TOTAL_YD := 380
const CUP_TOLERANCE_YD := 2   # カップから±2yd以内に止まればカップイン（暫定）
const OB_MARGIN_YD := 30      # カップを越えて30yd超はOB（暫定）
const MAX_STROKES := 12       # 打数上限（暫定）。到達でピックアップ

enum Outcome { FAIRWAY, CUP_IN, OVER, OB, WHIFF }

var par: int = PAR
var total_yd: int = TOTAL_YD
var position_yd: int = 0
var strokes: int = 0
var finished: bool = false
var picked_up: bool = false
var used_words: Array = []
var history: Array = []


func remaining_yd() -> int:
	return absi(total_yd - position_yd)


## 進行方向: カップが前方なら +1、カップを越えて戻る場合は -1
func direction() -> int:
	return 1 if position_yd <= total_yd else -1


func has_used(word: String) -> bool:
	return used_words.has(word)


## 確定した飛距離でショットを適用する。
func apply_shot(word: String, distance_yd: int) -> Dictionary:
	assert(not finished)
	var from_pos := position_yd
	var dir := direction()
	strokes += 1
	used_words.append(word)
	var outcome: int
	var penalty := 0
	var overshoot := 0
	if distance_yd <= 0:
		outcome = Outcome.WHIFF
	else:
		var new_pos := position_yd + dir * distance_yd
		overshoot = (new_pos - total_yd) * dir  # >0: カップを越えた量, <0: 手前
		if absi(overshoot) <= CUP_TOLERANCE_YD:
			outcome = Outcome.CUP_IN
			position_yd = total_yd
			finished = true
		elif overshoot > OB_MARGIN_YD:
			outcome = Outcome.OB
			penalty = 1
			strokes += 1  # OB: 1打罰、元の位置から打ち直し（飛距離の補正はしない）
		elif overshoot > 0:
			outcome = Outcome.OVER
			position_yd = new_pos
		else:
			outcome = Outcome.FAIRWAY
			position_yd = new_pos
	if not finished and strokes >= MAX_STROKES:
		finished = true
		picked_up = true
	var rec := {
		"word": word, "distance_yd": distance_yd, "from_yd": from_pos, "to_yd": position_yd,
		"outcome": outcome, "penalty": penalty, "overshoot_yd": overshoot, "strokes": strokes,
		"remaining_yd": remaining_yd(), "finished": finished, "picked_up": picked_up,
		"direction": dir,
	}
	history.append(rec)
	return rec


func score_label() -> String:
	if picked_up:
		return "ピックアップ"
	return label_for(strokes, par)


static func label_for(strokes_: int, par_: int) -> String:
	if strokes_ == 1:
		return "ホールインワン"
	var d := strokes_ - par_
	match d:
		-3: return "アルバトロス"
		-2: return "イーグル"
		-1: return "バーディ"
		0: return "パー"
		1: return "ボギー"
		2: return "ダブルボギー"
		3: return "トリプルボギー"
		_: return ("+%d" % d) if d > 0 else str(d)
