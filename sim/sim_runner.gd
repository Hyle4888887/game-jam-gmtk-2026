extends Node

# M7 balance harness: plays many full runs and reports the numbers needed to
# tune graphify/Design - Rules.md's knobs (starting sentence, blinds, hands
# per day, x_days...) - see graphify/Build Plan - Milestones.md M7.
#
# Reports:
#   - player win-rate
#   - avg day reached
#   - avg ending sentence
#   - player outcome histogram (win / executed / timeout)
#   - table-wide execution-cause counts across all seats in the whole batch
#     (highest_sentence vs each quest id) - useful for spotting a quest that
#     never/always fires
#
# Run via:
#   godot --headless --path . res://sim/sim_runner.tscn

const NUM_RUNS := 1000

var quest_kill_counts: Dictionary = {}


func _on_prisoner_died(_id: int, cause: String) -> void:
	quest_kill_counts[cause] = int(quest_kill_counts.get(cause, 0)) + 1


func _ready() -> void:
	GameManager.prisoner_died.connect(_on_prisoner_died)

	var wins := 0
	var day_reached_sum := 0
	var final_sentence_sum := 0
	var outcome_histogram: Dictionary = {}

	for i in range(NUM_RUNS):
		var config := RunConfig.new()
		config.seed = i

		var result: Dictionary = GameManager.start_run(config)

		day_reached_sum += int(result.day_reached)
		final_sentence_sum += int(result.final_sentence)

		if result.win:
			wins += 1
			outcome_histogram["win"] = int(outcome_histogram.get("win", 0)) + 1
		elif String(result.reason).begins_with("executed"):
			outcome_histogram["executed"] = int(outcome_histogram.get("executed", 0)) + 1
		else:
			outcome_histogram["timeout"] = int(outcome_histogram.get("timeout", 0)) + 1

	GameManager.prisoner_died.disconnect(_on_prisoner_died)

	var win_rate := float(wins) / float(NUM_RUNS)
	var avg_day_reached := float(day_reached_sum) / float(NUM_RUNS)
	var avg_final_sentence := float(final_sentence_sum) / float(NUM_RUNS)

	print("=== Balance Report (%d runs) ===" % NUM_RUNS)
	print("Player win-rate: %.1f%%" % (win_rate * 100.0))
	print("Avg day reached (0-indexed): %.2f" % avg_day_reached)
	print("Avg ending sentence: %.1f years" % avg_final_sentence)
	print("Player outcome histogram: %s" % [outcome_histogram])
	print("Table-wide execution cause counts (all seats, all runs): %s" % [quest_kill_counts])

	var histogram_total := 0
	for key in outcome_histogram.keys():
		histogram_total += int(outcome_histogram[key])
	if histogram_total != NUM_RUNS:
		print("SANITY FAIL: outcome histogram (%d) does not sum to run count (%d)" % [histogram_total, NUM_RUNS])
		get_tree().quit(1)
		return

	get_tree().quit(0)
