class_name BettingRound
extends RefCounted

enum Action { FOLD, CHECK, CALL, RAISE }

## Engine safety limit (not a balance knob): caps re-raises per street so a
## pathological action source can't loop the betting round forever.
const MAX_RAISES_PER_STREET := 6


static func legal_actions(to_call: int, raises_remaining: bool = true) -> Array:
	if to_call <= 0:
		return [Action.CHECK, Action.RAISE] if raises_remaining else [Action.CHECK]
	return [Action.FOLD, Action.CALL, Action.RAISE] if raises_remaining else [Action.FOLD, Action.CALL]


## Runs one betting street to completion. `active_players` is the full seat
## order for this street (folded players are skipped automatically); folded
## flags and per-hand contributions are mutated in place on each
## PrisonerState. `street_bets` maps prisoner -> amount already committed on
## this street alone (e.g. posted blinds preflop) and is mutated in place.
## `community` and `street_name` are read-only context for the action source
## (e.g. AIController needs the revealed community cards to judge strength).
## `action_source` must implement decide(prisoner, legal_actions, to_call,
## min_raise, context) -> {"type": Action, "amount": int (only for RAISE)},
## where context is {"community": Array[Card], "pot": int, "active_count":
## int, "street": String, "big_blind": int, "opponent_ids": Array[int]}.
## `big_blind` is the day's fixed blind level (== starting_min_raise), given
## as a stable sizing anchor since `pot` and `min_raise` both escalate within
## a raising war - an action source that sizes its raises off either of those
## compounds every re-raise and can blow up sentence_years to nonsense values
## within a single hand. `opponent_ids` lists everyone else still active in
## the hand (folded excluded), for opponent-modeling action sources.
##
## If `action_source` also implements observe_action(prisoner_id, action),
## it's called after every decided action at this table (including its own),
## so a stateful action source can build up opponent reads without needing a
## signal connection with its own lifecycle to manage.
static func run_street(
	active_players: Array,
	street_bets: Dictionary,
	starting_bet: int,
	starting_min_raise: int,
	action_source,
	community: Array = [],
	street_name: String = ""
) -> void:
	var current_bet := starting_bet
	var min_raise := starting_min_raise
	var big_blind := starting_min_raise
	var raise_count := 0

	var need_to_act: Array = []
	for p in active_players:
		if not p.folded:
			need_to_act.append(p)

	while need_to_act.size() > 0:
		var still_in := count_active(active_players)
		if still_in <= 1:
			break

		var player = need_to_act.pop_front()
		if player.folded:
			continue

		var already: int = street_bets.get(player, 0)
		var to_call: int = current_bet - already
		var legal := legal_actions(to_call, raise_count < MAX_RAISES_PER_STREET)
		var pot := 0
		for pl in active_players:
			pot += pl.contribution
		var opponent_ids: Array = []
		for pl in active_players:
			if pl != player and not pl.folded:
				opponent_ids.append(pl.id)
		var context := {
			"community": community,
			"pot": pot,
			"active_count": still_in,
			"street": street_name,
			"big_blind": big_blind,
			"opponent_ids": opponent_ids,
		}
		var action: Dictionary = action_source.decide(player, legal, to_call, min_raise, context)
		var action_type: int = action["type"]
		assert(action_type in legal, "action_source returned an action not in the legal set")
		if action_source.has_method("observe_action"):
			action_source.observe_action(player.id, action)

		match action_type:
			Action.FOLD:
				player.folded = true
			Action.CHECK:
				pass
			Action.CALL:
				street_bets[player] = already + to_call
				player.contribution += to_call
			Action.RAISE:
				var raise_amount: int = max(int(action.get("amount", min_raise)), min_raise)
				var new_total := current_bet + raise_amount
				var pay := new_total - already
				street_bets[player] = new_total
				player.contribution += pay
				current_bet = new_total
				min_raise = raise_amount
				raise_count += 1
				need_to_act.clear()
				for other in active_players:
					if other != player and not other.folded:
						need_to_act.append(other)


static func count_active(players: Array) -> int:
	var count := 0
	for p in players:
		if not p.folded:
			count += 1
	return count
