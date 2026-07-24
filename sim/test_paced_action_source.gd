extends Node

# Unit test for PacedActionSource: verifies it actually waits ~delay_seconds
# after the inner action_source resolves before returning, and correctly
# forwards observe_action to the wrapped source. Uses a short delay (not the
# real 5s used by GameView) so this stays fast.
# Run via:
#   godot --headless --path . res://sim/test_paced_action_source.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


class ObserveSpy:
	var observed: Array = []

	func observe_action(prisoner_id: int, action: Dictionary) -> void:
		observed.append([prisoner_id, action])


func _ready() -> void:
	var inner := CallStationActionSource.new()
	var delay := 0.2
	var paced := PacedActionSource.new(inner, delay)

	var prisoner := PrisonerState.new(0, "P", 100, false)
	var start_ms := Time.get_ticks_msec()
	var action: Dictionary = await paced.decide(prisoner, [BettingRound.Action.CHECK], 0, 10)
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	_check(action.get("type") == BettingRound.Action.CHECK, "PacedActionSource returns the inner source's decision")
	# Loose tolerance - this just needs to confirm a real, meaningful delay
	# happened, not verify precise timer accuracy (headless frame timing
	# has enough granularity that a tight bound flakes).
	_check(elapsed_ms >= delay * 1000 * 0.5, "PacedActionSource actually waited roughly delay_seconds before returning (elapsed=%dms)" % elapsed_ms)

	var spy := ObserveSpy.new()
	var paced_with_spy := PacedActionSource.new(spy, 0.0)
	paced_with_spy.observe_action(0, {"type": BettingRound.Action.FOLD})
	_check(spy.observed.size() == 1 and spy.observed[0][0] == 0, "observe_action forwards to the wrapped inner source")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: PacedActionSource wraps timing and observe_action correctly")
		get_tree().quit(0)
