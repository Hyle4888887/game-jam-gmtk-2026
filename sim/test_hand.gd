extends Node

# Headless smoke test for M2: plays one hand of Hold'em with 7 call-station
# dummies and logs a correct winner + everyone's contribution.
#
# Runs as a scene (not --script) because PokerEngine emits through the
# GameManager autoload, which is only initialized when Godot boots a scene.
# Run via:
#   godot --headless --path . res://sim/test_hand.tscn


func _ready() -> void:
	var rng = RNGService
	rng.seed_run(12345)

	var config := RunConfig.new()
	var blinds := {"ante": config.ante, "small_blind": config.small_blind, "big_blind": config.big_blind}

	var prisoners: Array = []
	for i in range(7):
		var sentence: int = rng.randi_range(config.ai_sentence_min, config.ai_sentence_max)
		prisoners.append(PrisonerState.new(i, "Prisoner %d" % i, sentence, i == 0))

	var action_source := CallStationActionSource.new()
	var log := PokerEngine.play_hand(prisoners, blinds, rng, action_source, 0)

	print("Community: %s" % [log.community])
	print("Contributions:")
	for p in prisoners:
		var folded_tag := " (folded)" if p.folded else ""
		print("  %s -> %d%s" % [p, log.contributions[p], folded_tag])

	print("Winners: %s" % [log.winners])
	if log.hand_result != null:
		print("Winning hand: %s" % [log.hand_result])

	var ok := log.winners.size() > 0
	for w in log.winners:
		if w.folded:
			ok = false

	if ok:
		print("PASSED: hand resolved with a valid, non-folded winner")
		get_tree().quit(0)
	else:
		print("FAILED: winner invalid")
		get_tree().quit(1)
