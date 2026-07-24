class_name HUDView
extends Control

## Bottom action bar: fold/check-call/raise buttons + a raise-amount slider
## with the usual quick-bet shortcuts (MIN / 1/2 POT / POT / MAX), themed
## with the pulled "wood" UI kit textures. Emits action_chosen with the same
## {"type":..., "amount":...} shape every action_source already uses, so
## HumanActionSource just awaits this signal.
##
## Built in code rather than a hand-authored .tscn - simpler to keep correct
## while the layout is still in flux.

signal action_chosen(action: Dictionary)

const BUTTON_MARGIN := 5
const PANEL_MARGIN := 10

var fold_button: Button
var check_call_button: Button
var raise_button: Button
var raise_slider: HSlider
var raise_amount_label: Label
var quick_bet_buttons: Array = []
var day_label: Label
var sentence_label: TickingSentenceLabel

var _current_to_call: float = 0.0
var _current_pot: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0, 84)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_stylebox("res://UI/panels/wood_panel.png", PANEL_MARGIN))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 14)
	sentence_label = TickingSentenceLabel.new()
	sentence_label.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(day_label)
	info_vbox.add_child(sentence_label)
	hbox.add_child(info_vbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var raise_vbox := VBoxContainer.new()
	raise_amount_label = Label.new()
	raise_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raise_amount_label.add_theme_font_size_override("font_size", 13)
	raise_vbox.add_child(raise_amount_label)

	var quick_bet_row := HBoxContainer.new()
	quick_bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_bet_row.add_theme_constant_override("separation", 4)
	for entry in [["MIN", _set_raise_to_min], ["1/2 POT", _set_raise_to_half_pot], ["POT", _set_raise_to_pot], ["MAX", _set_raise_to_max]]:
		var qb := _make_button(entry[0])
		qb.custom_minimum_size = Vector2(50, 24)
		qb.add_theme_font_size_override("font_size", 10)
		qb.pressed.connect(entry[1])
		quick_bet_row.add_child(qb)
		quick_bet_buttons.append(qb)
	raise_vbox.add_child(quick_bet_row)

	raise_slider = HSlider.new()
	raise_slider.custom_minimum_size = Vector2(160, 18)
	raise_slider.value_changed.connect(_on_slider_changed)
	raise_vbox.add_child(raise_slider)
	hbox.add_child(raise_vbox)

	fold_button = _make_button("FOLD")
	fold_button.pressed.connect(func(): action_chosen.emit({"type": BettingRound.Action.FOLD}))
	hbox.add_child(fold_button)

	check_call_button = _make_button("CHECK")
	check_call_button.pressed.connect(_on_check_call_pressed)
	hbox.add_child(check_call_button)

	raise_button = _make_button("RAISE")
	raise_button.pressed.connect(func(): action_chosen.emit({"type": BettingRound.Action.RAISE, "amount": raise_slider.value}))
	hbox.add_child(raise_button)

	hide_actions()


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 34)
	var normal := _make_stylebox("res://UI/buttons/wood_button_normal.png", BUTTON_MARGIN)
	var pressed := _make_stylebox("res://UI/buttons/wood_button_pressed.png", BUTTON_MARGIN)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	return b


func _make_stylebox(path: String, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	return sb


func _on_slider_changed(value: float) -> void:
	_update_raise_label(value)


func _update_raise_label(value: float) -> void:
	raise_amount_label.text = "Raise: %s" % TimeUnits.format_amount_best_unit(value)


func _set_raise_to_min() -> void:
	raise_slider.value = raise_slider.min_value


func _set_raise_to_half_pot() -> void:
	raise_slider.value = clampf(float(_current_pot) / 2.0, raise_slider.min_value, raise_slider.max_value)


func _set_raise_to_pot() -> void:
	raise_slider.value = clampf(float(_current_pot), raise_slider.min_value, raise_slider.max_value)


func _set_raise_to_max() -> void:
	raise_slider.value = raise_slider.max_value


func _on_check_call_pressed() -> void:
	if _current_to_call > 0:
		action_chosen.emit({"type": BettingRound.Action.CALL})
	else:
		action_chosen.emit({"type": BettingRound.Action.CHECK})


## Configures the bar for one decision. `legal` is the Array of
## BettingRound.Action values currently allowed for this player. `pot`
## drives the 1/2 POT and POT quick-bet buttons.
func set_legal_actions(legal: Array, to_call: float, min_raise: float, pot: float = 0.0) -> void:
	visible = true
	_current_to_call = to_call
	_current_pot = pot

	fold_button.visible = BettingRound.Action.FOLD in legal

	var can_check_or_call: bool = (BettingRound.Action.CHECK in legal) or (BettingRound.Action.CALL in legal)
	check_call_button.visible = can_check_or_call
	if to_call > 0:
		check_call_button.text = "CALL %s" % TimeUnits.format_amount_best_unit(to_call)
	else:
		check_call_button.text = "CHECK"

	var can_raise: bool = BettingRound.Action.RAISE in legal
	raise_button.visible = can_raise
	raise_slider.visible = can_raise
	raise_amount_label.visible = can_raise
	for qb in quick_bet_buttons:
		qb.visible = can_raise
	if can_raise:
		raise_slider.min_value = min_raise
		raise_slider.max_value = max(min_raise * 10, min_raise + 1)
		# A fixed step of 1 (whole year) was fine when blinds were whole years,
		# but a sub-year min_raise (e.g. a 30sec/1min opening blind) needs a
		# step scaled to its own range, or the slider only ever lands on 0 or
		# 1. step=0 makes Range treat it as continuous (no snapping) instead,
		# which works smoothly at any scale and lets the quick-bet buttons
		# land on their exact target amount.
		raise_slider.step = 0.0
		raise_slider.value = min_raise
		_update_raise_label(min_raise)


func hide_actions() -> void:
	visible = false


func set_status(day_text: String, sentence_years: float) -> void:
	day_label.text = day_text
	sentence_label.set_years(sentence_years)
