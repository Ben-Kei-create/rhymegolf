class_name GolfRules
extends RefCounted
## ホール規則（設計書 4.4）。辞書・採点への参照禁止。入力は確定した飛距離(yd)のみ。
## next_s = ball_s + sign(cup_s - ball_s) * yards。クラブ・風・地形・残り距離による補正は存在しない。

const MAX_STROKES := 15
const EPS := 0.0001

enum Outcome { WHIFF, FAIRWAY, BUNKER, CUP_IN, OB, WATER }

var hole: Dictionary
var ball_s: float
var stroke_count := 0
var finished := false
var gave_up := false


func _init(hole_def: Dictionary) -> void:
	hole = hole_def
	ball_s = float(hole_def["start_s"])


func cup_s() -> float:
	return float(hole["cup_s"])


func par() -> int:
	return int(hole["par"])


func remaining_yd() -> float:
	return absf(cup_s() - ball_s)


## +1: カップが前方 / -1: カップを越えたので戻る方向
func direction() -> int:
	return 1 if cup_s() - ball_s >= 0.0 else -1


func _in_hazard(kind: String, s: float) -> bool:
	for h in hole["hazards"]:
		if h["kind"] == kind and s >= float(h["from_s"]) - EPS and s <= float(h["to_s"]) + EPS:
			return true
	return false


## 状態を変えずに結果を計算する（オートプレイ・テスト・UIプレビュー用）。
func preview(yards: float) -> Dictionary:
	var from_s := ball_s
	var dir := direction()
	var land := snappedf(from_s + dir * yards, 0.1)
	var outcome: int
	var penalty := 0
	var new_ball := from_s
	if yards <= 0.0:
		outcome = Outcome.WHIFF
		land = from_s
	elif absf(land - cup_s()) <= float(hole["cup_radius_yd"]) + EPS:
		outcome = Outcome.CUP_IN
		new_ball = land
	elif land < float(hole["min_s"]) or land > float(hole["max_s"]):
		outcome = Outcome.OB
		penalty = 1
	elif _in_hazard("water", land):
		outcome = Outcome.WATER
		penalty = 1
	else:
		new_ball = land
		outcome = Outcome.BUNKER if _in_hazard("bunker", land) else Outcome.FAIRWAY
	var overshot := (outcome == Outcome.FAIRWAY or outcome == Outcome.BUNKER) and (land - cup_s()) * dir > 0.0
	return {
		"outcome": outcome, "from_s": from_s, "landing_s": land, "new_ball_s": new_ball,
		"penalty": penalty, "overshot": overshot, "direction": dir,
	}


## ショット確定。打った1打＋罰打を加算（OB/池は元の位置へ戻す＝ストローク＆ディスタンス）。
func resolve(yards: float) -> Dictionary:
	assert(not finished)
	var rec := preview(yards)
	var remaining_before := remaining_yd()
	stroke_count += 1 + int(rec["penalty"])
	ball_s = rec["new_ball_s"]
	if rec["outcome"] == Outcome.CUP_IN:
		finished = true
	elif stroke_count >= MAX_STROKES:
		finished = true
		gave_up = true
		stroke_count = MAX_STROKES
	rec["remaining_before"] = remaining_before
	rec["remaining_after"] = remaining_yd()
	rec["stroke_count"] = stroke_count
	rec["finished"] = finished
	rec["gave_up"] = gave_up
	return rec


## ギブアップ（スコアは15扱い）
func give_up() -> void:
	stroke_count = MAX_STROKES
	finished = true
	gave_up = true


func score_diff() -> int:
	return stroke_count - par()


func score_label() -> String:
	if gave_up:
		return "ギブアップ"
	return label_for(stroke_count, par())


static func label_for(strokes: int, par_: int) -> String:
	if strokes == 1:
		return "ホールインワン"
	match strokes - par_:
		-3: return "アルバトロス"
		-2: return "イーグル"
		-1: return "バーディ"
		0: return "パー"
		1: return "ボギー"
		2: return "ダブルボギー"
		3: return "トリプルボギー"
		_:
			var d := strokes - par_
			return ("+%d" % d) if d > 0 else str(d)
