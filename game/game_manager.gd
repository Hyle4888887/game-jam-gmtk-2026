extends Node

# Top level run/day state machine. Fleshed out in full once the poker engine
# and day-resolution systems exist (see graphify/Build Plan - Milestones.md).

signal run_started(config)
signal run_ended(win: bool, reason: String)
signal day_started(day_index: int, daily_quest)
signal day_resolved(day_index: int, victims: Array)

# Hand-level signal contract (graphify/Architecture - Systems.md). PokerEngine
# is static/stateless, so it emits through this autoload rather than owning
# its own signals. Wired up incrementally: sentence_changed and hand_resolved
# are emitted starting at M3; the rest are declared now so a future UI layer
# has a stable contract to subscribe to, and get wired as later milestones
# (AI, day loop) reach the points that produce them.
signal hand_started(dealer_seat: int)
signal hand_resolved(log)
signal card_dealt(prisoner_id: int, card: Card, hidden: bool)
signal community_revealed(cards: Array)
signal betting_round_started(street: String)
signal action_requested(prisoner_id: int, legal_actions: Array)
signal action_taken(prisoner_id: int, action: Dictionary)
signal sentence_changed(prisoner_id: int, old_value: float, new_value: float)
signal prisoner_died(prisoner_id: int, cause: String)

## Emitted by GameView on any mouse/keyboard press (see GameView.
## _unhandled_input). Two consumers race a wait against it: PacedActionSource
## uses it to cut an AI turn's pacing delay short (so clicking through
## actually speeds the game up, not just the end-of-hand pause below), and
## start_run's wait_for_hand_result_ack uses it (with no timeout at all) to
## know the player has actually seen the "WINNER IS ..." popup before
## starting the next hand.
signal skip_requested

var player: PrisonerState = null
var table: TableManager = null
var config: RunConfig = null


## Plays one full run to completion: RUN_START -> DAY_START -> hands ->
## DAY_RESOLVE -> next day or RUN_END. See graphify/Design - Rules.md §1 for
## the win/lose conditions and graphify/Build Plan - Milestones.md M6.
##
## `action_source` services every seat; pass a MixedActionSource wrapping a
## HumanActionSource for the player seat once the UI is driving it (see
## view/human_action_source.gd), otherwise every seat falls back to the
## AI-vs-AI proxy used by the M7 balance harness. This is a coroutine (awaits
## PokerEngine.play_hand, which awaits decide() calls) so a human-driven seat
## can genuinely wait on a button press; callers must `await` this function.
## Returns {"win": bool, "reason": String, "day_reached": int,
## "final_sentence": int}. `wait_for_hand_result_ack` (false by default)
## blocks the day loop after each hand resolves until GameView's
## skip_requested fires (any mouse/keyboard press) - no timeout, so the
## "WINNER IS ..." popup (see HandResultPopup) genuinely stays up until the
## player has actually seen it, instead of a fixed pause that could
## auto-advance (and start the next hand's own AI turns) out from under
## them. False for the M7 balance harness and automated tests, which need
## hundreds/thousands of hands to run unattended in seconds.
func start_run(run_config: RunConfig, action_source = null, player_name: String = "Player", wait_for_hand_result_ack: bool = false) -> Dictionary:
	config = run_config
	if config.quest_pool.is_empty():
		config.quest_pool = Quest.default_pool()
	if config.ai_profiles.is_empty():
		config.ai_profiles = AIProfile.presets()
	if action_source == null:
		# Player seat runs the opponent-modeling proxy; AI opponents keep
		# using the plain heuristic the difficulty ramp is tuned against.
		action_source = MixedActionSource.new(ExploitiveAIController.new(), AIController.new())

	RNGService.seed_run(config.seed)

	player = PrisonerState.new(0, player_name, config.starting_sentence, true)
	if player.ai_profile == null:
		player.ai_profile = AIProfile.shark()

	table = TableManager.new(config.table_size)
	table.seed_table(player, config, RNGService, 0)

	run_started.emit(config)

	var result := {
		"win": false,
		"reason": "",
		"day_reached": 0,
		"final_sentence": player.sentence_years,
	}

	for day in range(config.x_days):
		var quest: Quest = QuestManager.draw_daily_quest(config.quest_pool, RNGService)
		day_started.emit(day, quest)

		var stats := StatsTracker.new()
		stats.reset_day(table.seats)
		var blinds := config.blinds_for_day(day)

		for h in range(config.hands_per_day):
			hand_started.emit(table.dealer_index)
			var log := await PokerEngine.play_hand(table.seats, blinds, RNGService, action_source, table.dealer_index)
			stats.record_hand(log, table.seats)
			table.rotate_dealer()
			if wait_for_hand_result_ack:
				await skip_requested

		var victims: Array = DeathResolver.resolve(table.seats, quest, stats, RNGService)
		day_resolved.emit(day, victims)

		result.day_reached = day
		result.final_sentence = player.sentence_years

		if not player.is_alive:
			result.reason = "executed on day %d" % day
			run_ended.emit(false, result.reason)
			return result

		if player.sentence_years <= config.win_at_or_below:
			result.win = true
			result.reason = "sentence served on day %d" % day
			run_ended.emit(true, result.reason)
			return result

		if day == config.x_days - 1:
			result.reason = "sentence not served by day %d" % config.x_days
			run_ended.emit(false, result.reason)
			return result

		table.refill(config, RNGService, day + 1)

	return result
