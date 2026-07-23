class_name MixedActionSource
extends RefCounted

## Dispatches to a different action source depending on PrisonerState.is_player,
## while presenting a single action_source to BettingRound/PokerEngine (which
## only ever expect one shared instance across the whole table). Used so the
## player seat can run ExploitiveAIController while AI opponents keep using
## the plain AIController the difficulty ramp is tuned against.

var player_source
var ai_source


func _init(p_player_source, p_ai_source) -> void:
	player_source = p_player_source
	ai_source = p_ai_source


func decide(prisoner, legal_actions: Array, to_call: int, min_raise: int, context: Dictionary = {}) -> Dictionary:
	if prisoner.is_player:
		return player_source.decide(prisoner, legal_actions, to_call, min_raise, context)
	return ai_source.decide(prisoner, legal_actions, to_call, min_raise, context)


func observe_action(prisoner_id: int, action: Dictionary) -> void:
	if player_source.has_method("observe_action"):
		player_source.observe_action(prisoner_id, action)
	if ai_source.has_method("observe_action"):
		ai_source.observe_action(prisoner_id, action)
