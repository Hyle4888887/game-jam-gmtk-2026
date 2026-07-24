extends Node

# Regression test: MixedActionSource.decide() must `await` both branches,
# not just return their result directly. A plain synchronous action source
# (AIController, CallStationActionSource) masks a missing await - calling an
# un-awaited coroutine only breaks loudly once the delegate genuinely
# suspends (like HumanActionSource awaiting a signal). This test uses a fake
# action source that awaits a real signal to catch that class of bug.
# Run via:
#   godot --headless --path . res://sim/test_mixed_action_source.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


## Mimics HumanActionSource's shape: decide() genuinely suspends on a signal
## instead of returning synchronously.
class FakeAsyncActionSource:
	signal ready_to_decide

	func decide(_prisoner, _legal_actions: Array, _to_call: float, _min_raise: float, _context: Dictionary = {}) -> Dictionary:
		var action: Dictionary = await ready_to_decide
		return action


func _ready() -> void:
	var fake_async := FakeAsyncActionSource.new()
	var fake_ai := CallStationActionSource.new()
	var mixed := MixedActionSource.new(fake_async, fake_ai)

	var player := PrisonerState.new(0, "Player", 100, true)
	var ai_prisoner := PrisonerState.new(1, "AI", 100, false)

	# AI branch: must resolve immediately without needing the fake signal.
	var ai_action: Dictionary = await mixed.decide(ai_prisoner, [BettingRound.Action.CHECK], 0, 10)
	_check(ai_action.get("type") == BettingRound.Action.CHECK, "AI branch resolves synchronously through MixedActionSource")

	# Player branch: must actually suspend until the fake signal fires. The
	# deferred call only runs on the next idle frame, which is after this
	# await has already suspended - so if the inner await were ever dropped
	# again, decide() would return before the signal fires and _check below
	# would still see the right value by luck of timing on a single run;
	# see test_game_view.gd for the real end-to-end (HUD button -> resolved
	# hand) coverage of this path.
	call_deferred("_fire_fake_signal", fake_async)
	var player_action: Dictionary = await mixed.decide(player, [BettingRound.Action.FOLD], 10, 10)
	_check(player_action.get("type") == BettingRound.Action.FOLD, "player branch genuinely awaits an async action source through MixedActionSource")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: MixedActionSource correctly awaits both branches")
		get_tree().quit(0)


func _fire_fake_signal(fake_async) -> void:
	fake_async.ready_to_decide.emit({"type": BettingRound.Action.FOLD})
