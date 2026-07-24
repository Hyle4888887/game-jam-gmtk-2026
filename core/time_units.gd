class_name TimeUnits
extends RefCounted

## Pure display-layer time unit helpers. sentence_years (the authoritative
## win-check number, per graphify/Design - Rules.md §1) is always stored in
## years - these only reformat that same number for flavor/legibility: a
## seconds-equivalent readout next to every "X years" display, and a "best
## fit" unit (years if >= 1 year, months if less, ... down to seconds) for
## chip/blind/pot amounts so early-game numbers read as small legible values
## instead of huge raw seconds counts. RunConfig.ante/small_blind/big_blind
## are floats specifically so a blind can genuinely BE a sub-year amount
## (e.g. 30 seconds) rather than just being displayed as one - see
## RunConfig's own comment for why sentence_years/contribution had to become
## float throughout the engine to carry that.
##
## The 6 tiers here (no "weeks") match the 6 chip designs in the real chip
## art (asset/other_pics/jetons.png: Sec/Min/H/D/M/Y) - Unit's int value is
## the sprite sheet's column index, see ChipStackView.chip_texture.

enum Unit { SECONDS, MINUTES, HOURS, DAYS, MONTHS, YEARS }

const UNIT_NAMES := ["sec", "min", "hr", "day", "mo", "yr"]

const SECONDS_PER_YEAR := 31536000.0
const MINUTES_PER_YEAR := 525600.0
const HOURS_PER_YEAR := 8760.0
const DAYS_PER_YEAR := 365.0
const MONTHS_PER_YEAR := 12.0

const UNIT_FACTORS := [
	SECONDS_PER_YEAR,
	MINUTES_PER_YEAR,
	HOURS_PER_YEAR,
	DAYS_PER_YEAR,
	MONTHS_PER_YEAR,
	1.0,
]


## Auto-picks whichever unit best fits the VALUE's own magnitude (years if
## >= 1 year, months if >= 1 month but < 1 year, ... down to seconds).
static func best_unit_for(years: float) -> Unit:
	var abs_years := absf(years)
	if abs_years >= 1.0:
		return Unit.YEARS
	if abs_years >= 1.0 / MONTHS_PER_YEAR:
		return Unit.MONTHS
	if abs_years >= 1.0 / DAYS_PER_YEAR:
		return Unit.DAYS
	if abs_years >= 1.0 / HOURS_PER_YEAR:
		return Unit.HOURS
	if abs_years >= 1.0 / MINUTES_PER_YEAR:
		return Unit.MINUTES
	return Unit.SECONDS


static func format_amount_best_unit(years: float) -> String:
	var unit := best_unit_for(years)
	return _format(years * UNIT_FACTORS[unit], UNIT_NAMES[unit])


static func years_to_seconds(years: float) -> float:
	return years * SECONDS_PER_YEAR


static func _format(value: float, unit: String) -> String:
	if value == floor(value):
		return "%d %s" % [int(value), unit]
	return "%.1f %s" % [value, unit]
