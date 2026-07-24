class_name HandEvaluator
extends RefCounted

enum Category {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
}

const CATEGORY_DISPLAY_NAMES := {
	Category.HIGH_CARD: "High Card",
	Category.PAIR: "Pair",
	Category.TWO_PAIR: "Two Pair",
	Category.THREE_OF_A_KIND: "Three of a Kind",
	Category.STRAIGHT: "Straight",
	Category.FLUSH: "Flush",
	Category.FULL_HOUSE: "Full House",
	Category.FOUR_OF_A_KIND: "Four of a Kind",
	Category.STRAIGHT_FLUSH: "Straight Flush",
}


static func category_display_name(category: int) -> String:
	return CATEGORY_DISPLAY_NAMES.get(category, "Unknown")


## Result of evaluating a hand: category, tiebreaker ranks in the order they
## should be compared (most significant first), and the specific 5 cards that
## make up this hand (needed e.g. for the "most of a suit" daily quest).
class HandResult:
	var category: int
	var tiebreakers: Array
	var cards: Array

	func _init(p_category: int, p_tiebreakers: Array, p_cards: Array = []) -> void:
		category = p_category
		tiebreakers = p_tiebreakers
		cards = p_cards

	func _to_string() -> String:
		return "%s %s" % [Category.keys()[category], tiebreakers]


## Best 5-card hand out of 5, 6 or 7 cards.
static func evaluate_best(cards: Array[Card]) -> HandResult:
	assert(cards.size() >= 5)
	var best: HandResult = null
	for combo in _combinations(cards, 5):
		var result := _evaluate_5(combo)
		if best == null or compare(result, best) > 0:
			best = result
	return best


## Returns 1 if a beats b, -1 if b beats a, 0 if exact tie.
static func compare(a: HandResult, b: HandResult) -> int:
	if a.category != b.category:
		return 1 if a.category > b.category else -1
	for i in range(a.tiebreakers.size()):
		var ta: int = a.tiebreakers[i]
		var tb: int = b.tiebreakers[i]
		if ta != tb:
			return 1 if ta > tb else -1
	return 0


static func _evaluate_5(cards: Array) -> HandResult:
	var ranks: Array = []
	for c in cards:
		ranks.append(c.rank)
	ranks.sort()
	ranks.reverse()

	var first_suit = cards[0].suit
	var is_flush := true
	for c in cards:
		if c.suit != first_suit:
			is_flush = false
			break

	var unique_ranks := {}
	for r in ranks:
		unique_ranks[r] = true

	var is_straight := false
	var straight_high := 0
	if unique_ranks.size() == 5:
		if ranks[0] == 14 and ranks[1] == 5 and ranks[2] == 4 and ranks[3] == 3 and ranks[4] == 2:
			# wheel: A-2-3-4-5, the Ace plays low so the straight is headed by 5
			is_straight = true
			straight_high = 5
		elif ranks[0] - ranks[4] == 4:
			is_straight = true
			straight_high = ranks[0]

	var count_map := {}
	for r in ranks:
		count_map[r] = count_map.get(r, 0) + 1

	# groups: [count, rank], sorted by count desc then rank desc
	var groups: Array = []
	for r in count_map.keys():
		groups.append([count_map[r], r])
	groups.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1] > b[1]
	)

	if is_straight and is_flush:
		return HandResult.new(Category.STRAIGHT_FLUSH, [straight_high], cards)

	if groups[0][0] == 4:
		return HandResult.new(Category.FOUR_OF_A_KIND, [groups[0][1], groups[1][1]], cards)

	if groups[0][0] == 3 and groups[1][0] == 2:
		return HandResult.new(Category.FULL_HOUSE, [groups[0][1], groups[1][1]], cards)

	if is_flush:
		return HandResult.new(Category.FLUSH, ranks.duplicate(), cards)

	if is_straight:
		return HandResult.new(Category.STRAIGHT, [straight_high], cards)

	if groups[0][0] == 3:
		var kickers := _kicker_ranks(groups, 1)
		return HandResult.new(Category.THREE_OF_A_KIND, [groups[0][1]] + kickers, cards)

	if groups[0][0] == 2 and groups[1][0] == 2:
		var pair_ranks := [groups[0][1], groups[1][1]]
		pair_ranks.sort()
		pair_ranks.reverse()
		var kicker: int = groups[2][1]
		return HandResult.new(Category.TWO_PAIR, pair_ranks + [kicker], cards)

	if groups[0][0] == 2:
		var kickers2 := _kicker_ranks(groups, 1)
		return HandResult.new(Category.PAIR, [groups[0][1]] + kickers2, cards)

	return HandResult.new(Category.HIGH_CARD, ranks.duplicate(), cards)


static func _kicker_ranks(groups: Array, min_count_exclusive_below: int) -> Array:
	var kickers: Array = []
	for g in groups:
		if g[0] <= min_count_exclusive_below:
			kickers.append(g[1])
	kickers.sort()
	kickers.reverse()
	return kickers


static func _combinations(items: Array, k: int) -> Array:
	var result: Array = []
	_combine_recursive(items, k, 0, [], result)
	return result


static func _combine_recursive(items: Array, k: int, start: int, current: Array, result: Array) -> void:
	if current.size() == k:
		result.append(current.duplicate())
		return
	for i in range(start, items.size()):
		current.append(items[i])
		_combine_recursive(items, k, i + 1, current, result)
		current.pop_back()
