class_name GameStateMachine
extends RefCounted
## ゲーム状態遷移（設計書 6.2）。不正な遷移は拒否して false を返す。

enum S {
	BOOT, TITLE, HOLE_LOADING, PROMPT_READY, INPUT_VALIDATE, SHOT_LOCKED, SWING_ANIMATION,
	BALL_FLIGHT, LANDING_RESOLVE, PENALTY_ANIMATION, HOLE_RESULT, ROUND_RESULT, PAUSE,
}

const ALLOWED := {
	S.BOOT: [S.TITLE, S.HOLE_LOADING],
	S.TITLE: [S.HOLE_LOADING],
	S.HOLE_LOADING: [S.PROMPT_READY],
	S.PROMPT_READY: [S.INPUT_VALIDATE, S.HOLE_RESULT],  # HOLE_RESULT: ギブアップ
	S.INPUT_VALIDATE: [S.PROMPT_READY, S.SHOT_LOCKED],
	S.SHOT_LOCKED: [S.SWING_ANIMATION],
	S.SWING_ANIMATION: [S.BALL_FLIGHT],
	S.BALL_FLIGHT: [S.LANDING_RESOLVE],
	S.LANDING_RESOLVE: [S.PENALTY_ANIMATION, S.PROMPT_READY, S.HOLE_RESULT],
	S.PENALTY_ANIMATION: [S.PROMPT_READY, S.HOLE_RESULT],
	S.HOLE_RESULT: [S.HOLE_LOADING, S.ROUND_RESULT],
	S.ROUND_RESULT: [S.TITLE, S.HOLE_LOADING],
	S.PAUSE: [],
}

var state: int = S.BOOT
var _paused_from: int = -1


func can_go(to: int) -> bool:
	return ALLOWED.get(state, []).has(to)


func go(to: int) -> bool:
	if not can_go(to):
		push_warning("GameStateMachine: illegal %s -> %s" % [S.keys()[state], S.keys()[to]])
		return false
	state = to
	return true


## 任意の安定状態から一時停止。アニメーション中・確定処理中は不可。
func pause() -> bool:
	if state in [S.PROMPT_READY, S.HOLE_RESULT, S.ROUND_RESULT, S.TITLE]:
		_paused_from = state
		state = S.PAUSE
		return true
	return false


func resume() -> bool:
	if state == S.PAUSE and _paused_from >= 0:
		state = _paused_from
		_paused_from = -1
		return true
	return false


func name_of(s: int) -> String:
	return S.keys()[s]
