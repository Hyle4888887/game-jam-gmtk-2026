extends SceneTree

# Headless check for TimeUnits.format_amount_best_unit/best_unit_for: picks
# whichever of the 6 unit tiers (sec/min/hr/day/mo/yr - matching the 6 chip
# designs in asset/other_pics/jetons.png exactly, no "weeks" tier) best fits
# a VALUE's own magnitude. Pure data, no autoload dependency, so plain
# --script mode works. Run via:
#   godot --headless --path . --script res://sim/test_time_units.gd

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _initialize() -> void:
	_check(TimeUnits.years_to_seconds(1.0) == TimeUnits.SECONDS_PER_YEAR, "years_to_seconds(1) matches SECONDS_PER_YEAR exactly")
	_check(TimeUnits.years_to_seconds(0.0) == 0.0, "years_to_seconds(0) is 0")

	# 6 tiers, matching the 6 chip designs (Sec/Min/H/D/M/Y) in
	# asset/other_pics/jetons.png - Unit's int value is that sheet's column
	# index (see ChipStackView.chip_texture), so this ordering matters.
	_check(TimeUnits.best_unit_for(2.5) == TimeUnits.Unit.YEARS, "1+ year value picks YEARS")
	_check(TimeUnits.best_unit_for(1.0) == TimeUnits.Unit.YEARS, "exactly 1 year picks YEARS, not 12 months")
	_check(TimeUnits.best_unit_for(6.0 / 12.0) == TimeUnits.Unit.MONTHS, "half a year picks MONTHS")
	_check(TimeUnits.best_unit_for(1.0 / 12.0) == TimeUnits.Unit.MONTHS, "exactly 1 month picks MONTHS, not days")
	_check(TimeUnits.best_unit_for(3.0 / 365.0) == TimeUnits.Unit.DAYS, "a few days picks DAYS")
	_check(TimeUnits.best_unit_for(1.0 / 365.0) == TimeUnits.Unit.DAYS, "exactly 1 day picks DAYS, not hours")
	_check(TimeUnits.best_unit_for(5.0 / 8760.0) == TimeUnits.Unit.HOURS, "a few hours picks HOURS")
	_check(TimeUnits.best_unit_for(1.0 / 8760.0) == TimeUnits.Unit.HOURS, "exactly 1 hour picks HOURS, not minutes")
	_check(TimeUnits.best_unit_for(30.0 / 525600.0) == TimeUnits.Unit.MINUTES, "a half hour picks MINUTES")
	_check(TimeUnits.best_unit_for(1.0 / 525600.0) == TimeUnits.Unit.MINUTES, "exactly 1 minute picks MINUTES, not seconds")
	_check(TimeUnits.best_unit_for(15.0 / TimeUnits.SECONDS_PER_YEAR) == TimeUnits.Unit.SECONDS, "anything under a minute picks SECONDS")
	_check(TimeUnits.best_unit_for(0.0) == TimeUnits.Unit.SECONDS, "zero picks SECONDS, the smallest unit")

	_check(TimeUnits.format_amount_best_unit(1.0) == "1 yr", "format_amount_best_unit formats using the picked unit's name")
	_check(TimeUnits.format_amount_best_unit(6.0 / 12.0) == "6 mo", "format_amount_best_unit converts into the picked unit's scale")

	# Realistic engine values: a raw blind of a few years now reads as a
	# legible years figure instead of a huge raw seconds count - this is the
	# actual bug that motivated switching everything to best-unit.
	_check(TimeUnits.format_amount_best_unit(5) == "5 yr", "a 5-year blind reads as '5 yr', not hundreds of millions of seconds")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		quit(1)
	else:
		print("PASSED: TimeUnits best-unit selection is correct")
		quit(0)
