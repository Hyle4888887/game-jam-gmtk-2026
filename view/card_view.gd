class_name CardView
extends TextureRect

## Renders one Card face-up or face-down. Falls back to
## Card.DEFAULT_BACK_TEXTURE whenever the card is face-down OR its face art
## doesn't exist yet (see Card.texture_path() - Spade/Clover currently have
## none, Heart/Diamond are each missing an Ace), so this keeps working as the
## art pack fills in without any code changes.
##
## A revealed card with no art would otherwise render identically to a
## genuinely hidden one (both fall back to the same back texture) - that's
## confusing, so a text fallback ("10D", "AH", ...) overlays the back texture
## whenever a card is face-up but has no art yet, so it's still readable.

enum ResultTint { NONE, WINNER, LOSER }

const HIGHLIGHT_TINT := Color(1.3, 1.15, 0.55)
const NORMAL_TINT := Color(1, 1, 1)
const DARK_TINT := Color(0.35, 0.35, 0.35)

var card: Card = null
var face_up: bool = true

var _fallback_label: Label


func _ready() -> void:
	_fallback_label = Label.new()
	_fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback_label.add_theme_font_size_override("font_size", 22)
	_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback_label)
	_update_texture()


func set_card(p_card: Card, p_face_up: bool = true) -> void:
	card = p_card
	face_up = p_face_up
	_update_texture()


func set_face_up(p_face_up: bool) -> void:
	face_up = p_face_up
	_update_texture()


## A genuinely empty slot (e.g. a community card not dealt yet) - distinct
## from a face-down card, which still has a back texture.
func clear() -> void:
	card = null
	face_up = true
	_update_texture()


## WINNER = golden tint (this card was part of the winning hand), LOSER =
## darkened (everything else, once a hand resolves and hands are revealed),
## NONE = normal. See TableView.highlight_winning_cards/clear_highlights.
func set_result_tint(state: ResultTint) -> void:
	match state:
		ResultTint.WINNER:
			modulate = HIGHLIGHT_TINT
		ResultTint.LOSER:
			modulate = DARK_TINT
		_:
			modulate = NORMAL_TINT


func _update_texture() -> void:
	# Any new card assignment (set_card/clear) resets a leftover highlight
	# from a previous hand's showdown - it only re-applies via an explicit
	# set_highlighted(true) call after the next hand actually resolves.
	modulate = NORMAL_TINT
	if card == null:
		texture = null
		if _fallback_label != null:
			_fallback_label.visible = false
		return

	if face_up and card.has_face_art():
		texture = load(card.texture_path())
		if _fallback_label != null:
			_fallback_label.visible = false
		return

	texture = load(Card.DEFAULT_BACK_TEXTURE)
	if _fallback_label != null:
		_fallback_label.visible = face_up
		if face_up:
			_fallback_label.text = "%s%s" % [Card.rank_label(card.rank), Card.SUIT_FOLDER[card.suit].left(1)]
