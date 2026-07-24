class_name CallStationActionSource
extends RefCounted

## Never folds, never raises: checks when free, otherwise calls. Used as the
## M2 placeholder action source and doubles as the behavior for the
## "Calling Station" AIProfile preset later (M4).


func decide(_prisoner, legal_actions: Array, _to_call: float, _min_raise: float, _context: Dictionary = {}) -> Dictionary:
	if BettingRound.Action.CHECK in legal_actions:
		return {"type": BettingRound.Action.CHECK}
	return {"type": BettingRound.Action.CALL}
