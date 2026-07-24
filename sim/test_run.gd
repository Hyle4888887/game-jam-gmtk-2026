extends Node

# Headless smoke test for M6: plays several full runs via
# GameManager.start_run() and checks the win/lose conditions from
# graphify/Design - Rules.md §1 are actually enforced:
#   - win requires player alive AND sentence_years <= win_at_or_below
#   - loss by execution means player.is_alive is false
#   - loss by day-X timeout means day_reached == x_days - 1 and sentence > 0
#   - day_reached never exceeds x_days - 1
#
# Runs as a scene (GameManager/PokerEngine need the autoload chain alive).
# Run via:
#   godot --headless --path . res://sim/test_run.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var seeds := [1, 2, 3, 4, 5, 6, 7, 8]
	var win_count := 0
	var loss_execution_count := 0
	var loss_timeout_count := 0

	for s in seeds:
		var config := RunConfig.new()
		config.seed = s
		var result: Dictionary = await GameManager.start_run(config)

		_check(result.day_reached >= 0 and result.day_reached <= config.x_days - 1, "seed %d: day_reached within [0, x_days-1]" % s)

		if result.win:
			win_count += 1
			_check(GameManager.player.is_alive, "seed %d: winner is alive" % s)
			_check(result.final_sentence <= config.win_at_or_below, "seed %d: winner's sentence <= win threshold" % s)
		else:
			if not GameManager.player.is_alive:
				loss_execution_count += 1
				_check(result.reason.begins_with("executed"), "seed %d: execution loss has matching reason" % s)
			else:
				loss_timeout_count += 1
				_check(result.day_reached == config.x_days - 1, "seed %d: timeout loss happened on the final day" % s)
				_check(result.final_sentence > config.win_at_or_below, "seed %d: timeout loss sentence is still above threshold" % s)

	print("  outcomes across %d seeds: %d wins, %d executions, %d timeouts" % [seeds.size(), win_count, loss_execution_count, loss_timeout_count])

	# Reproducibility: same seed must produce the same outcome.
	var config_a := RunConfig.new()
	config_a.seed = 999
	var result_a: Dictionary = await GameManager.start_run(config_a)
	var config_b := RunConfig.new()
	config_b.seed = 999
	var result_b: Dictionary = await GameManager.start_run(config_b)
	_check(
		result_a.win == result_b.win and result_a.day_reached == result_b.day_reached and result_a.final_sentence == result_b.final_sentence,
		"same seed produces the same run outcome (reproducibility)"
	)

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: full run state machine enforces win/lose conditions correctly")
		get_tree().quit(0)
