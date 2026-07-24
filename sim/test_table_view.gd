extends Node

# Headless smoke test for the TableView scene: instances it, feeds it a
# fake 7-seat table (with hole cards, folded/dead flags, dealer index) and
# some community cards, and checks nothing throws. Doesn't verify pixels -
# see the `run` skill screenshot pass for that. Run via:
#   godot --headless --path . res://sim/test_table_view.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var table_view: TableView = load("res://view/table_view.tscn").instantiate()
	add_child(table_view)
	table_view.size = Vector2(1152, 648)

	var prisoners: Array = []
	for i in range(7):
		var p := PrisonerState.new(i, "Prisoner %d" % i, 100 + i, i == 0)
		p.deal_hole(Card.new(Card.Suit.HEART, 13), Card.new(Card.Suit.DIAMOND, 10))
		if i == 2:
			p.folded = true
		if i == 5:
			p.is_alive = false
		prisoners.append(p)

	table_view.update_seats(prisoners, 0, 3)
	_check(table_view.seats[0].visible, "seat 0 visible after update_seats")
	_check(table_view.seats.size() == 7, "table has 7 seat views")

	# SB/BB badges: dealer_index=3, 7 seats -> sb=(3+1)%7=4, bb=(3+2)%7=5,
	# matching PokerEngine.play_hand's own math exactly.
	_check(table_view.seats[4].blind_label.text == "SB", "small blind badge is on the correct seat")
	_check(table_view.seats[5].blind_label.text == "BB", "big blind badge is on the correct seat")
	_check(table_view.seats[3].blind_label.text == "", "the dealer's own seat has no blind badge")
	_check(table_view.seats[0].blind_label.text == "", "an unrelated seat has no blind badge")

	# All 5 community slots stay visible=true always now (see table_view.gd):
	# an HBoxContainer dropping invisible children from its size computation
	# was what broke community card centering in the first place. Revealed
	# vs. unrevealed is distinguished by CardView.card being set vs cleared.
	var community: Array = [Card.new(Card.Suit.SPADE, 5), Card.new(Card.Suit.CLOVER, 9), Card.new(Card.Suit.HEART, 2)]
	table_view.set_community(community)
	_check(table_view.community_cards[0].visible, "community card slots stay visible")
	_check(table_view.community_cards[0].card != null, "1st community card is revealed (card set)")
	_check(table_view.community_cards[4].card == null, "unrevealed community card slot has no card")

	table_view.set_info_text("Day 1 - Quest: The Coward")
	_check(table_view.info_label.text == "Day 1 - Quest: The Coward", "info label text set correctly")

	# Force the deferred layout to run now instead of waiting a frame.
	table_view._layout_seats()
	_check(table_view.seats[0].position != Vector2.ZERO, "seats are actually positioned by the ellipse layout")
	_check(table_view.community_row.position != Vector2.ZERO, "community row is actually positioned (not stuck at origin)")

	# graphify/Design - Rules.md §1: sentence_years can go negative internally
	# (a big enough win overshoots 0) but must clamp to 0 for display.
	var negative_seat: SeatView = load("res://view/seat_view.tscn").instantiate()
	add_child(negative_seat)
	negative_seat.set_prisoner_info("Overachiever", -50)
	_check(negative_seat.sentence_label.text.begins_with("0 years"), "negative sentence_years clamps to 0 for display")

	# Pot always shows in whichever unit best fits its own magnitude (see
	# TimeUnits.format_amount_best_unit) - 240 years stays in years since
	# it's already >= 1 year.
	table_view.set_pot(240)
	_check(table_view.pot_label.text == "Pot: 240 yr", "pot label reflects set_pot() in its best-fit unit")

	# Per-seat action text (shown above that player's seat, not a shared
	# corner label - see SeatView.action_label).
	table_view.set_seat_action_text(2, "RAISES 5 yr")
	_check(table_view.seats[2].action_label.text == "RAISES 5 yr", "set_seat_action_text sets only the targeted seat's action label")
	_check(table_view.seats[3].action_label.text == "", "other seats' action labels are untouched")

	table_view.set_seat_action_text(-1, "should be ignored")
	table_view.set_seat_action_text(999, "should be ignored")
	_check(table_view.seats[2].action_label.text == "RAISES 5 yr", "out-of-range seat indices are ignored, no crash")

	table_view.clear_all_action_text()
	_check(table_view.seats[2].action_label.text == "", "clear_all_action_text clears every seat's action label")

	# Highlighting: the winning hand's 5 cards should tint gold, every other
	# currently-shown card should darken (not just stay neutral) so the
	# winning combination actually stands out.
	# Only 3 of 5 community slots were dealt a card above (indices 3-4 are
	# still cleared/empty) - the winning combo intentionally excludes
	# community[2] so there's a REAL, revealed, non-winning community card
	# to check darkening against (an empty slot has nothing to darken).
	var winner_hole: Array = prisoners[0].hole_cards
	var winning_combo: Array = [winner_hole[0], winner_hole[1], community[0], community[1]]
	table_view.highlight_winning_cards(winning_combo)
	_check(table_view.seats[0].hole_cards[0].modulate == CardView.HIGHLIGHT_TINT, "a card in the winning combo is highlighted")
	_check(table_view.seats[1].hole_cards[0].modulate == CardView.DARK_TINT, "a non-winning player's card is darkened")
	_check(table_view.community_cards[0].modulate == CardView.HIGHLIGHT_TINT, "a winning community card is highlighted")
	_check(table_view.community_cards[2].modulate == CardView.DARK_TINT, "a non-winning (but revealed) community card is darkened")
	_check(table_view.community_cards[3].modulate == CardView.NORMAL_TINT, "an empty/unrevealed community slot is neither highlighted nor darkened")

	table_view.clear_highlights()
	_check(table_view.seats[0].hole_cards[0].modulate == CardView.NORMAL_TINT, "clear_highlights() resets everything back to normal")

	# Chip-slide animation: a transient chip node should appear as a new
	# child and animate itself away (checked by child count, not pixels -
	# see the `run` skill / manual verification for the actual visual).
	var children_before := table_view.get_child_count()
	table_view.animate_chip_slide(1, 20)
	_check(table_view.get_child_count() == children_before + 1, "animate_chip_slide adds one transient chip node")
	table_view.animate_chip_slide(-1, 20)
	table_view.animate_chip_slide(999, 20)
	_check(table_view.get_child_count() == children_before + 1, "out-of-range seat indices are ignored, no crash")

	# Pot-to-winner animation (reversed direction, slower duration - see
	# TableView.animate_pot_to_seat).
	var children_before_pot := table_view.get_child_count()
	table_view.animate_pot_to_seat(0, 50)
	_check(table_view.get_child_count() == children_before_pot + 1, "animate_pot_to_seat adds one transient chip node")
	table_view.animate_pot_to_seat(-1, 50)
	table_view.animate_pot_to_seat(999, 50)
	_check(table_view.get_child_count() == children_before_pot + 1, "animate_pot_to_seat ignores out-of-range seat indices, no crash")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: TableView wiring works headlessly")
		get_tree().quit(0)
