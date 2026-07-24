class_name AIController
extends RefCounted

## v1 heuristic action source: estimates hand strength (a simplified
## Chen-style score preflop, HandEvaluator category postflop) and combines it
## with the prisoner's AIProfile to pick fold/check/call/raise. Conforms to
## the action_source interface used by BettingRound.run_street.
## See graphify/Architecture - Systems.md.

const DEFAULT_PROFILE_TIGHTNESS := 0.5


func decide(prisoner, legal_actions: Array, to_call: float, min_raise: float, context: Dictionary = {}) -> Dictionary:
	var profile: AIProfile = prisoner.ai_profile
	if profile == null:
		profile = AIProfile.shark()

	var community: Array = context.get("community", [])
	var strength: float
	if community.size() == 0:
		strength = _preflop_strength(prisoner.hole_cards)
	else:
		strength = _postflop_strength(prisoner.hole_cards, community)

	# Occasionally represent a stronger hand than held, scaled by bluff.
	if RNGService.randf() < profile.bluff * 0.3:
		strength = clampf(strength + 0.4, 0.0, 1.0)

	# Tighter players need more strength to keep contributing years.
	var continue_threshold: float = 0.15 + profile.tightness * 0.35
	# More aggressive players raise at a lower strength bar.
	var raise_threshold: float = 0.55 + (1.0 - profile.aggression) * 0.35

	if to_call > 0 and strength < continue_threshold and BettingRound.Action.FOLD in legal_actions:
		return {"type": BettingRound.Action.FOLD}

	if strength >= raise_threshold and BettingRound.Action.RAISE in legal_actions:
		# Sized off the day's stable big_blind, NOT the pot or min_raise -
		# both of those escalate with every re-raise in the same street, and
		# pot-based sizing would compound into a runaway feedback loop since
		# sentence_years has no finite "stack" to cap it (see betting_round.gd).
		var big_blind: float = context.get("big_blind", min_raise)
		var size_factor: float = 0.5 + profile.aggression + profile.risk * 0.5
		var raise_amount: float = max(min_raise, big_blind * size_factor)
		return {"type": BettingRound.Action.RAISE, "amount": raise_amount}

	if BettingRound.Action.CHECK in legal_actions:
		return {"type": BettingRound.Action.CHECK}

	return {"type": BettingRound.Action.CALL}


## Simplified Chen-style score in [0,1]: high card, pair, suited and
## connector bonuses. Not exact Chen point values, just a cheap ordering.
static func _preflop_strength(hole: Array) -> float:
	var c1: Card = hole[0]
	var c2: Card = hole[1]
	var hi: int = max(c1.rank, c2.rank)
	var lo: int = min(c1.rank, c2.rank)
	var pair := c1.rank == c2.rank
	var suited := c1.suit == c2.suit

	var score: float
	if pair:
		score = 0.5 + float(hi - 2) / 12.0 * 0.5
	else:
		score = float(hi - 2) / 12.0 * 0.6
		score += float(lo - 2) / 12.0 * 0.15
		if suited:
			score += 0.05
		var gap := hi - lo
		if gap >= 1 and gap <= 4:
			score += 0.05 * float(5 - gap) / 4.0

	return clampf(score, 0.0, 1.0)


## HandEvaluator category mapped to [0,1], nudged by the top tiebreaker for
## granularity within the same category.
static func _postflop_strength(hole: Array, community: Array) -> float:
	var seven: Array[Card] = []
	seven.append_array(hole)
	seven.append_array(community)
	if seven.size() < 5:
		return _preflop_strength(hole)

	var result := HandEvaluator.evaluate_best(seven)
	var base := float(result.category) / float(HandEvaluator.Category.STRAIGHT_FLUSH)
	var nudge := 0.0
	if result.tiebreakers.size() > 0:
		nudge = (float(result.tiebreakers[0]) - 2.0) / 12.0 * 0.08
	return clampf(base + nudge, 0.0, 1.0)
