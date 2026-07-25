extends Node

## Autoload (Project Settings > Autoload, name it "MusicManager").
## Handles background music with seamless looping and simple fade in/out.
## Only `play_in_game()` is actually called anywhere yet (no menu/game-over
## screens exist), but "menu"/"game_over" are declared now since the audio
## files already exist in res://musics/ - wiring those two in later is then
## just a one-line MusicManager.play("menu"/"game_over") call, no new code.

const TRACKS := {
	"in_game": "res://musics/MusicInGame.mp3",
	"menu": "res://musics/MusicMenu.mp3",
	"game_over": "res://musics/MusicGameOver.mp3",
}

var _player: AudioStreamPlayer
var _current_track: String = ""
var _fade_tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_player)


## Starts `track_name` looping. Calling play() again with the SAME track
## that's already playing is a no-op (doesn't restart/pop) - this matters
## because game_view._ready() can in principle re-run in edge cases (e.g.
## a future "restart run" flow), and restarting music from 0 on that would
## be jarring rather than just continuing.
func play(track_name: String, fade_in: float = 1.0) -> void:
	if not TRACKS.has(track_name):
		push_warning("MusicManager: unknown track '%s'" % track_name)
		return
	if track_name == _current_track and _player.playing:
		return

	var path: String = TRACKS[track_name]
	if not ResourceLoader.exists(path):
		push_warning("MusicManager: missing asset '%s'" % path)
		return
	var stream: AudioStream = load(path)

	# Godot loops MP3/OggVorbis streams natively via this flag - no need to
	# reconnect the `finished` signal and manually replay, which is prone
	# to an audible gap/click at the loop point.
	if stream is AudioStreamMP3:
		stream.loop = true

	if _fade_tween != null:
		_fade_tween.kill()

	_player.stream = stream
	_current_track = track_name
	_player.play()

	if fade_in > 0.0:
		_player.volume_db = -40.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", 0.0, fade_in)
	else:
		_player.volume_db = 0.0


func play_in_game(fade_in: float = 1.5) -> void:
	play("in_game", fade_in)


func stop(fade_out: float = 1.0) -> void:
	if not _player.playing:
		return
	if _fade_tween != null:
		_fade_tween.kill()
	if fade_out > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", -40.0, fade_out)
		_fade_tween.tween_callback(_player.stop)
	else:
		_player.stop()
	_current_track = ""
