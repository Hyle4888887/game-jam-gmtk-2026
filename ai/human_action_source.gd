class_name HumanActionSource
extends RefCounted

## Player-facing action source: shows the legal actions on the HUD and
## suspends until the player presses a button. Conforms to the same
## decide(...) interface every other action_source uses (see
## poker/betting_round.gd) - BettingRound calls it with `await`, so this is
## the one implementation that actually needs to.

var hud: HUDView


func _init(p_hud: HUDView) -> void:
	hud = p_hud


func decide(_prisoner, legal_actions: Array, to_call: float, min_raise: float, context: Dictionary = {}) -> Dictionary:
	hud.set_legal_actions(legal_actions, to_call, min_raise, float(context.get("pot", 0)))
	var action: Dictionary = await hud.action_chosen
	hud.hide_actions()
	return action
