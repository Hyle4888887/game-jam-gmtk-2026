extends Node

# End-to-end integration test: drives a real HUDView through
# HumanActionSource -> MixedActionSource -> BettingRound -> PokerEngine ->
# GameManager.start_run, simulating the player always checking/calling by
# pressing the actual HUD button whenever action_requested fires for the
# player seat. This is the test that would have caught the
# "MixedActionSource forgot to await its player branch" bug - unit-testing
# MixedActionSource in isolation with a fake signal didn't force real
# engine-timing conditions the way driving the whole pipeline does.
#
# Uses a tiny RunConfig (1 day, 3 hands) so it finishes in well under the
# process timeout instead of playing a full 7-day run. Run via:
#   godot --headless --path . res://sim/test_game_view.tscn

var failures := 0
var hud: HUDView
var hands_seen := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _on_action_requested(prisoner_id: int, legal_actions: Array) -> void:
	if GameManager.player != null and prisoner_id == GameManager.player.id:
		call_deferred("_press_appropriate_button", legal_actions)


func _press_appropriate_button(legal_actions: Array) -> void:
	if BettingRound.Action.CHECK in legal_actions or BettingRound.Action.CALL in legal_actions:
		hud.check_call_button.pressed.emit()
	elif BettingRound.Action.FOLD in legal_actions:
		hud.fold_button.pressed.emit()


func _on_hand_resolved(_log) -> void:
	hands_seen += 1


func _ready() -> void:
	hud = load("res://view/hud_view.tscn").instantiate()
	add_child(hud)
	hud.size = Vector2(1152, 110)

	GameManager.action_requested.connect(_on_action_requested)
	GameManager.hand_resolved.connect(_on_hand_resolved)

	var config := RunConfig.new()
	config.seed = 42
	config.x_days = 1
	config.hands_per_day = 3

	var human_source := HumanActionSource.new(hud)
	var action_source := MixedActionSource.new(human_source, AIController.new())

	var result: Dictionary = await GameManager.start_run(config, action_source)

	_check(hands_seen > 0, "at least one hand resolved through the full human-in-the-loop pipeline")
	_check(result.has("win"), "start_run returned a valid result dict")
	print("  hands_seen=%d result=%s" % [hands_seen, result])

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: full human-in-the-loop pipeline (HUD -> HumanActionSource -> GameManager) works end to end")
		get_tree().quit(0)
