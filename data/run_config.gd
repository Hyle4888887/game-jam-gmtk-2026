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

@export var ante: int = 4
@export var small_blind: int = 5
@export var big_blind: int = 10
@export var blind_scale_every_days: int = 2
@export var blind_scale_factor: float = 1.5

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
		"ante": int(round(ante * mult)),
		"small_blind": int(round(small_blind * mult)),
		"big_blind": int(round(big_blind * mult)),
		"loss_penalty_factor": loss_penalty_factor,
	}
