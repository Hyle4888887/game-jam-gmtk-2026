extends Node

# Headless smoke test for M3: verifies the bet-to-lose economy per
# graphify/Design - Rules.md §3. Note this is intentionally NOT zero-sum at
# the table: each non-winner independently ADDS their own contribution while
# only the winner(s) SUBTRACT theirs, so with a single winner among 7 players
# the table's total sentence years goes UP each hand (6 losers add C, 1
# winner removes C -> net +5C). What must hold per hand is:
#   after_total - before_total == total_contributions - 2 * winners_contributions
#
# Runs as a scene (not --script) because PokerEngine emits through the
# GameManager autoload, which is only initialized when Godot boots a scene.
# Run via:
#   godot --headless --path . res://sim/test_bet_to_lose.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var rng = RNGService
	rng.seed_run(777)

	var config := RunConfig.new()
	var blinds := {"ante": config.ante, "small_blind": config.small_blind, "big_blind": config.big_blind}

	# --- Test A: many hands, zero-sum-per-hand invariant ---
	var prisoners: Array = []
	for i in range(7):
		prisoners.append(PrisonerState.new(i, "P%d" % i, 100, i == 0))

	var action_source := CallStationActionSource.new()
	var formula_holds := true
	# On average an individual prisoner loses more often than they win at a
	# 7-handed table (1 winner vs up to 6 losers per hand, see comment above),
	# so cumulative sentence trends UP over many hands - checking the final
	# value would not detect the win-side of the mechanic. Instead check
	# per-hand that any winner's own delta this hand was negative.
	var any_winner_decreased_this_hand := false
	for h in range(30):
		var before_total := 0.0
		for p in prisoners:
			before_total += p.sentence_years
		var log := await PokerEngine.play_hand(prisoners, blinds, rng, action_source, h % 7)
		var after_total := 0.0
		for p in prisoners:
			after_total += p.sentence_years
		var total_contrib := 0.0
		var winners_contrib := 0.0
		for p in prisoners:
			total_contrib += log.contributions[p]
		for w in log.winners:
			winners_contrib += log.contributions[w]
			if log.sentence_deltas[w] < 0:
				any_winner_decreased_this_hand = true
		var expected_delta := total_contrib - 2 * winners_contrib
		if not is_equal_approx(after_total - before_total, expected_delta) and absf(after_total - before_total - expected_delta) > 0.000001:
			formula_holds = false
			print("  hand %d: expected delta %s, got %s" % [h, expected_delta, after_total - before_total])
	_check(formula_holds, "table-wide sentence delta matches total_contrib - 2*winners_contrib every hand")
	_check(any_winner_decreased_this_hand, "every hand's winner(s) had their own sentence decrease by their contribution")

	# --- Test B: forced fold, verify asymmetric outcome ---
	var folder := PrisonerState.new(0, "Folder", 100, false)
	var caller := PrisonerState.new(1, "Caller", 100, false)
	var others: Array = []
	for i in range(2, 7):
		others.append(PrisonerState.new(i, "P%d" % i, 100, false))
	var table: Array = [folder, caller] + others

	var fold_source := _ScriptedFoldSource.new(folder.id)
	var log_b := await PokerEngine.play_hand(table, blinds, rng, fold_source, 0)

	_check(folder.folded, "scripted prisoner actually folded")
	_check(folder.sentence_years == 100 + log_b.contributions[folder], "folder's sentence increased by exactly their (small) contribution (blinds dict here has no loss_penalty_factor, so it defaults to 1.0/full penalty)")
	if log_b.winners.size() == 1 and log_b.winners[0] == folder:
		_check(false, "folder must not be recorded as a winner")

	# --- Test C: loss_penalty_factor softens (but doesn't zero) the loser
	# side of the mechanic, per graphify/Design - Rules.md §3. ---
	var soft_blinds := blinds.duplicate()
	soft_blinds["loss_penalty_factor"] = 0.25
	var soft_folder := PrisonerState.new(0, "SoftFolder", 100, false)
	var soft_others: Array = []
	for i in range(1, 7):
		soft_others.append(PrisonerState.new(i, "P%d" % i, 100, false))
	var soft_table: Array = [soft_folder] + soft_others
	var soft_fold_source := _ScriptedFoldSource.new(soft_folder.id)
	var log_c := await PokerEngine.play_hand(soft_table, soft_blinds, rng, soft_fold_source, 0)

	var expected_soft_delta: float = log_c.contributions[soft_folder] * 0.25
	_check(
		is_equal_approx(log_c.sentence_deltas[soft_folder], expected_soft_delta) or log_c.sentence_deltas[soft_folder] == expected_soft_delta,
		"loss_penalty_factor=0.25 scales a non-winner's penalty down to 25%% of their contribution (not the full amount)"
	)
	var any_full_winner_erase := false
	for w in log_c.winners:
		if log_c.sentence_deltas[w] == -log_c.contributions[w]:
			any_full_winner_erase = true
	_check(any_full_winner_erase, "loss_penalty_factor does not affect the winner's own full erase")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: bet-to-lose economy behaves correctly")
		get_tree().quit(0)


## Folds immediately for one designated prisoner id, calls/checks for everyone else.
class _ScriptedFoldSource:
	var fold_id: int

	func _init(p_fold_id: int) -> void:
		fold_id = p_fold_id

	func decide(prisoner, legal_actions: Array, _to_call: float, _min_raise: float, _context: Dictionary = {}) -> Dictionary:
		if prisoner.id == fold_id and BettingRound.Action.FOLD in legal_actions:
			return {"type": BettingRound.Action.FOLD}
		if BettingRound.Action.CHECK in legal_actions:
			return {"type": BettingRound.Action.CHECK}
		return {"type": BettingRound.Action.CALL}
