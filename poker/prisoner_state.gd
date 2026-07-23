class_name PrisonerState
extends RefCounted

var id: int
var display_name: String
var is_player: bool = false
var seat: int = -1
var sentence_years: int = 0
var is_alive: bool = true
var ai_profile: AIProfile = null

## Per-hand state, reset by reset_for_hand() at the start of every hand.
var hole_cards: Array[Card] = []
var contribution: int = 0
var folded: bool = false

## Per-day stats, reset by StatsTracker at the start of every day (M5).
var day_stats: Dictionary = {}


func _init(p_id: int, p_name: String, p_sentence: int, p_is_player: bool = false) -> void:
	id = p_id
	display_name = p_name
	sentence_years = p_sentence
	is_player = p_is_player


func reset_for_hand() -> void:
	hole_cards = []
	contribution = 0
	folded = false


## Assigning a bare Array literal to a typed Array[Card] property fails at
## runtime when done through a dynamically-typed (Variant) reference, so
## callers outside this class must go through this method rather than
## setting hole_cards directly.
func deal_hole(first: Card, second: Card) -> void:
	hole_cards = [first, second]


func _to_string() -> String:
	return "%s(#%d, %dy)" % [display_name, id, sentence_years]
