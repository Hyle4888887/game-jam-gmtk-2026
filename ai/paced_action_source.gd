class_name PacedActionSource
extends RefCounted

## Wraps another action_source and adds a real-time delay AFTER it decides
## (so the action already resolved and the table already reflects it) before
## returning, so a human watching AI turns actually gets time to see each
## one happen instead of a whole betting round resolving instantly.
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
		# process_always=false: SceneTreeTimer defaults to ticking even while
		# the tree is paused, which would let AI turns keep resolving behind
		# the pause menu. false makes it a real pause instead.
		await tree.create_timer(delay_seconds, false).timeout
	return action


func observe_action(prisoner_id: int, action: Dictionary) -> void:
	if inner.has_method("observe_action"):
		inner.observe_action(prisoner_id, action)
