class_name GameView
extends Control

## The actual playable entry point: wires TableView + HUDView to
## GameManager's signal contract and drives one full run with the player
## seat controlled by HumanActionSource. AI opponents use the plain
## AIController (wrapped in PacedActionSource so each AI turn takes a real
## few seconds instead of the whole betting round resolving instantly) - the
## difficulty ramp (TableManager) is still tuned against the unpaced
## AIController's behavior, pacing only affects timing, not decisions.

## Instance var (not a const) so an automated test can zero it out before
## this node enters the tree (set it right after instantiate(), before
## add_child) - real gameplay keeps the 5s default, tests get a fast run
## through the ACTUAL scene instead of a hand-rebuilt pipeline that can't
## catch bugs specific to this script (see sim/test_game_view_real.gd).
@export var ai_turn_delay_seconds: float = 5.0

## Same reasoning as ai_turn_delay_seconds (zeroed - here, falsed - out by
## tests). When true, the day loop blocks after every hand until the player
## presses any mouse/keyboard button (see _unhandled_input and
## GameManager.start_run's wait_for_hand_result_ack) - no fixed timeout, so
## the "WINNER IS ..." popup (see HandResultPopup) genuinely stays up until
## it's actually been read, rather than auto-advancing into the next hand's
## own AI turns out from under the player.
@export var wait_for_hand_result_ack: bool = true

var table_view: TableView
var hud_view: HUDView
var result_label: Label
var hand_result_popup: HandResultPopup
var rules_panel: RulesPanelView

var _last_quest_name: String = ""
var _current_community: Array[Card] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ALWAYS so _unhandled_input (ESC) keeps firing while the tree is paused -
	# table_view/hud_view are set to PAUSABLE explicitly below, which
	# overrides inheriting this and makes them actually freeze/stop
	# accepting input while paused, as a real pause menu should.
	process_mode = Node.PROCESS_MODE_ALWAYS

	table_view = preload("res://view/table_view.tscn").instantiate()
	table_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	table_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(table_view)

	hud_view = preload("res://view/hud_view.tscn").instantiate()
	hud_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud_view)

	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_CENTER)
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.visible = false
	add_child(result_label)

	hand_result_popup = preload("res://view/hand_result_popup.tscn").instantiate()
	add_child(hand_result_popup)

	# Added BEFORE the "?" button so the button renders on top and keeps
	# receiving hover/click even once the panel is showing (it fully covers
	# the screen) - otherwise the panel would steal the button's hover the
	# instant it appeared. Starts hidden (see RulesPanelView._ready) -
	# never auto-shown; only via hover-peek or the ESC pause menu below.
	rules_panel = preload("res://view/rules_panel_view.tscn").instantiate()
	add_child(rules_panel)
	rules_panel.closed.connect(func():
		if get_tree().paused:
			get_tree().paused = false
	)

	var rules_button := Button.new()
	rules_button.text = "?"
	rules_button.custom_minimum_size = Vector2(28, 28)
	rules_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rules_button.position = Vector2(-38, 8)
	# Hover to peek the rules without pausing; ESC (see _unhandled_input)
	# pins the same panel open as a real pause menu instead.
	rules_button.mouse_entered.connect(func(): rules_panel.open())
	rules_button.mouse_exited.connect(func():
		if not get_tree().paused:
			rules_panel.close()
	)
	add_child(rules_button)

	GameManager.day_started.connect(_on_day_started)
	GameManager.hand_started.connect(_on_hand_started)
	GameManager.community_revealed.connect(_on_community_revealed)
	GameManager.hand_resolved.connect(_on_hand_resolved)
	GameManager.day_resolved.connect(_on_day_resolved)
	GameManager.run_ended.connect(_on_run_ended)
	# Hole cards are dealt INSIDE PokerEngine.play_hand, which runs after
	# hand_started already fired - so without this, the view stays stuck
	# showing the pre-deal (empty-handed) state through the entire hand,
	# and the player can never actually see their own cards while deciding.
	# action_requested fires right before every decision, hole cards
	# included, so hooking the refresh here keeps the table honest.
	GameManager.action_requested.connect(_on_action_requested)
	GameManager.action_taken.connect(_on_action_taken)

	var config := RunConfig.new()
	var paced_ai := PacedActionSource.new(AIController.new(), ai_turn_delay_seconds)
	var action_source := MixedActionSource.new(HumanActionSource.new(hud_view), paced_ai)
	MusicManager.play_in_game()
	await GameManager.start_run(config, action_source, "Player", wait_for_hand_result_ack)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# Any mouse/keyboard press fast-forwards whatever's currently waiting on
	# real time: an AI's PacedActionSource turn delay, or (with no timeout at
	# all) the "WINNER IS ..." popup via wait_for_hand_result_ack. Not gated
	# on the popup being visible - a click during an AI's own paced delay
	# should speed that up too, not just the end-of-hand pause. Safe to fire
	# unconditionally: this only reaches _unhandled_input for clicks/keys no
	# Control (e.g. a HUD button) already consumed.
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		GameManager.skip_requested.emit()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		rules_panel.open()
	else:
		rules_panel.close()


