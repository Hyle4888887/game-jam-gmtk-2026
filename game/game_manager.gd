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
signal sentence_changed(prisoner_id: int, old_value: int, new_value: int)
signal prisoner_died(prisoner_id: int, cause: String)

var player: PrisonerState = null
var table: TableManager = null
var config: RunConfig = null


## Plays one full run to completion: RUN_START -> DAY_START -> hands ->
## DAY_RESOLVE -> next day or RUN_END. See graphify/Design - Rules.md §1 for
## the win/lose conditions and graphify/Build Plan - Milestones.md M6.
##
## `action_source` services every seat (player included) since there is no
## UI/human input yet; a human-playable seat is stretch goal S4 in the build
## plan and would swap this per-seat instead of table-wide.
## Returns {"win": bool, "reason": String, "day_reached": int,
## "final_sentence": int}.
func start_run(run_config: RunConfig, action_source = null, player_name: String = "Player") -> Dictionary:
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
			var log := PokerEngine.play_hand(table.seats, blinds, RNGService, action_source, table.dealer_index)
			stats.record_hand(log, table.seats)
			table.rotate_dealer()

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
