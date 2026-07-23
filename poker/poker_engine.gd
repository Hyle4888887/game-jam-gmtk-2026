class_name PokerEngine
extends RefCounted

## Result of playing one hand end to end, including the bet-to-lose sentence
## resolution (graphify/Design - Rules.md §3).
class HandResultLog:
	var community: Array[Card] = []
	var contributions: Dictionary = {}
	var folded_players: Array = []
	var winners: Array = []
	var hand_result: HandEvaluator.HandResult = null
	## prisoner -> signed change applied to sentence_years this hand.
	var sentence_deltas: Dictionary = {}


## Plays one hand of Hold'em for `active_prisoners` (already alive/seated,
## in table order). `dealer_index` is an index into active_prisoners.
## `action_source` must implement decide(...) per BettingRound.
static func play_hand(
	active_prisoners: Array,
	blinds: Dictionary,
	rng_service,
	action_source,
	dealer_index: int = 0
) -> HandResultLog:
	for p in active_prisoners:
		p.reset_for_hand()

	var deck := Deck.new()
	deck.shuffle(rng_service)

	var n := active_prisoners.size()
	var ante: int = blinds.get("ante", 0)
	var small_blind: int = blinds.get("small_blind", 0)
	var big_blind: int = blinds.get("big_blind", 0)

	for p in active_prisoners:
		p.contribution += ante

	var sb_index := (dealer_index + 1) % n
	var bb_index := (dealer_index + 2) % n
	var sb_player = active_prisoners[sb_index]
	var bb_player = active_prisoners[bb_index]

	var street_bets := {}
	street_bets[sb_player] = small_blind
	sb_player.contribution += small_blind
	street_bets[bb_player] = big_blind
	bb_player.contribution += big_blind

	for p in active_prisoners:
		p.deal_hole(deck.draw(), deck.draw())

	var preflop_order := _order_from(active_prisoners, (bb_index + 1) % n)
	BettingRound.run_street(preflop_order, street_bets, big_blind, big_blind, action_source, [], "preflop")

	var community: Array[Card] = []
	var postflop_order := _order_from(active_prisoners, sb_index)

	if BettingRound.count_active(active_prisoners) > 1:
		deck.burn()
		community.append(deck.draw())
		community.append(deck.draw())
		community.append(deck.draw())
		BettingRound.run_street(postflop_order, {}, 0, big_blind, action_source, community, "flop")

	if BettingRound.count_active(active_prisoners) > 1:
		deck.burn()
		community.append(deck.draw())
		BettingRound.run_street(postflop_order, {}, 0, big_blind, action_source, community, "turn")

	if BettingRound.count_active(active_prisoners) > 1:
		deck.burn()
		community.append(deck.draw())
		BettingRound.run_street(postflop_order, {}, 0, big_blind, action_source, community, "river")

	var log := HandResultLog.new()
	log.community = community
	for p in active_prisoners:
		log.contributions[p] = p.contribution
		if p.folded:
			log.folded_players.append(p)

	var contenders: Array = []
	for p in active_prisoners:
		if not p.folded:
			contenders.append(p)

	if contenders.size() == 1:
		log.winners = [contenders[0]]
		log.hand_result = null
	else:
		var best_result: HandEvaluator.HandResult = null
		var winners: Array = []
		for p in contenders:
			var seven: Array[Card] = []
			seven.append_array(p.hole_cards)
			seven.append_array(community)
			var result := HandEvaluator.evaluate_best(seven)
			if best_result == null or HandEvaluator.compare(result, best_result) > 0:
				best_result = result
				winners = [p]
			elif HandEvaluator.compare(result, best_result) == 0:
				winners.append(p)
		log.winners = winners
		log.hand_result = best_result

	# --- Bet-to-lose resolution (graphify/Design - Rules.md §3) ---
	# Winners (including a win-by-everyone-else-folded) erase their own
	# contribution from sentence_years; every other prisoner who put years in
	# this hand (folded early or lost at showdown) has loss_penalty_factor *
	# that contribution added as a penalty (see RunConfig.loss_penalty_factor
	# for why this is scaled down rather than a full 1:1 add). Win-by-fold is
	# resolved the same as a showdown win since there's no runner-up hand to
	# compare against, and it keeps the core loop consistent: sentence only
	# goes down by winning, never by folding safely.
	var winner_set := {}
	for w in log.winners:
		winner_set[w] = true
	var loss_penalty_factor: float = blinds.get("loss_penalty_factor", 1.0)

	for p in active_prisoners:
		var delta: int = -p.contribution if winner_set.has(p) else int(round(p.contribution * loss_penalty_factor))
		var old_sentence: int = p.sentence_years
		p.sentence_years += delta
		log.sentence_deltas[p] = delta
		if delta != 0:
			GameManager.sentence_changed.emit(p.id, old_sentence, p.sentence_years)

	GameManager.hand_resolved.emit(log)

	return log


static func _order_from(players: Array, start_index: int) -> Array:
	var n := players.size()
	var order := []
	for i in range(n):
		order.append(players[(start_index + i) % n])
	return order
