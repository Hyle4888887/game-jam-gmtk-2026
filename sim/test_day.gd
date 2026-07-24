extends Node

# Headless smoke test for M5: seats a table, plays a full day of hands,
# resolves the 2 daily deaths (highest sentence + quest match), refills the
# table back to 7, and repeats for a few days to check nothing breaks across
# day boundaries.
#
# Runs as a scene (PokerEngine/DeathResolver need the GameManager autoload).
# Run via:
#   godot --headless --path . res://sim/test_day.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var rng = RNGService
	rng.seed_run(4242)

	var config := RunConfig.new()
	config.ai_profiles = AIProfile.presets()
	config.quest_pool = Quest.default_pool()

	var player := PrisonerState.new(0, "Player", config.starting_sentence, true)
	var table := TableManager.new(config.table_size)
	table.seed_table(player, config, rng, 0)

	_check(table.seats.size() == 7, "table seeded with 7 seats")
	var all_alive_initially := true
	for p in table.seats:
		if not p.is_alive:
			all_alive_initially = false
	_check(all_alive_initially, "all 7 seats alive at seed time")

	var source := AIController.new()
	var deaths_seen := 0

	for day in range(4):
		var stats := StatsTracker.new()
		stats.reset_day(table.seats)
		var blinds := config.blinds_for_day(day)

		for h in range(config.hands_per_day):
			var log := await PokerEngine.play_hand(table.seats, blinds, rng, source, table.dealer_index)
			stats.record_hand(log, table.seats)
			table.rotate_dealer()

		var quest := QuestManager.draw_daily_quest(config.quest_pool, rng)
		var before_alive: Array = table.alive_prisoners()
		var max_sentence_before := 0.0
		for p in before_alive:
			if p.sentence_years > max_sentence_before:
				max_sentence_before = p.sentence_years

		var victims := DeathResolver.resolve(table.seats, quest, stats, rng)

		_check(victims.size() == config.deaths_per_day, "day %d: exactly %d deaths" % [day, config.deaths_per_day])
		var victims_distinct: bool = victims.size() == 2 and victims[0] != victims[1]
		_check(victims_distinct, "day %d: the two victims are distinct prisoners" % day)
		var death1_has_max: bool = victims.size() > 0 and victims[0].sentence_years >= 0 and not victims[0].is_alive
		_check(death1_has_max, "day %d: death 1 prisoner is marked dead" % day)

		var death1_was_max_sentence := victims.size() > 0
		if victims.size() > 0:
			# victims[0] should have held the max sentence among the alive
			# pool at resolution time (recorded before is_alive flips).
			death1_was_max_sentence = false
			for p in before_alive:
				if p == victims[0] and p.sentence_years == max_sentence_before:
					death1_was_max_sentence = true
		_check(death1_was_max_sentence, "day %d: death 1 held the max sentence among alive prisoners" % day)

		if player in victims:
			deaths_seen += 1
			print("  (player died on day %d, cause pool exhausted for this smoke test)" % day)
			break

		table.refill(config, rng, day + 1)
		var refilled_all_alive := true
		for p in table.seats:
			if p == null or not p.is_alive:
				refilled_all_alive = false
		_check(refilled_all_alive, "day %d: table refilled back to 7 alive" % day)

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: day loop (refill + stats + quests + deaths) behaves correctly")
		get_tree().quit(0)
