class_name DeathResolver
extends RefCounted

## Executes the 2 daily deaths and mutates the victims' is_alive flag.
## See graphify/Design - Rules.md §6.
##
## Death 1: the alive prisoner with the most sentence_years (RNG tie-break).
## Death 2: whoever best matches the daily quest, excluding Death 1.
## Emits GameManager.prisoner_died for each victim.
static func resolve(prisoners: Array, quest: Quest, stats: StatsTracker, rng_service) -> Array:
	var alive: Array = []
	for p in prisoners:
		if p.is_alive:
			alive.append(p)

	# prisoner -> cause string, built alongside victims so the degenerate
	# branch below can't be mislabeled by inferring death1/death2 from index.
	var causes: Dictionary = {}
	var victims: Array = []

	if alive.size() < 2:
		# Degenerate case (shouldn't happen with table_size=7, deaths_per_day=2
		# and refill-to-7 each day) - execute whoever is left rather than crash.
		for p in alive:
			victims.append(p)
			causes[p] = "table_depleted"
	else:
		var max_sentence: int = alive[0].sentence_years
		var max_candidates: Array = [alive[0]]
		for i in range(1, alive.size()):
			var p = alive[i]
			if p.sentence_years > max_sentence:
				max_sentence = p.sentence_years
				max_candidates = [p]
			elif p.sentence_years == max_sentence:
				max_candidates.append(p)
		var death1: PrisonerState = max_candidates[rng_service.pick_index(max_candidates.size())]
		causes[death1] = "highest_sentence"
		victims.append(death1)

		var death2: PrisonerState = QuestManager.evaluate(quest, alive, stats, [death1], rng_service)
		if death2 != null:
			causes[death2] = quest.id
			victims.append(death2)

	for v in victims:
		v.is_alive = false
		GameManager.prisoner_died.emit(v.id, causes[v])

	return victims
