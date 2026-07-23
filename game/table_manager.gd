class_name TableManager
extends RefCounted

## Owns the fixed-size seat list, fills empty/dead seats with fresh AI at the
## start of each day, and rotates the dealer button. See
## graphify/Design - Rules.md §5 and graphify/Architecture - Systems.md.
##
## New AI prisoners get tougher as the run progresses: day 0 skews toward
## "beginner" profiles (Calling Station, Rock - passive, non-threatening),
## the final day skews toward "veteran" profiles (Shark, Maniac - sharp,
## aggressive). Combined with RunConfig.blinds_for_day's escalating stakes,
## this gives the early days a soft on-ramp and the late days real teeth.

const BEGINNER_PROFILE_NAMES := ["Calling Station", "Rock"]
const VETERAN_PROFILE_NAMES := ["Shark", "Maniac"]

var seats: Array = []
var dealer_index: int = 0

var _next_ai_id: int = 1


func _init(table_size: int) -> void:
	seats.resize(table_size)


## Seats the player plus fresh AI to fill the table for day 0.
func seed_table(player: PrisonerState, config: RunConfig, rng_service, day_index: int = 0) -> void:
	seats[0] = player
	for i in range(1, seats.size()):
		seats[i] = _spawn_ai(config, rng_service, day_index)
	dealer_index = 0


## Fills any empty/dead seat with a fresh AI prisoner. Survivors keep their
## seat and sentence_years across days. `day_index` is the day about to be
## played, used to scale new AI difficulty.
func refill(config: RunConfig, rng_service, day_index: int = 0) -> void:
	for i in range(seats.size()):
		var p = seats[i]
		if p == null or not p.is_alive:
			seats[i] = _spawn_ai(config, rng_service, day_index)


func alive_prisoners() -> Array:
	var result: Array = []
	for p in seats:
		if p != null and p.is_alive:
			result.append(p)
	return result


func rotate_dealer() -> void:
	dealer_index = (dealer_index + 1) % seats.size()


func _spawn_ai(config: RunConfig, rng_service, day_index: int) -> PrisonerState:
	var sentence: int = rng_service.randi_range(config.ai_sentence_min, config.ai_sentence_max)
	var id: int = 1000 + _next_ai_id
	_next_ai_id += 1
	var p := PrisonerState.new(id, "Inmate %d" % id, sentence, false)
	p.ai_profile = _pick_profile_for_day(config, rng_service, day_index)
	return p


## Linearly ramps from all-beginner on day 0 to all-veteran on the final day.
static func _pick_profile_for_day(config: RunConfig, rng_service, day_index: int) -> AIProfile:
	if config.ai_profiles.is_empty():
		return AIProfile.shark()

	var last_day: int = max(1, config.x_days - 1)
	var veteran_chance: float = clampf(float(day_index) / float(last_day), 0.0, 1.0)

	var pool: Array = []
	var wanted_names: Array = VETERAN_PROFILE_NAMES if rng_service.randf() < veteran_chance else BEGINNER_PROFILE_NAMES
	for profile in config.ai_profiles:
		if profile.display_name in wanted_names:
			pool.append(profile)
	if pool.is_empty():
		pool = config.ai_profiles

	var idx: int = rng_service.pick_index(pool.size())
	return pool[idx]
