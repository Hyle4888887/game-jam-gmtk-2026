extends Node

# Genuine end-to-end test: instantiates the REAL res://view/game_view.tscn
# (not a hand-rebuilt pipeline) and drives it via its actual HUD buttons,
# with ai_turn_delay_seconds zeroed out so it runs fast instead of the real
# game's 5s-per-AI-turn pacing.
#
# This exists because two real bugs (a missing return-type annotation in
# game_view.gd, and a card-highlight-then-refresh ordering bug that silently
# wiped the win highlight) both slipped past test_game_view.gd, which
# rebuilds HUD/HumanActionSource/MixedActionSource manually rather than ever
# actually parsing/running game_view.gd itself. This test closes that gap.
# Run via:
#   godot --headless --path . res://sim/test_game_view_real.tscn

var failures := 0
var hands_seen := 0
var saw_winner_tint := false
var saw_loser_tint := false
var gv: GameView


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _on_action_requested(prisoner_id: int, legal_actions: Array) -> void:
	if GameManager.player != null and prisoner_id == GameManager.player.id:
		call_deferred("_press_button", legal_actions)


func _press_button(legal_actions: Array) -> void:
	if BettingRound.Action.CHECK in legal_actions or BettingRound.Action.CALL in legal_actions:
		gv.hud_view.check_call_button.pressed.emit()
	elif BettingRound.Action.FOLD in legal_actions:
		gv.hud_view.fold_button.pressed.emit()


func _on_hand_resolved(_log) -> void:
	hands_seen += 1
	# Connected after gv itself, so gv's own _on_hand_resolved (which applies
	# the highlight/darken) has already run for this same signal emission by
	# the time this fires - this is exactly what would have caught the
	# refresh-after-highlight ordering bug.
	for cv in gv.table_view._all_card_views():
		if cv.modulate == CardView.HIGHLIGHT_TINT:
			saw_winner_tint = true
		if cv.modulate == CardView.DARK_TINT:
			saw_loser_tint = true


func _ready() -> void:
	gv = load("res://view/game_view.tscn").instantiate()
	gv.ai_turn_delay_seconds = 0.0
	add_child(gv)

	GameManager.action_requested.connect(_on_action_requested)
	GameManager.hand_resolved.connect(_on_hand_resolved)

	await GameManager.run_ended

	_check(hands_seen > 0, "at least one hand resolved through the real GameView scene")
	_check(saw_winner_tint, "a real showdown produced a gold-highlighted winning card (catches the refresh/highlight ordering bug)")
	_check(saw_loser_tint, "a real showdown darkened at least one non-winning card")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: the real GameView scene highlights/darkens showdown cards correctly")
		get_tree().quit(0)
