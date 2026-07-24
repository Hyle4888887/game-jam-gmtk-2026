extends Node

# Headless smoke test for ChipStackView, now backed by the real chip art
# (asset/other_pics/jetons.png). Run via:
#   godot --headless --path . res://sim/test_chip_stack_view.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var chips: ChipStackView = load("res://view/chip_stack_view.tscn").instantiate()
	add_child(chips)

	chips.set_amount(0)
	_check(not chips.visible, "zero amount hides the chip stack")

	# The label always shows the value in whichever unit best fits its own
	# magnitude (see TimeUnits.format_amount_best_unit) - 35 (raw engine
	# years) is >= 1 year, so it reads as "35 yr" and shows the YEARS chip.
	chips.set_amount(35)
	_check(chips.visible, "positive amount shows the chip icon")
	_check(chips.amount_label.text == TimeUnits.format_amount_best_unit(35), "amount label shows the best-unit-formatted number")
	_check(chips.chip_icon.texture != null, "a chip texture is assigned")

	var years_region: Rect2 = chips.chip_icon.texture.region
	var expected_years_region := ChipStackView.chip_texture(TimeUnits.Unit.YEARS, true).region
	_check(years_region == expected_years_region, "35 years shows the YEARS-denomination chip sprite")

	# chip_texture: single (row 0) vs stacked (row 1) must be different regions.
	var single := ChipStackView.chip_texture(TimeUnits.Unit.SECONDS, false)
	var stacked := ChipStackView.chip_texture(TimeUnits.Unit.SECONDS, true)
	_check(single.region != stacked.region, "single-chip and stacked-chip textures use different sprite sheet rows")
	_check(single.atlas == stacked.atlas, "both textures come from the same chip sprite sheet")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: ChipStackView chip-art visuals work correctly")
		get_tree().quit(0)
