class_name TableView
extends Control

## The poker table: 7 seats arranged in an ellipse, a community-card row in
## the middle, and a top info label (day/quest/hand). asset/other_pics/
## Background.jpg fills the whole screen behind everything - there's no
## separate table shape drawn on top of it, since the image already depicts
## the table itself.
##
## Built in code rather than a hand-authored .tscn - simpler to keep correct
## while the layout is still in flux.

const SEAT_SCENE := preload("res://view/seat_view.tscn")
const CARD_VIEW_SCENE := preload("res://view/card_view.tscn")
const CHIP_STACK_SCENE := preload("res://view/chip_stack_view.tscn")
const BACKGROUND_TEXTURE := preload("res://asset/other_pics/Background.jpg")
const NUM_SEATS := 7
const SEAT_SIZE := Vector2(120, 110)
const CARD_SIZE := Vector2(50, 72)
const CARD_SEPARATION := 8.0

var seats: Array = []
var community_cards: Array = []
var community_row: Control
var info_label: Label
var pot_label: Label
var pot_chips: ChipStackView
var room_background: TextureRect
# Cached by set_pot() every time it's called - lets animate_chip_slide look
# up "the pot as it stood right before this bet" without game_view having
# to separately track and pass that number through.
var _last_pot_amount: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	room_background = TextureRect.new()
	room_background.texture = BACKGROUND_TEXTURE
	room_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_background.clip_contents = true
	room_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_background)

	info_label = Label.new()
	info_label.position = Vector2(20, 10)
	info_label.add_theme_font_size_override("font_size", 20)
	add_child(info_label)

	# Plain Control with manually-positioned children, NOT a container that
	# auto-sizes from visible children: toggling CardView.visible would drop
	# a card from an HBoxContainer's size computation, which broke centering
	# (revealed community cards never actually appeared - all 5 slots stay
	# present via CardView.clear() instead of hiding nodes, see set_community).
	community_row = Control.new()
	community_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(community_row)
	for i in range(5):
		var cv: CardView = CARD_VIEW_SCENE.instantiate()
		# Not inside a Container (see the comment above on why), so nothing else
		# resizes this - explicitly matching CARD_SIZE here guards against the
		# .tscn's own baked size (whatever a future edit sets it to) silently
		# blowing the layout math above out of proportion again.
		cv.custom_minimum_size = CARD_SIZE
		cv.size = CARD_SIZE
		cv.position = Vector2(i * (CARD_SIZE.x + CARD_SEPARATION), 0)
		community_row.add_child(cv)
		cv.clear()
		community_cards.append(cv)

	pot_label = Label.new()
	pot_label.add_theme_font_size_override("font_size", 18)
	pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_label.custom_minimum_size = Vector2(120, 24)
	add_child(pot_label)

	pot_chips = CHIP_STACK_SCENE.instantiate()
	add_child(pot_chips)

	set_pot(0)

	for i in range(NUM_SEATS):
		var seat: SeatView = SEAT_SCENE.instantiate()
		seat.custom_minimum_size = SEAT_SIZE
		add_child(seat)
		seats.append(seat)

	resized.connect(_layout_seats)
	get_viewport().size_changed.connect(_layout_seats)
	call_deferred("_layout_seats")
	# Belt-and-suspenders: on some platforms (seen under Wayland) the
	# viewport hasn't resolved its real size by the first deferred call, so
	# a single retry after a full frame has processed catches that case
	# too instead of silently leaving every seat stacked at (0,0).
	get_tree().process_frame.connect(_layout_seats, CONNECT_ONE_SHOT)


func _layout_seats() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		# Still unresolved - fall back to the project's default window size
		# rather than leaving seats un-positioned; _layout_seats will be
		# called again (resized/size_changed/process_frame) once real size
		# is known and will correct this.
		vp = Vector2(1152, 648)
	var center := vp / 2.0
	var radius := Vector2(vp.x * 0.36, vp.y * 0.34)

	# Anchors (PRESET_FULL_RECT, set in _ready) should keep this filling the
	# screen on their own, but explicit sizing here matches the same
	# belt-and-suspenders approach used for seats below (see the Wayland
	# note on the process_frame connection) - cheap insurance against the
	# background silently staying at its pre-layout 0x0 size.
	room_background.size = vp
	room_background.position = Vector2.ZERO

	for i in range(NUM_SEATS):
		var theta := PI / 2.0 + i * TAU / float(NUM_SEATS)
		var point := center + Vector2(cos(theta), sin(theta)) * radius
		seats[i].position = point - SEAT_SIZE / 2.0

	var row_width: float = 5 * CARD_SIZE.x + 4 * CARD_SEPARATION
	community_row.position = Vector2(center.x - row_width / 2.0, center.y - CARD_SIZE.y / 2.0)
	pot_label.position = Vector2(center.x - 60, center.y - CARD_SIZE.y / 2.0 - 34)
	pot_chips.position = Vector2(center.x - pot_chips.custom_minimum_size.x / 2.0, center.y - CARD_SIZE.y / 2.0 - 34 - pot_chips.custom_minimum_size.y)


