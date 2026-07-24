extends Node

# Headless check for TickingSentenceLabel: set_years() resyncs the text
# immediately, and the seconds parenthetical actually ticks down over time
# (purely cosmetic - the years number itself never changes except via a
# fresh set_years() call). Run via:
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
	_check(label.text.find("(") != -1 and label.text.find("sec)") != -1, "text includes a seconds-equivalent parenthetical")

	var seconds_before := label._display_seconds
	# Simulate real time passing without waiting for real wall-clock time.
	label._process(1.0)
	_check(label._display_seconds < seconds_before, "the seconds readout ticks down over (simulated) time")
	_check(label.text.begins_with("10 years"), "the years number itself does not change from ticking alone")

	label.set_years(-5)
	_check(label.text.begins_with("0 years"), "set_years() clamps a negative sentence to 0 for display")
	_check(label._display_seconds == 0.0, "a clamped-to-0 sentence resyncs the ticking seconds to 0 too")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: TickingSentenceLabel resyncs and ticks correctly")
		get_tree().quit(0)
