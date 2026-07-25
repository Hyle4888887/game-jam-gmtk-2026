extends Node

## Autoload (Project Settings > Autoload, name it "SoundManager").
## Central place for one-shot SFX so table_view.gd / game_view.gd don't
## each need their own AudioStreamPlayer bookkeeping. Uses a small pool of
## players so overlapping sounds (e.g. two chips landing at once) don't
## cut each other off.

const POOL_SIZE := 8

const SFX := {
	"card_a": "res://sounds/BruitDeCarte.wav",
	"card_b": "res://sounds/BruitDeCarte2.wav",
	"chip_petite": "res://sounds/JetonPetite.mp3",
	"chip_moyen": "res://sounds/JetonMoyen.mp3",
	"chip_grande": "res://sounds/JetonGrande.mp3",
	"chip_tapis": "res://sounds/JetonTapis.mp3",
	"tictac_lente": "res://sounds/TicTacLente.wav",
	"tictac_rapide": "res://sounds/TicTacRapide.wav",
}

# Two card-sound takes exist purely for variety - picking randomly between
# them avoids every single card flip/deal sounding like an identical clip
# played on a loop.
const CARD_VARIANTS := ["card_a", "card_b"]

var _pool: Array[AudioStreamPlayer] = []
var _next_player_index := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(p)
		_pool.append(p)


## `pitch_variance` randomizes pitch a little (e.g. 0.05) so repeated sounds
## in a fast sequence (a deal, several bets) don't sound mechanically
## identical. Fails silently if the asset name/path isn't found - lets
## sound get wired up before every asset necessarily exists.
func play(sfx_name: String, pitch_variance: float = 0.0, volume_db: float = 0.0) -> void:
	if not SFX.has(sfx_name):
		push_warning("SoundManager: unknown sfx '%s'" % sfx_name)
		return
	var stream := _load_cached(SFX[sfx_name])
	if stream == null:
		return

	var player := _pool[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.volume_db = volume_db
	player.play()


## Convenience wrapper for any card movement (deal or flip): picks one of
## the two BruitDeCarte takes at random.
func play_card(pitch_variance: float = 0.06) -> void:
	play(CARD_VARIANTS[randi() % CARD_VARIANTS.size()], pitch_variance)


## Picks which chip sound fits a bet, scaled by how big this bet is
## relative to the pot it's landing in - not by its absolute amount, since
## blinds/pots escalate a lot over a run (see RunConfig.blinds_for_day) and
## a fixed year/month threshold would feel "wrong-sized" by day 10.
## `pot_before` should be the pot's value BEFORE this contribution is added.
func sfx_for_bet(amount: float, pot_before: float) -> String:
	if pot_before <= 0.0:
		return "chip_petite"
	var ratio := amount / pot_before
	if ratio < 0.5:
		return "chip_petite"
	elif ratio < 1.5:
		return "chip_moyen"
	else:
		return "chip_grande"


func _load_cached(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("SoundManager: missing asset '%s'" % path)
		_cache[path] = null
		return null
	var stream: AudioStream = load(path)
	_cache[path] = stream
	return stream