## `reveal_all` shows every hole card face-up (e.g. at showdown); otherwise
## only `player_id`'s own cards are shown face-up, everyone else gets backs.
func update_seats(prisoners: Array, player_id: int, dealer_index: int, reveal_all: bool = false) -> void:
	# Matches PokerEngine.play_hand's own sb_index/bb_index math exactly
	# (dealer+1, dealer+2 mod seat count) so the badges never disagree with
	# who's actually posting the blinds.
	var n := prisoners.size()
	var sb_index := (dealer_index + 1) % n if n > 0 else -1
	var bb_index := (dealer_index + 2) % n if n > 0 else -1

	for i in range(seats.size()):
		var seat: SeatView = seats[i]
		if i >= prisoners.size() or prisoners[i] == null:
			seat.visible = false
			continue
		var p = prisoners[i]
		seat.visible = true
		seat.set_prisoner_info(p.display_name, p.sentence_years)
		seat.set_contribution(p.contribution)
		var show_face: bool = reveal_all or p.id == player_id
		seat.set_hole_cards(p.hole_cards, show_face)
		seat.set_folded(p.folded)
		seat.set_dead(not p.is_alive)
		seat.set_dealer(i == dealer_index)
		if i == sb_index:
			seat.set_blind_role("SB")
		elif i == bb_index:
			seat.set_blind_role("BB")
		else:
			seat.set_blind_role("")


func set_community(cards: Array) -> void:
	for i in range(community_cards.size()):
		var cv: CardView = community_cards[i]
		if i < cards.size():
			# Only the newly-revealed slots should make noise - set_community
			# gets called again on later streets (turn/river) with the same
			# flop cards still in `cards`, so without this guard every street
			# would re-trigger the flip sound for cards already on the table.
			var is_new_reveal: bool = cv.card == null
			cv.set_card(cards[i], true)
			if is_new_reveal:
				SoundManager.play_card()
		else:
			cv.clear()


func set_info_text(text: String) -> void:
	info_label.text = text


## The pot always shows in whichever unit best fits its own size (years if
## it's grown to a year or more, months if less than that, etc) - a pot can
## swing across orders of magnitude within one hand, so a fixed unit would
## either read as a huge pile of seconds or a fraction of a year.
func set_pot(amount: float) -> void:
	pot_label.text = "Pot: %s" % TimeUnits.format_amount_best_unit(amount)
	pot_chips.set_amount(amount)
	_last_pot_amount = amount


func set_seat_action_text(seat_index: int, text: String) -> void:
	if seat_index >= 0 and seat_index < seats.size():
		seats[seat_index].set_action_text(text)


func clear_all_action_text() -> void:
	for seat in seats:
		seat.clear_action_text()


## Golden-tints the CardViews (hole + community) whose Card is in
## `winning_cards` (HandEvaluator.HandResult.cards - the actual 5-card combo
## used at showdown), and darkens every other currently-shown card so the
## winning combination actually stands out. Call this AFTER the seats have
## already been refreshed to reveal-all for this hand - refreshing again
## afterward would re-assign every CardView's card and silently reset the
## tint back to normal (see CardView._update_texture).
func highlight_winning_cards(winning_cards: Array) -> void:
	for cv in _all_card_views():
		if cv.card == null:
			cv.set_result_tint(CardView.ResultTint.NONE)
		elif cv.card in winning_cards:
			cv.set_result_tint(CardView.ResultTint.WINNER)
		else:
			cv.set_result_tint(CardView.ResultTint.LOSER)


func clear_highlights() -> void:
	for cv in _all_card_views():
		cv.set_result_tint(CardView.ResultTint.NONE)


## Animates a single real chip sprite sliding from `seat_index`'s seat to the
## pot, then removes itself. Purely cosmetic - contribution/pot numbers are
## already updated via set_pot()/SeatView.set_contribution() on the next
## refresh; this just gives that change some visible motion. `amount` (years)
## picks which denomination chip to show, via TimeUnits.best_unit_for.
func animate_chip_slide(seat_index: int, amount: float) -> void:
	if seat_index < 0 or seat_index >= seats.size():
		return
	var start_center: Vector2 = seats[seat_index].position + SEAT_SIZE / 2.0
	var end_center: Vector2 = pot_chips.position + pot_chips.custom_minimum_size / 2.0
	var sfx := SoundManager.sfx_for_bet(amount, _last_pot_amount)
	_animate_flying_chip(start_center, end_center, amount, 0.45, sfx)


## Animates the pot's chips sliding to the winning seat at showdown, then
## removes itself. Purely cosmetic, like animate_chip_slide but reversed and
## slower (0.9s - a "the pot is now yours" moment vs. a quick bet).
func animate_pot_to_seat(seat_index: int, amount: float) -> void:
	if seat_index < 0 or seat_index >= seats.size():
		return
	var start_center: Vector2 = pot_chips.position + pot_chips.custom_minimum_size / 2.0
	var end_center: Vector2 = seats[seat_index].position + SEAT_SIZE / 2.0
	_animate_flying_chip(start_center, end_center, amount, 0.9, "chip_tapis")


func _animate_flying_chip(start_center: Vector2, end_center: Vector2, amount: float, duration: float, landing_sfx: String) -> void:
	var chip_size := ChipStackView.DISPLAY_SIZE
	var chip := TextureRect.new()
	chip.texture = ChipStackView.chip_texture(TimeUnits.best_unit_for(amount), false)
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip.stretch_mode = TextureRect.STRETCH_SCALE
	chip.size = Vector2(chip_size, chip_size)
	chip.position = start_center - Vector2(chip_size, chip_size) / 2.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.z_index = 10
	add_child(chip)

	var tween := create_tween()
	tween.tween_property(chip, "position", end_center - Vector2(chip_size, chip_size) / 2.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Landing sound fires right as the chip actually reaches the pot/seat,
	# not after queue_free - queueing free() doesn't delay a frame, but
	# ordering the callback this way keeps the intent obvious if that ever
	# changes (e.g. an impact "squash" animation added before removal).
	tween.tween_callback(func(): SoundManager.play(landing_sfx, 0.04))
	tween.tween_callback(chip.queue_free)


func _all_card_views() -> Array:
	var result: Array = community_cards.duplicate()
	for seat in seats:
		result.append_array(seat.hole_cards)
	return result
