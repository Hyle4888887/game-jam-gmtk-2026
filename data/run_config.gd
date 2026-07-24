class_name RunConfig
extends Resource

## All the tunable knobs for a run, per graphify/Design - Rules.md §8.
## Keep every balance number here, not hardcoded in logic.

@export var x_days: int = 7
@export var starting_sentence: int = 142
@export var ai_sentence_min: int = 120
@export var ai_sentence_max: int = 160
@export var table_size: int = 7
@export var deaths_per_day: int = 2
@export var hands_per_day: int = 15

## Blinds/ante are years (float, not int) specifically so day 1 can open at
## a genuinely tiny fraction of a year - 30 seconds / 1 minute - per real
## playtesting feedback that even 1/2 years felt like a steep opening bet.
## sentence_years/contribution had to become float throughout the engine to
## carry values this small without rounding/truncating to 0 every hand (that
## was the actual cause of "raising doesn't change my years": int(round(...))
## in PokerEngine/StatsTracker was flooring sub-1-year deltas away). Re-verify
## with the M7 balance harness if this changes again - see loss_penalty_factor
## below for the last time this mattered.
@export var ante: float = 0.0
@export var small_blind: float = 30.0 / TimeUnits.SECONDS_PER_YEAR
@export var big_blind: float = 60.0 / TimeUnits.SECONDS_PER_YEAR
## Escalates once PER DAY (not every 2 days) at 10x per step - a 1.5x/2-day
## curve made sense when day 1 opened at 1/2 years, but starting from a
## 30sec/1min opening blind needs a MUCH steeper ramp to ever become
## meaningful against a 142-year sentence within a 7-day run. 10x/day for 6
## steps (day 0 -> day 6) takes the big blind from 1 minute through roughly
## an hour, a day, a month, and lands at ~1.9 years by day 7 - conveniently
## climbing through almost exactly the same 6 tiers (sec/min/hr/day/mo/yr)
## the chip art and TimeUnits already use, so the escalation itself reads as
## "today's stakes are a new denomination of chip." Re-verify with the M7
## balance harness - this changes the difficulty ramp substantially.
@export var blind_scale_every_days: int = 1
@export var blind_scale_factor: float = 10.0

## Bet-to-lose is deliberately not zero-sum (graphify/Design - Rules.md §3):
## every hand, the winner erases their FULL contribution but every other
## player independently adds theirs. At a 7-handed table that's 1 winner
## netting down vs. ~6 losers netting up per hand, which makes an average
## player's sentence trend upward almost regardless of skill - the M7
## balance harness measured ~0% win-rate even with an opponent-modeling
## player AI, because avoiding being the day's worst-off is dominated by
## table-wide variance, not individual play. loss_penalty_factor scales down
## how much a NON-winning contribution adds (winners still erase 100% of
## their own), so an average/skilled player isn't structurally guaranteed to
## drift upward every hand. 0.25 was chosen so a player winning modestly
## more than the 1/7 baseline trends toward 0 rather than treading water or
## climbing - retune via the M7 harness if the difficulty ramp changes.
@export_range(0.0, 1.0) var loss_penalty_factor: float = 0.25

@export var win_at_or_below: int = 0
## -1 means "randomize" (RNGService.seed_run treats negative as randi()); set
## to a specific value for a reproducible run.
@export var seed: int = -1

@export var quest_pool: Array[Quest] = []
@export var ai_profiles: Array[AIProfile] = []


## Blinds/ante escalate every `blind_scale_every_days` days to keep late hands
## meaningful, per graphify/Design - Rules.md §4.
func blinds_for_day(day_index: int) -> Dictionary:
	var steps := int(floor(float(day_index) / float(blind_scale_every_days)))
	var mult := pow(blind_scale_factor, steps)
	return {
		"ante": ante * mult,
		"small_blind": small_blind * mult,
		"big_blind": big_blind * mult,
		"loss_penalty_factor": loss_penalty_factor,
	}
