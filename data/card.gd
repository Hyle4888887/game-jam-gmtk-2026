class_name Card
extends Resource

## 2..10 = pip value, 11=J, 12=Q, 13=K, 14=A
enum Suit { HEART, SPADE, DIAMOND, CLOVER }

const SUIT_FOLDER := {
	Suit.HEART: "Heart",
	Suit.SPADE: "Spade",
	Suit.DIAMOND: "Diamond",
	Suit.CLOVER: "Clover",
}

const RANK_PREFIX := {
	11: "J",
	12: "Q",
	13: "K",
	14: "Ace",
}

@export var suit: Suit = Suit.HEART
@export var rank: int = 2


func _init(p_suit: Suit = Suit.HEART, p_rank: int = 2) -> void:
	suit = p_suit
	rank = p_rank


static func rank_label(rank: int) -> String:
	if RANK_PREFIX.has(rank):
		return RANK_PREFIX[rank]
	return str(rank)


func _to_string() -> String:
	return "%s of %s" % [rank_label(rank), SUIT_FOLDER[suit]]


## Best-effort mapping to the jam's art asset filenames. NOTE: the current
## art pass under res://asset/Cards is incomplete (most suits only have a
## handful of ranks, and Heart's "2" file is misspelled "2Hearth.png") so this
## path is not guaranteed to point at an existing file yet. Safe to call now
## since nothing renders it until the UI milestone.
func texture_path() -> String:
	var folder: String = SUIT_FOLDER[suit]
	var prefix: String = rank_label(rank)
	return "res://asset/Cards/%s/%s%s.png" % [folder, prefix, folder]