func _on_day_started(day_index: int, quest: Quest) -> void:
	_last_quest_name = quest.display_name
	# Blinds/ante escalate every 2 days per RunConfig.blinds_for_day (the real
	# economy/balance, unchanged) - shown in whichever unit best fits each
	# value's own size (see TimeUnits.format_amount_best_unit) so early-game
	# blinds read as small legible numbers instead of huge raw seconds counts.
	var blinds: Dictionary = GameManager.config.blinds_for_day(day_index)
	var sb_text := TimeUnits.format_amount_best_unit(blinds.get("small_blind", 0))
	var bb_text := TimeUnits.format_amount_best_unit(blinds.get("big_blind", 0))
	table_view.set_info_text("Day %d - Blinds: %s / %s - Anti-quest: %s" % [day_index + 1, sb_text, bb_text, quest.display_name])
	_refresh_seats()


func _on_hand_started(_dealer_seat: int) -> void:
	table_view.set_community([])
	table_view.clear_highlights()
	table_view.clear_all_action_text()
	hand_result_popup.hide_result()
	_current_community = []
	hud_view.clear_current_hand()
	_refresh_seats()
	SoundManager.play_card()


func _on_action_taken(prisoner_id: int, action: Dictionary) -> void:
	var seat_index := _find_seat_index(prisoner_id)
	if seat_index < 0:
		return
	var verb: String
	match int(action.get("type", -1)):
		BettingRound.Action.FOLD:
			verb = "FOLDS"
		BettingRound.Action.CHECK:
			verb = "CHECKS"
		BettingRound.Action.CALL:
			verb = "CALLS"
			_animate_chip_slide(prisoner_id)
		BettingRound.Action.RAISE:
			verb = "RAISES %s" % TimeUnits.format_amount_best_unit(float(action.get("amount", 0)))
			_animate_chip_slide(prisoner_id)
		_:
			verb = "ACTS"
	# Shown directly above that player's own seat (see SeatView.action_label)
	# instead of a single shared corner label, since their name/cards are
	# already right there - no need to repeat who's acting.
	table_view.set_seat_action_text(seat_index, verb)
	# Without this, a bet/call/raise that closes out a betting street (no
	# further action_requested until the next street/hand) never visibly
	# updates the seat's contribution chips - action_taken always fires
	# right after the state actually changed, so refresh here too.
	_refresh_seats()


func _animate_chip_slide(prisoner_id: int) -> void:
	var seat_index := _find_seat_index(prisoner_id)
	if seat_index < 0 or GameManager.table == null:
		return
	var prisoner: PrisonerState = GameManager.table.seats[seat_index]
	table_view.animate_chip_slide(seat_index, prisoner.contribution)


func _find_seat_index(prisoner_id: int) -> int:
	if GameManager.table == null:
		return -1
	for i in range(GameManager.table.seats.size()):
		var p = GameManager.table.seats[i]
		if p != null and p.id == prisoner_id:
			return i
	return -1


func _on_action_requested(_prisoner_id: int, _legal_actions: Array) -> void:
	_refresh_seats()


func _on_community_revealed(cards: Array) -> void:
	table_view.set_community(cards)
	_current_community.assign(cards)
	_update_current_hand_display()


## HandEvaluator.evaluate_best needs 5+ cards - 2 hole alone mean nothing, so
## this only shows once the flop (3 community cards) is out.
func _update_current_hand_display() -> void:
	var player: PrisonerState = GameManager.player
	if player == null or player.hole_cards.size() < 2 or _current_community.size() < 3:
		hud_view.clear_current_hand()
		return
	var seven: Array[Card] = []
	seven.append_array(player.hole_cards)
	seven.append_array(_current_community)
	var result := HandEvaluator.evaluate_best(seven)
	hud_view.set_current_hand(HandEvaluator.category_display_name(result.category))


func _on_hand_resolved(log) -> void:
	# Reveal everyone's hole cards FIRST - _refresh_seats re-assigns every
	# CardView's card, which resets any tint back to normal (see
	# CardView._update_texture). Highlighting has to be the LAST visual
	# change applied, or it gets silently wiped in the same frame.
	_refresh_seats(true)

	var winner_names: Array = []
	for w in log.winners:
		winner_names.append(w.display_name)

	if log.hand_result != null:
		var category_text := HandEvaluator.category_display_name(log.hand_result.category)
		hand_result_popup.show_result(winner_names, category_text)
		table_view.highlight_winning_cards(log.hand_result.cards)
	else:
		# Win-by-everyone-else-folded: no showdown, nothing to highlight.
		hand_result_popup.show_result(winner_names, null)
		table_view.clear_highlights()

	# The pot's chips visibly travel to the winner(s) - split pots (a tie)
	# send one to each winning seat. log.contributions is this hand's actual
	# pot breakdown, the same numbers PokerEngine used to resolve bet-to-lose.
	var hand_pot := 0.0
	for contribution in log.contributions.values():
		hand_pot += float(contribution)
	for w in log.winners:
		var seat_index := _find_seat_index(w.id)
		if seat_index >= 0:
			table_view.animate_pot_to_seat(seat_index, hand_pot)


func _on_day_resolved(_day_index: int, _victims: Array) -> void:
	_refresh_seats()


func _on_run_ended(win: bool, reason: String) -> void:
	hud_view.hide_actions()
	result_label.text = ("YOU ARE FREE\n" if win else "EXECUTED\n") + reason
	result_label.visible = true


func _refresh_seats(reveal_all: bool = false) -> void:
	if GameManager.table == null or GameManager.player == null:
		return
	table_view.update_seats(GameManager.table.seats, GameManager.player.id, GameManager.table.dealer_index, reveal_all)

	var pot := 0.0
	for p in GameManager.table.seats:
		if p != null:
			pot += p.contribution
	table_view.set_pot(pot)

	hud_view.set_status(
		"Anti-quest: %s" % _last_quest_name,
		GameManager.player.sentence_years,
		GameManager.player.contribution
	)
