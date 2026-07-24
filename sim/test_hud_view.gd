extends Node

# Headless smoke test for HUDView: instances it, drives set_legal_actions
# through fold/check/call/raise combos, and simulates button presses to
# confirm action_chosen emits the right action dict. Run via:
#   godot --headless --path . res://sim/test_hud_view.tscn

var failures := 0
var last_action: Dictionary = {}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _on_action_chosen(action: Dictionary) -> void:
	last_action = action


func _ready() -> void:
	var hud: HUDView = load("res://view/hud_view.tscn").instantiate()
	add_child(hud)
	hud.size = Vector2(1152, 110)
	hud.action_chosen.connect(_on_action_chosen)

	# Amounts are always shown in whichever unit best fits their own
	# magnitude (see TimeUnits.format_amount_best_unit) - 10 (years, the raw
	# engine unit) is >= 1 year, so it reads as "10 yr".
	var expected_10 := TimeUnits.format_amount_best_unit(10)

	# Facing a bet: FOLD/CALL/RAISE legal, no CHECK.
	hud.set_legal_actions([BettingRound.Action.FOLD, BettingRound.Action.CALL, BettingRound.Action.RAISE], 10, 10)
	_check(hud.visible, "HUD becomes visible once legal actions are set")
	_check(hud.fold_button.visible, "fold button visible when FOLD is legal")
	_check(hud.check_call_button.text == "CALL %s" % expected_10, "check/call button reads CALL amount (best-unit formatted) when facing a bet")
	_check(hud.raise_button.visible, "raise controls visible when RAISE is legal")
	_check(hud.raise_amount_label.text == "Raise: %s" % expected_10, "raise label starts at min_raise, best-unit formatted")

	hud.fold_button.pressed.emit()
	_check(last_action.get("type") == BettingRound.Action.FOLD, "pressing fold emits a FOLD action")

	hud.check_call_button.pressed.emit()
	_check(last_action.get("type") == BettingRound.Action.CALL, "pressing check/call while facing a bet emits CALL")

	hud.raise_slider.value = 25
	hud.raise_button.pressed.emit()
	_check(last_action.get("type") == BettingRound.Action.RAISE and int(last_action.get("amount", -1)) == 25, "pressing raise emits RAISE with the slider's amount")

	# No bet to face: CHECK/RAISE legal, no FOLD/CALL.
	hud.set_legal_actions([BettingRound.Action.CHECK, BettingRound.Action.RAISE], 0, 10)
	_check(not hud.fold_button.visible, "fold button hidden when FOLD isn't legal")
	_check(hud.check_call_button.text == "CHECK", "check/call button reads CHECK when to_call is 0")

	hud.check_call_button.pressed.emit()
	_check(last_action.get("type") == BettingRound.Action.CHECK, "pressing check/call with to_call=0 emits CHECK")

	hud.hide_actions()
	_check(not hud.visible, "hide_actions() hides the whole bar")

	# Quick-bet buttons: MIN / 1/2 POT / POT / MAX, pot=100, min_raise=10.
	hud.set_legal_actions([BettingRound.Action.FOLD, BettingRound.Action.CALL, BettingRound.Action.RAISE], 10, 10, 100)
	_check(hud.quick_bet_buttons.size() == 4, "there are exactly 4 quick-bet buttons (MIN, 1/2 POT, POT, MAX)")

	hud.quick_bet_buttons[0].pressed.emit()  # MIN
	_check(int(hud.raise_slider.value) == 10, "MIN sets the raise slider to min_raise")

	hud.quick_bet_buttons[1].pressed.emit()  # 1/2 POT
	_check(int(hud.raise_slider.value) == 50, "1/2 POT sets the raise slider to half the pot")

	hud.quick_bet_buttons[2].pressed.emit()  # POT
	_check(int(hud.raise_slider.value) == 100, "POT sets the raise slider to the full pot")

	hud.quick_bet_buttons[3].pressed.emit()  # MAX
	_check(int(hud.raise_slider.value) == int(hud.raise_slider.max_value), "MAX sets the raise slider to its maximum")

	# A pot smaller than min_raise must still clamp into the legal range.
	hud.set_legal_actions([BettingRound.Action.CHECK, BettingRound.Action.RAISE], 0, 10, 2)
	hud.quick_bet_buttons[2].pressed.emit()  # POT (2), below min_raise (10)
	_check(int(hud.raise_slider.value) == 10, "POT below min_raise clamps up to min_raise, not below the legal minimum")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: HUDView wiring works headlessly")
		get_tree().quit(0)
