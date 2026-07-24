class_name QuestManager
extends RefCounted

## Draws and evaluates the daily anti-quest. See graphify/Design - Rules.md §6.


static func draw_daily_quest(pool: Array, rng_service) -> Quest:
	assert(pool.size() > 0, "quest pool must not be empty")
	var idx: int = rng_service.pick_index(pool.size())
	return pool[idx]


## Returns the prisoner(s) that best match `quest`'s metric among `prisoners`,
## excluding anyone in `exclude` (e.g. the prisoner already chosen by Death 1).
## Ties are broken via rng_service. Returns null if nobody is eligible.
static func evaluate(quest: Quest, prisoners: Array, stats: StatsTracker, exclude: Array = [], rng_service = null) -> PrisonerState:
	var candidates: Array = []
	for p in prisoners:
		if not (p in exclude):
			candidates.append(p)
	if candidates.is_empty():
		return null

	var best_value: float = stats.metric(candidates[0].id, quest.metric_key)
	var best_list: Array = [candidates[0]]
	for i in range(1, candidates.size()):
		var p = candidates[i]
		var v: float = stats.metric(p.id, quest.metric_key)
		var better: bool = v > best_value if quest.pick == Quest.Pick.MAX else v < best_value
		if better:
			best_value = v
			best_list = [p]
		elif v == best_value:
			best_list.append(p)

	if best_list.size() == 1:
		return best_list[0]

	var idx: int = rng_service.pick_index(best_list.size()) if rng_service != null else 0
	return best_list[idx]
