class_name TickingSentenceLabel
extends Label

## Shows "X years (Y [unit])". The years number is the authoritative value
## (sentence_years, per graphify/Design - Rules.md §1) and only actually
## changes via set_years() (i.e. when a hand resolves). The parenthetical
## shows the REAL sub-year remainder in whichever unit best fits it (see
## TimeUnits.format_amount_best_unit) - early-game blinds are minutes/hours,
## far smaller than a whole year, so a change that only ever showed in the
## truncated "%d years" digit looked like betting/raising did nothing even
## though sentence_years genuinely moved every hand. This used to be a
## purely cosmetic ticking-down clock instead of the real remainder, which
## was itself part of that confusion (a fake number moving while the real
## one visibly didn't).

var _years: float = 0.0


func set_years(years: float) -> void:
	_years = maxf(years, 0.0)
	_update_text()


func _update_text() -> void:
	var whole_years := int(_years)
	var remainder: float = _years - float(whole_years)
	text = "%d years (%s)" % [whole_years, TimeUnits.format_amount_best_unit(remainder)]
