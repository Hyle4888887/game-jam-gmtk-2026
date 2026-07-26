extends Node

# Headless smoke test for HandResultPopup: instances it, checks it starts
# hidden, and that show_result()/hide_result() produce the right text for
# both a showdown win and a win-by-everyone-else-folded. Run via:
#   godot --headless --path . res://sim/test_hand_result_popup.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var popup: HandResultPopup = load("res://view/hand_result_popup.tscn").instantiate()
	add_child(popup)
	popup.size = Vector2(1152, 648)
	_check(not popup.visible, "HandResultPopup starts hidden")

	popup._layout()
	var vp := popup.get_viewport_rect().size
	# Horizontally centered but in the thin top strip, not dead center - dead
	# center would sit right on top of TableView's community-card row/
	# highlighted winning cards, which is exactly what this popup announces.
	var expected_position := Vector2((vp.x - HandResultPopup.PANEL_SIZE.x) / 2.0, HandResultPopup.TOP_MARGIN)
	_check(popup._panel.size == HandResultPopup.PANEL_SIZE, "panel has its real fixed size, not 0x0")
	_check(popup._panel.position.is_equal_approx(expected_position), "panel is horizontally centered but sits in the thin top strip, clear of the community cards")

	# Regression check for the real bug: TableView's 7-seat ellipse packs its
	# two topmost seats (index 3/4 of 7 - nearest theta=3PI/2) close enough to
	# the top that a popup sized/positioned for "clear of the community row"
	# alone still covered THEIR hole cards. Mirror TableView._layout_seats'
	# own math here so this actually catches a regression instead of
	# hardcoding a number that could quietly drift out of sync.
	var center := vp / 2.0
	var radius := Vector2(vp.x * 0.36, vp.y * 0.34)
	var topmost_seat_top := INF
	for i in range(TableView.NUM_SEATS):
		var theta: float = PI / 2.0 + i * TAU / float(TableView.NUM_SEATS)
		var seat_top: float = center.y + sin(theta) * radius.y - TableView.SEAT_SIZE.y / 2.0
		topmost_seat_top = min(topmost_seat_top, seat_top)
	_check(
		popup._panel.position.y + HandResultPopup.PANEL_SIZE.y < topmost_seat_top,
		"panel's bottom edge stays above every seat's top edge, including the two nearest the top of the ellipse (regression check for hiding a winner's own hole cards)"
	)

	popup.show_result(["Alice"], "Flush")
	_check(popup.visible, "show_result() makes it visible")
	_check(popup._winner_label.text == "WINNER IS Alice", "winner label names the single winner")
	_check(popup._detail_label.text == "won with Flush", "detail label shows the hand category")

	# Split pot: a tie erases each tied winner's own contribution (see
	# graphify/Design - Rules.md §3) - both names should show, not just one.
	popup.show_result(["Alice", "Bob"], "Two Pair")
	_check(popup._winner_label.text == "WINNER IS Alice, Bob", "winner label lists every tied winner")

	# Win-by-everyone-else-folded: null category_text, no showdown to compare.
	popup.show_result(["Carol"], null)
	_check(popup._detail_label.text == "won (everyone else folded)", "detail label handles the no-showdown case")

	popup.hide_result()
	_check(not popup.visible, "hide_result() hides it again")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: HandResultPopup shows/hides the right winner text")
		get_tree().quit(0)
