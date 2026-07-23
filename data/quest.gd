class_name Quest
extends Resource

## Daily "anti-quest" used for the 2nd execution slot each day.
## See graphify/Design - Rules.md §6.

enum Pick { MAX, MIN }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Key looked up in StatsTracker's per-day metrics dictionary.
@export var metric_key: String = ""
@export var pick: Pick = Pick.MAX


## The starting pool from graphify/Design - Rules.md §6.
static func default_pool() -> Array[Quest]:
	var pool: Array[Quest] = []
	pool.append(_make("most_hands_won", "The Overachiever", "Won the most hands today.", "most_hands_won", Pick.MAX))
	pool.append(_make("highest_combo", "The Showoff", "Showed the single highest-ranked hand category in a win today.", "highest_combo", Pick.MAX))
	pool.append(_make("most_of_a_suit", "The Flush Fanatic", "Won a hand using the most cards of one suit today.", "most_of_a_suit", Pick.MAX))
	pool.append(_make("biggest_single_pot", "The High Roller", "Won the single largest pot today.", "biggest_single_pot", Pick.MAX))
	pool.append(_make("most_years_shed", "The Runaway", "Reduced their own sentence the most today.", "most_years_shed", Pick.MAX))
	pool.append(_make("most_folds", "The Coward", "Folded the most today.", "most_folds", Pick.MAX))
	pool.append(_make("richest_gambler", "The Gambler", "Wagered the most years total today.", "richest_gambler", Pick.MAX))
	return pool


static func _make(id: String, display_name: String, description: String, metric_key: String, pick: Pick) -> Quest:
	var q := Quest.new()
	q.id = id
	q.display_name = display_name
	q.description = description
	q.metric_key = metric_key
	q.pick = pick
	return q
