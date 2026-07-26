class_name HandResultPopup
extends Control

## Styled "WINNER IS ..." announcement shown at the end of every hand, so a
## result actually reads as an event instead of a label quietly changing in
## the corner. Previously this was just a plain top-of-screen label that
## GameView._on_hand_started wiped almost instantly, since the day loop
## moved straight to the next hand with no pause - see GameManager.start_run's
## wait_for_hand_result_ack, which now blocks the day loop (no timeout) until
## the player presses any mouse/keyboard button, so this popup genuinely
## stays up until it's been read instead of the next hand's own
## _on_hand_started hiding it again on a fixed timer.
##
## Positioned in the thin strip at the very top of the screen - not dead
## center like a real modal, and no full-screen dim - since that's exactly
## the moment TableView.highlight_winning_cards() is tinting the winning
## combo right there on the table, so covering the middle of the screen
## would hide the very thing the popup is announcing.
##
## Sitting a bit lower (e.g. vp.y*0.1, tall enough for 2 comfortable lines)
## still isn't safe: TableView's 7-seat ellipse packs seats close enough to
## the top that its two topmost seats' boxes start at ~0.109*vp.y (seat
## index 3/4 of 7, the two nearest theta=3PI/2 - see TableView._layout_seats'
## radius/SEAT_SIZE math) - a showdown winner sitting in one of those two
## seats had their own hole cards hidden by the popup, exactly the thing
## this is supposed to announce. Nothing in the ellipse encroaches above
## that line, so this has to be short enough to end before it, not just
## start below TableView.info_label.
const PANEL_SIZE := Vector2(460, 54)

var _panel: Panel
var _winner_label: Label
var _detail_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE, not STOP - this is a passive announcement, not a decision the
	# player needs to dismiss; it shouldn't eat clicks meant for anything else
	# that becomes interactive again once it's hidden.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = Panel.new()
	_panel.z_index = 91
	# NOT set_anchors_preset(PRESET_CENTER) + a manual position offset - that
	# combination zeroes the panel's offsets against whatever .size happened
	# to be at that instant (0x0, since custom_minimum_size alone never grows
	# a non-Container control's actual .size), so the "centered" rect stayed
	# zero-sized and effectively pinned at the top-left. Compute size/position
	# from the real viewport directly instead, same as RulesPanelView._layout.
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.55, 0.25)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	_panel.add_child(vbox)

	_winner_label = Label.new()
	_winner_label.add_theme_font_size_override("font_size", 18)
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_winner_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_detail_label)

	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")
	# Belt-and-suspenders for the same first-frame-viewport-not-resolved-yet
	# case documented on TableView._layout_seats/RulesPanelView._layout.
	get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)

	visible = false


## Fixed small pixel margin from the very top edge, not a fraction of vp.y -
## this needs to sit as close to y=0 as legibly possible (see PANEL_SIZE's
## comment on why even vp.y*0.1 wasn't safe), and TableView's seat/card
## layout is itself expressed in fixed pixels against the project's design
## resolution (SEAT_SIZE, CARD_SIZE, etc. - canvas_items stretch keeps that
## logical space consistent across real screen sizes), so this matches that
# same convention rather than scaling independently.
const TOP_MARGIN := 6.0


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		vp = Vector2(1152, 648)
	_panel.position = Vector2((vp.x - PANEL_SIZE.x) / 2.0, TOP_MARGIN)


## `winner_names` supports split pots (a tie erases each tied winner's own
## contribution equally, per graphify/Design - Rules.md §3). `category_text`
## is null for a win-by-everyone-else-folded (no showdown, nothing to
## compare hands against).
func show_result(winner_names: Array, category_text) -> void:
	var names_text: String = ", ".join(winner_names)
	_winner_label.text = "WINNER IS %s" % names_text
	if category_text != null:
		_detail_label.text = "won with %s" % category_text
	else:
		_detail_label.text = "won (everyone else folded)"
	visible = true


func hide_result() -> void:
	visible = false
