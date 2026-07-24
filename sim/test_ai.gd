extends Node

# Headless smoke test for M4: seats AIController-driven prisoners with the
# four AIProfile presets, plays many hands, and checks the heuristic actually
# differentiates styles (Rock folds more than Maniac, Maniac raises more than
# Rock) with no illegal actions (BettingRound asserts that internally) and no
# runaway betting rounds (bounded by MAX_RAISES_PER_STREET, checked here by
# just completing within a reasonable time).
#
# Runs as a scene (PokerEngine needs the GameManager autoload). Run via:
#   godot --headless --path . res://sim/test_ai.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


class CountingActionSource:
	var inner := AIController.new()
	var decide_counts: Dictionary = {}
	var fold_counts: Dictionary = {}
	var raise_counts: Dictionary = {}

	func decide(prisoner, legal_actions: Array, to_call: float, min_raise: float, context: Dictionary = {}) -> Dictionary:
		var action: Dictionary = inner.decide(prisoner, legal_actions, to_call, min_raise, context)
		var name: String = prisoner.ai_profile.display_name
		decide_counts[name] = int(decide_counts.get(name, 0)) + 1
		if action["type"] == BettingRound.Action.FOLD:
			fold_counts[name] = int(fold_counts.get(name, 0)) + 1
		elif action["type"] == BettingRound.Action.RAISE:
			raise_counts[name] = int(raise_counts.get(name, 0)) + 1
		return action


func _rate(counts: Dictionary, totals: Dictionary, name: String) -> float:
	var total: int = int(totals.get(name, 0))
	if total == 0:
		return 0.0
	return float(counts.get(name, 0)) / float(total)


func _ready() -> void:
	var rng = RNGService
	rng.seed_run(2026)

	var config := RunConfig.new()
	var blinds := {"ante": config.ante, "small_blind": config.small_blind, "big_blind": config.big_blind}

	var profiles: Array = [
		AIProfile.rock(),
		AIProfile.maniac(),
		AIProfile.calling_station(),
		AIProfile.shark(),
		AIProfile.rock(),
		AIProfile.maniac(),
		AIProfile.shark(),
	]

	var prisoners: Array = []
	for i in range(7):
		var p := PrisonerState.new(i, "P%d-%s" % [i, profiles[i].display_name], 100, false)
		p.ai_profile = profiles[i]
		prisoners.append(p)

	var source := CountingActionSource.new()

	var hands_played := 0
	for h in range(200):
		# Reset sentences periodically so nobody's contribution shrinks to 0
		# and stalls the strength/threshold math over a long run.
		if h % 20 == 0:
			for p in prisoners:
				p.sentence_years = 100
		await PokerEngine.play_hand(prisoners, blinds, rng, source, h % 7)
		hands_played += 1

	_check(hands_played == 200, "200 hands completed without hanging or crashing")

	var rock_fold := _rate(source.fold_counts, source.decide_counts, "Rock")
	var maniac_fold := _rate(source.fold_counts, source.decide_counts, "Maniac")
	var rock_raise := _rate(source.raise_counts, source.decide_counts, "Rock")
	var maniac_raise := _rate(source.raise_counts, source.decide_counts, "Maniac")

	print("  Rock: fold_rate=%.3f raise_rate=%.3f (n=%d)" % [rock_fold, rock_raise, source.decide_counts.get("Rock", 0)])
	print("  Maniac: fold_rate=%.3f raise_rate=%.3f (n=%d)" % [maniac_fold, maniac_raise, source.decide_counts.get("Maniac", 0)])

	_check(rock_fold > maniac_fold, "Rock (tight) folds more often than Maniac (loose)")
	_check(maniac_raise > rock_raise, "Maniac (aggressive) raises more often than Rock (passive)")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: AIController differentiates profiles correctly")
		get_tree().quit(0)
