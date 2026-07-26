extends Node

# Unit test for GameManager.start_run()'s wait_for_hand_result_ack: verifies
# it blocks the day loop indefinitely after each hand resolves until
# skip_requested fires (GameView's "any key/click" handler while
# the "WINNER IS ..." popup is up) - no timeout, so a result can never be
# auto-advanced past before the player has actually seen it - and that it's
# skipped entirely when false (the default every other test/the M7 harness
# relies on). Uses a 1-day, 1-hand config to stay fast. Run via:
#   godot --headless --path . res://sim/test_hand_result_pause.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var config := RunConfig.new()
	config.x_days = 1
	config.hands_per_day = 1
	config.seed = 42

	var start_ms := Time.get_ticks_msec()
	await GameManager.start_run(config, null, "Player", false)
	var elapsed_false_ms := Time.get_ticks_msec() - start_ms
	# Loose tolerance - just confirming no meaningful wait happened, not
	# timing precision (headless frame timing has enough granularity that a
	# tight bound flakes - see test_paced_action_source.gd).
	_check(elapsed_false_ms < 200, "wait_for_hand_result_ack=false (the default) adds no real delay (elapsed=%dms)" % elapsed_false_ms)

	# With wait_for_hand_result_ack=true and nobody ever emitting
	# skip_requested, the run must still be blocked well past
	# where a timer-based approach would have auto-advanced (there is no
	# timer anymore - this is the whole point of the fix).
	start_ms = Time.get_ticks_msec()
	var run_finished := [false]
	var run_task := func():
		await GameManager.start_run(config, null, "Player", true)
		run_finished[0] = true
	run_task.call()
	await get_tree().create_timer(0.3, false).timeout
	_check(not run_finished[0], "wait_for_hand_result_ack=true blocks indefinitely with no ack - no fixed timeout to auto-advance on")

	# Now actually ack it - the run must complete promptly afterward.
	GameManager.skip_requested.emit()
	var waited_frames := 0
	while not run_finished[0] and waited_frames < 60:
		await get_tree().process_frame
		waited_frames += 1
	_check(run_finished[0], "skip_requested unblocks the day loop once emitted")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: wait_for_hand_result_ack gates the day loop correctly")
		get_tree().quit(0)
