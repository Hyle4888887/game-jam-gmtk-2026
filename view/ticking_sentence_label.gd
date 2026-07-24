class_name TickingSentenceLabel
extends Label

## Shows "X years (Y sec)". The years number is the authoritative value
## (sentence_years, per graphify/Design - Rules.md §1) and only actually
## changes via set_years() (i.e. when a hand resolves) - the seconds
## parenthetical visually ticks down continuously between updates for a
## countdown-clock feel, purely cosmetic, and resyncs to the true
## years-derived value on every set_years() call so it never really drifts.

const TICK_RATE := 30.0

var _years: float = 0.0
var _display_seconds: float = 0.0


func set_years(years: float) -> void:
	_years = maxf(years, 0.0)
	_display_seconds = TimeUnits.years_to_seconds(_years)
	_update_text()


func _process(delta: float) -> void:
	if _display_seconds <= 0.0:
		return
	_display_seconds = max(_display_seconds - delta * TICK_RATE, 0.0)
	_update_text()


func _update_text() -> void:
	text = "%d years (%s sec)" % [int(_years), _format_with_commas(int(_display_seconds))]


static func _format_with_commas(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result
