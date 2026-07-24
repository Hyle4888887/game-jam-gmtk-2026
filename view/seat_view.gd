class_name SeatView
extends Control

## One prisoner's seat at the table: name, sentence-years readout, 2 hole
## cards, and dealer/folded/dead indicators. Builds its own children in code
## rather than a hand-authored .tscn tree - simpler to keep correct while the
## layout is still in flux.

const CARD_VIEW_SCENE := preload("res://view/card_view.tscn")
const CHIP_STACK_SCENE := preload("res://view/chip_stack_view.tscn")
const DEAD_ICON := "res://UI/icons/wood_cross.png"
const DEALER_ICON := "res://UI/icons/wood_star.png"

var name_label: Label
var sentence_label: TickingSentenceLabel
var hole_cards: Array = []
var dead_icon_view: TextureRect
var dealer_icon_view: TextureRect
var contribution_chips: ChipStackView
var action_label: Label
var blind_badge: Panel
var blind_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(120, 110)

	# Sibling of vbox (not inside it) so it can sit just above the seat's own
	# box via a negative position offset, rather than competing for space
	# inside the seat's own layout.
	action_label = Label.new()
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.custom_minimum_size = Vector2(120, 16)
	action_label.position = Vector2(0, -20)
	action_label.add_theme_font_size_override("font_size", 12)
	action_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(action_label)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_row)
	for i in range(2):
		var cv: CardView = CARD_VIEW_SCENE.instantiate()
		cards_row.add_child(cv)
		hole_cards.append(cv)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	sentence_label = TickingSentenceLabel.new()
	sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sentence_label)

	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(icon_row)

	dealer_icon_view = TextureRect.new()
	dealer_icon_view.texture = load(DEALER_ICON)
	dealer_icon_view.custom_minimum_size = Vector2(13, 13)
	dealer_icon_view.visible = false
	icon_row.add_child(dealer_icon_view)

	dead_icon_view = TextureRect.new()
	dead_icon_view.texture = load(DEAD_ICON)
	dead_icon_view.custom_minimum_size = Vector2(13, 13)
	dead_icon_view.visible = false
	icon_row.add_child(dead_icon_view)

	# Small colored badge for who's posting small/big blind this hand - no
	# dedicated "SB"/"BB" chip art exists, so this is a mini colored panel
	# with text, matching the placeholder-chip look used elsewhere.
	blind_badge = Panel.new()
	blind_badge.custom_minimum_size = Vector2(24, 16)
	var blind_style := StyleBoxFlat.new()
	blind_style.bg_color = Color(0.15, 0.45, 0.75)
	blind_style.set_corner_radius_all(4)
	blind_badge.add_theme_stylebox_override("panel", blind_style)
	blind_badge.visible = false
	icon_row.add_child(blind_badge)

	blind_label = Label.new()
	blind_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blind_label.add_theme_font_size_override("font_size", 10)
	blind_badge.add_child(blind_label)

	contribution_chips = CHIP_STACK_SCENE.instantiate()
	vbox.add_child(contribution_chips)


func set_prisoner_info(display_name: String, sentence_years: float) -> void:
	name_label.text = display_name
	# graphify/Design - Rules.md §1: sentence_years can genuinely go negative
	# mid-run (a big enough win overshoots 0) - that's fine for the win
	# check, but should clamp to 0 for display so it doesn't read as broken.
	sentence_label.set_years(sentence_years)


func set_contribution(years: float) -> void:
	contribution_chips.set_amount(years)


func set_hole_cards(cards: Array, face_up: bool) -> void:
	for i in range(hole_cards.size()):
		var cv: CardView = hole_cards[i]
		if i < cards.size():
			cv.set_card(cards[i], face_up)
			cv.visible = true
		else:
			cv.visible = false


func set_folded(folded: bool) -> void:
	modulate = Color(1, 1, 1, 0.4) if folded else Color(1, 1, 1, 1)


func set_dealer(is_dealer: bool) -> void:
	dealer_icon_view.visible = is_dealer


## `role` is "SB", "BB", or "" for neither.
func set_blind_role(role: String) -> void:
	blind_label.text = role
	blind_badge.visible = role != ""


func set_dead(is_dead: bool) -> void:
	dead_icon_view.visible = is_dead
	if is_dead:
		modulate = Color(0.5, 0.1, 0.1, 0.6)


func set_action_text(text: String) -> void:
	action_label.text = text


func clear_action_text() -> void:
	action_label.text = ""
