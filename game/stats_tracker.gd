class_name StatsTracker
extends RefCounted

## Per-day metrics keyed by prisoner id, feeding QuestManager evaluation.
## See graphify/Design - Rules.md §6 and graphify/Architecture - Systems.md.

const METRIC_KEYS := [
	"most_hands_won",
	"highest_combo",
	"most_of_a_suit",
	"biggest_single_pot",
	"most_years_shed",
	"most_folds",
	"richest_gambler",
]

var day_stats: Dictionary = {}


func reset_day(prisoners: Array) -> void:
	day_stats = {}
	for p in prisoners:
		var fresh := {}
		for key in METRIC_KEYS:
			fresh[key] = 0
		day_stats[p.id] = fresh


## Feeds one resolved hand's outcome into the day's running metrics.
## `all_prisoners` is the full seat list that took part in this hand
## (folded and showdown alike).
func record_hand(log: PokerEngine.HandResultLog, all_prisoners: Array) -> void:
	var pot := 0
	for p in all_prisoners:
		pot += int(log.contributions.get(p, 0))

	var winner_set := {}
	for w in log.winners:
		winner_set[w] = true

	for p in all_prisoners:
		var stats: Dictionary = day_stats[p.id]
		var contrib: int = int(log.contributions.get(p, 0))
		stats["richest_gambler"] += contrib

		if p.folded:
			stats["most_folds"] += 1

		var delta: int = int(log.sentence_deltas.get(p, 0))
		if delta < 0:
			stats["most_years_shed"] += -delta

		if winner_set.has(p):
			stats["most_hands_won"] += 1
			if pot > stats["biggest_single_pot"]:
				stats["biggest_single_pot"] = pot
			if log.hand_result != null:
				if log.hand_result.category > stats["highest_combo"]:
					stats["highest_combo"] = log.hand_result.category
				var suit_count := _max_suit_count(log.hand_result.cards)
				if suit_count > stats["most_of_a_suit"]:
					stats["most_of_a_suit"] = suit_count


func metric(prisoner_id: int, key: String) -> int:
	return int(day_stats.get(prisoner_id, {}).get(key, 0))


static func _max_suit_count(cards: Array) -> int:
	var counts := {}
	for c in cards:
		counts[c.suit] = int(counts.get(c.suit, 0)) + 1
	var max_count := 0
	for key in counts.keys():
		if counts[key] > max_count:
			max_count = counts[key]
	return max_count
