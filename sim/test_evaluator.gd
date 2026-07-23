extends SceneTree

# Headless assertion suite for HandEvaluator. Run via:
#   godot --headless --path . --script res://sim/test_evaluator.gd
# Exits with code 1 if any assertion fails, 0 if all pass.

var failures := 0


func _initialize() -> void:
	_run_all()
	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		quit(1)
	else:
		print("PASSED: all evaluator assertions ok")
		quit(0)


func _c(suit: int, rank: int) -> Card:
	return Card.new(suit, rank)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _cat(cards: Array) -> int:
	var typed: Array[Card] = []
	for c in cards:
		typed.append(c)
	return HandEvaluator.evaluate_best(typed).category


func _run_all() -> void:
	var H = Card.Suit.HEART
	var S = Card.Suit.SPADE
	var D = Card.Suit.DIAMOND
	var C = Card.Suit.CLOVER

	# --- Category detection, 7-card hands (2 hole + 5 community) ---

	_check(
		_cat([_c(H, 9), _c(H, 10), _c(H, 11), _c(H, 12), _c(H, 13), _c(S, 2), _c(D, 3)])
			== HandEvaluator.Category.STRAIGHT_FLUSH,
		"straight flush beats everything"
	)

	_check(
		_cat([_c(H, 5), _c(S, 5), _c(D, 5), _c(C, 5), _c(H, 2), _c(S, 3), _c(D, 4)])
			== HandEvaluator.Category.FOUR_OF_A_KIND,
		"four of a kind detected"
	)

	_check(
		_cat([_c(H, 8), _c(S, 8), _c(D, 8), _c(C, 4), _c(H, 4), _c(S, 2), _c(D, 9)])
			== HandEvaluator.Category.FULL_HOUSE,
		"full house detected (trips + pair)"
	)

	_check(
		_cat([_c(H, 2), _c(H, 5), _c(H, 9), _c(H, 11), _c(H, 13), _c(S, 3), _c(D, 4)])
			== HandEvaluator.Category.FLUSH,
		"flush detected (non-sequential same suit)"
	)

	_check(
		_cat([_c(H, 4), _c(S, 5), _c(D, 6), _c(C, 7), _c(H, 8), _c(S, 2), _c(D, 12)])
			== HandEvaluator.Category.STRAIGHT,
		"straight detected (mixed suits)"
	)

	# wheel straight: A-2-3-4-5, ace plays low
	_check(
		_cat([_c(H, 14), _c(S, 2), _c(D, 3), _c(C, 4), _c(H, 5), _c(S, 9), _c(D, 11)])
			== HandEvaluator.Category.STRAIGHT,
		"wheel straight (A-2-3-4-5) detected"
	)

	_check(
		_cat([_c(H, 9), _c(S, 9), _c(D, 9), _c(C, 2), _c(H, 5), _c(S, 7), _c(D, 11)])
			== HandEvaluator.Category.THREE_OF_A_KIND,
		"three of a kind detected"
	)

	_check(
		_cat([_c(H, 9), _c(S, 9), _c(D, 4), _c(C, 4), _c(H, 5), _c(S, 7), _c(D, 11)])
			== HandEvaluator.Category.TWO_PAIR,
		"two pair detected"
	)

	_check(
		_cat([_c(H, 9), _c(S, 9), _c(D, 4), _c(C, 6), _c(H, 5), _c(S, 7), _c(D, 11)])
			== HandEvaluator.Category.PAIR,
		"one pair detected"
	)

	_check(
		_cat([_c(H, 2), _c(S, 5), _c(D, 9), _c(C, 11), _c(H, 13), _c(S, 7), _c(D, 3)])
			== HandEvaluator.Category.HIGH_CARD,
		"high card detected (nothing else)"
	)

	# --- Straight flush must be picked over a same-cards' plain flush/straight ---
	_check(
		_cat([_c(H, 2), _c(H, 3), _c(H, 4), _c(H, 5), _c(H, 6), _c(S, 6), _c(D, 6)])
			== HandEvaluator.Category.STRAIGHT_FLUSH,
		"straight flush found even alongside trips in the same 7 cards"
	)

	# --- Kicker / tie-break comparisons ---

	var pair_aces_king_kicker: Array[Card] = [_c(H, 14), _c(S, 14), _c(D, 13), _c(C, 9), _c(H, 5)]
	var pair_aces_queen_kicker: Array[Card] = [_c(H, 14), _c(D, 14), _c(S, 12), _c(C, 9), _c(H, 5)]
	# pad to 7 cards each with distinct low filler so best-5 stays the pair line
	pair_aces_king_kicker.append(_c(S, 2))
	pair_aces_king_kicker.append(_c(D, 3))
	pair_aces_queen_kicker.append(_c(H, 2))
	pair_aces_queen_kicker.append(_c(S, 3))

	var r1 := HandEvaluator.evaluate_best(pair_aces_king_kicker)
	var r2 := HandEvaluator.evaluate_best(pair_aces_queen_kicker)
	_check(
		HandEvaluator.compare(r1, r2) == 1,
		"pair of aces w/ king kicker beats pair of aces w/ queen kicker"
	)

	# full house vs flush: full house must win regardless of flush's high cards
	var full_house_low: Array[Card] = [_c(H, 3), _c(S, 3), _c(D, 3), _c(C, 2), _c(H, 2), _c(S, 9), _c(D, 11)]
	var flush_high: Array[Card] = [_c(H, 2), _c(H, 6), _c(H, 9), _c(H, 12), _c(H, 13), _c(S, 4), _c(D, 5)]
	_check(
		HandEvaluator.compare(HandEvaluator.evaluate_best(full_house_low), HandEvaluator.evaluate_best(flush_high)) == 1,
		"full house (low cards) beats flush (high cards)"
	)

	# --- Split pot / exact tie ---
	var board_straight_a: Array[Card] = [_c(H, 4), _c(S, 5), _c(D, 6), _c(C, 7), _c(H, 8), _c(S, 2), _c(D, 3)]
	var board_straight_b: Array[Card] = [_c(D, 4), _c(H, 5), _c(S, 6), _c(H, 7), _c(D, 8), _c(C, 2), _c(S, 3)]
	_check(
		HandEvaluator.compare(HandEvaluator.evaluate_best(board_straight_a), HandEvaluator.evaluate_best(board_straight_b)) == 0,
		"identical straights on different suits tie exactly"
	)

	# --- Category ordering sanity across the board ---
	var order := [
		HandEvaluator.Category.HIGH_CARD,
		HandEvaluator.Category.PAIR,
		HandEvaluator.Category.TWO_PAIR,
		HandEvaluator.Category.THREE_OF_A_KIND,
		HandEvaluator.Category.STRAIGHT,
		HandEvaluator.Category.FLUSH,
		HandEvaluator.Category.FULL_HOUSE,
		HandEvaluator.Category.FOUR_OF_A_KIND,
		HandEvaluator.Category.STRAIGHT_FLUSH,
	]
	var strictly_increasing := true
	for i in range(order.size() - 1):
		if order[i] >= order[i + 1]:
			strictly_increasing = false
	_check(strictly_increasing, "Category enum ordering matches poker hand ranking")
