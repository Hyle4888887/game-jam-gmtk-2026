extends Node

# Headless check for TickingSentenceLabel: set_years() shows the whole-years
# count immediately, plus the REAL sub-year remainder (in whichever unit
# best fits it) so a change too small to move the whole-years digit is still
# visible. Run via:
#   godot --headless --path . res://sim/test_ticking_sentence_label.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var label := TickingSentenceLabel.new()
	add_child(label)

	label.set_years(10)
	_check(label.text.begins_with("10 years"), "set_years() shows the years number immediately")
	_check(label.text == "10 years (0 sec)", "a clean whole-year value shows a zero remainder")

	# A sub-year delta (e.g. a day-1 blind of a few minutes) doesn't move the
	# whole-years digit, but must still show up in the remainder - this is
	# the actual bug that motivated ditching the old cosmetic ticker: with a
	# plain "%d years" readout, a real change this small looked like nothing
	# happened at all.
	label.set_years(9.5)
	_check(label.text.begins_with("9 years"), "a sub-year change still floors to the correct whole-years digit")
	_check(label.text.find("6 mo") != -1, "the sub-year remainder shows in its own best-fit unit (6 months)")

	label.set_years(-5)
	_check(label.text.begins_with("0 years"), "set_years() clamps a negative sentence to 0 for display")
	_check(label.text == "0 years (0 sec)", "a clamped-to-0 sentence shows a zero remainder too")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: TickingSentenceLabel resyncs and ticks correctly")
		get_tree().quit(0)
