class_name PacedActionSource
extends RefCounted

## Wraps another action_source and adds a real-time delay AFTER it decides
## (so the action already resolved and the table already reflects it) before
## returning, so a human watching AI turns actually gets time to see each
## one happen instead of a whole betting round resolving instantly.
##
## The delay is cut short the moment GameManager.skip_requested fires (any
## mouse/keyboard press - see GameView._unhandled_input), so a player who
## wants to blow through a hand faster than the default pacing can just
## click/press a key through it instead of waiting out every AI turn.
##
## Deliberately NOT used by the M7 balance harness or any automated test -
## only by the interactive GameView. A multi-second delay per decision would
## make batch simulation (1000 runs x up to 7 days x 15 hands x several
## decisions/hand) take hours instead of minutes.

var inner
var delay_seconds: float


func _init(p_inner, p_delay_seconds: float = 5.0) -> void:
	inner = p_inner
	delay_seconds = p_delay_seconds


func decide(prisoner, legal_actions: Array, to_call: float, min_raise: float, context: Dictionary = {}) -> Dictionary:
	var action: Dictionary = await inner.decide(prisoner, legal_actions, to_call, min_raise, context)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await _wait_or_skip(tree, delay_seconds)
	return action


## Waits up to `seconds` (real time; process_always=false so it respects a
## real pause - ESC menu - same as before), but returns early the moment
## GameManager.skip_requested fires. Polls time_left each frame rather than
## racing two `await`s directly - GDScript can only await one signal/timer at
## a time per expression, so this is the straightforward way to wait on
## "whichever of these two happens first".
##
## Always awaits at least one process_frame, even when `seconds` is 0.0 (used
## by every automated test) - a naive `while timer.time_left > 0.0: await ...`
## would skip the loop body entirely when time_left starts at exactly 0, so
## decide() would never genuinely suspend. Chaining enough zero-delay
## decisions like that back to back can run a whole betting round (or more)
## synchronously in one call stack before ever yielding control back to the
## caller - which silently breaks any test harness that connects a signal
## right after add_child() expecting to catch the *next* emission, since
## everything up to the first real suspend point (a human decision awaiting
## a signal) has already fired before that connection registers.
static func _wait_or_skip(tree: SceneTree, seconds: float) -> void:
	var timer := tree.create_timer(seconds, false)
	# A lambda mutating a plain outer local wouldn't be visible here - GDScript
	# captures locals by value snapshot, not by reference - so a 1-element
	# Array is used as a mutable box instead (see sim/test_pause.gd for the
	# same pattern hit before).
	var skipped := [false]
	var on_skip := func(): skipped[0] = true
	GameManager.skip_requested.connect(on_skip)
	while true:
		await tree.process_frame
		if timer.time_left <= 0.0 or skipped[0]:
			break
	GameManager.skip_requested.disconnect(on_skip)


func observe_action(prisoner_id: int, action: Dictionary) -> void:
	if inner.has_method("observe_action"):
		inner.observe_action(prisoner_id, action)
