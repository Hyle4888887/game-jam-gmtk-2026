extends Node

# Single source of randomness for the whole simulation. Every shuffle, tie-break,
# quest draw, AI jitter and new-prisoner sentence roll must go through this
# instance so a run is fully reproducible from its seed.

var _rng := RandomNumberGenerator.new()
var current_seed: int = 0


func seed_run(run_seed: int = -1) -> void:
	current_seed = run_seed if run_seed >= 0 else randi()
	_rng.seed = current_seed


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi() -> int:
	return _rng.randi()


## Fisher-Yates shuffle in place, using the seeded RNG.
func shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


## Pick a random element index, optionally excluding a set of indices (used for
## quest tie-breaks where some candidates have already been eliminated).
func pick_index(count: int) -> int:
	return _rng.randi_range(0, count - 1)
