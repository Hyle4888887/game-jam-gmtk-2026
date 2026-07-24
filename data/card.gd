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


## One of these three is used as the default face-down texture (see
## CardView) - Blue is the neutral pick; Death and Green are also in the art
## pack if a different back ever suits a specific moment.
const DEFAULT_BACK_TEXTURE := "res://asset/Cards/Back/BackCardBlue.png"

const FACE_EXTENSIONS := [".png", ".jpg"]


func _to_string() -> String:
	return "%s of %s" % [rank_label(rank), SUIT_FOLDER[suit]]


## Maps to the jam's art asset filenames, trying both extensions in use
## (some ranks are .png, some are .jpg). NOTE: the art pass is still in
## progress as of 2026-07-24 - Spade and Clover currently have NO face art at
## all, and Heart/Diamond are each missing their Ace (Heart is also missing
## its 2). Returns "" when no face art exists yet for this card; callers
## (CardView) should fall back to DEFAULT_BACK_TEXTURE rather than crash, so
## rendering keeps working as the art pack fills in.
func texture_path() -> String:
	var folder: String = SUIT_FOLDER[suit]
	var prefix: String = rank_label(rank)
	var base := "res://asset/Cards/%s/%s%s" % [folder, prefix, folder]
	for ext in FACE_EXTENSIONS:
		var path: String = base + ext
		# FileAccess.file_exists checks the actual res:// file, unlike
		# ResourceLoader.exists() which can return a stale true from
		# .godot/imported/'s cached import DB after a source file is deleted
		# but the editor hasn't been reopened to invalidate that cache.
		if FileAccess.file_exists(path):
			return path
	return ""


func has_face_art() -> bool:
	return texture_path() != ""
