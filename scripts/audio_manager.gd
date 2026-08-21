extends Node
## Central audio service, registered as the `Audio` autoload.
##
## Holds one music player plus a small pool of interchangeable one-shot
## players, so any script can fire a sound with `Audio.play_sfx("...")`
## without owning AudioStreamPlayer nodes of its own. Overlapping sounds
## (a tile tap during an impact) grab separate players from the pool.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## Music sits well under the effects so hits and clicks stay legible.
const MUSIC_VOLUME_DB := -16.0
const SFX_VOLUME_DB := -5.0
## How many effects can overlap before the oldest is recycled.
const SFX_POLYPHONY := 8

const MUSIC := {
	"battle": "res://assets/audio/music/battle_theme.ogg",
	"victory": "res://assets/audio/music/victory.ogg",
	"defeat": "res://assets/audio/music/defeat.ogg",
}

const SFX := {
	"tile_tap": "res://assets/audio/sfx/tile_tap.ogg",
	"word_accepted": "res://assets/audio/sfx/word_accepted.ogg",
	"word_rejected": "res://assets/audio/sfx/word_rejected.ogg",
	"attack_impact": "res://assets/audio/sfx/attack_impact.ogg",
	"take_damage": "res://assets/audio/sfx/take_damage.ogg",
	"potion": "res://assets/audio/sfx/potion.ogg",
	"shuffle": "res://assets/audio/sfx/shuffle.ogg",
	"button_click": "res://assets/audio/sfx/button_click.ogg",
	# Vocal hit reactions. These are arrays: play_sfx picks one at random, so a
	# long fight doesn't repeat the same yelp on every single exchange. The
	# player's are human, the enemies' are creature-ish, which keeps who just
	# got hit audible without looking at the screen.
	"player_hurt": [
		"res://assets/audio/sfx/player_hurt_1.ogg",
		"res://assets/audio/sfx/player_hurt_2.ogg",
		"res://assets/audio/sfx/player_hurt_3.ogg",
	],
	"enemy_hurt": [
		"res://assets/audio/sfx/enemy_hurt_1.ogg",
		"res://assets/audio/sfx/enemy_hurt_2.ogg",
		"res://assets/audio/sfx/enemy_hurt_3.ogg",
	],
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0

func _ready() -> void:
	_ensure_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in SFX_POLYPHONY:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

## Music and SFX live on their own buses so the balance between them is a
## single volume value each, rather than a gain baked into every clip.
func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), MUSIC_VOLUME_DB)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), SFX_VOLUME_DB)

## Starting the track that's already playing is a no-op, so moving from the
## title screen into a battle carries the same loop across without a restart.
func play_music(key: String) -> void:
	var stream := _load_stream(MUSIC.get(key, ""))
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_set_loop(stream, true)
	_music_player.stream = stream
	_music_player.play()

## One-shot music: stops the loop and plays a sting through to its end
## (victory fanfare, defeat sting).
func play_sting(key: String) -> void:
	var stream := _load_stream(MUSIC.get(key, ""))
	if stream == null:
		return
	_set_loop(stream, false)
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

## An SFX entry is either a single path or an array of interchangeable takes;
## an array picks one at random each call.
func play_sfx(key: String) -> void:
	var stream := _load_stream(_resolve_sfx_path(key))
	if stream == null:
		return
	var player := _claim_sfx_player()
	player.stream = stream
	player.play()

## Per-skill audio, looked up by path rather than through the SFX table above.
##
## Thirty entries (fifteen skills x cast/impact) would swamp that table for no
## benefit: the files are named after the move id, so the path IS the lookup.
## A skill with no audio on disk falls back to the shared impact sound, which
## keeps a half-authored move audible instead of silent.
const MOVE_SFX_DIR := "res://assets/audio/sfx/moves"

func play_move_sfx(move_id: String, phase: String) -> void:
	if move_id.is_empty():
		play_sfx("attack_impact")
		return
	var path := "%s/%s_%s.wav" % [MOVE_SFX_DIR, move_id, phase]
	var stream := _load_stream(path)
	if stream == null:
		# Only the impact is worth substituting; a missing cast should stay
		# silent rather than fire an unrelated noise during the wind-up.
		if phase == "hit":
			play_sfx("attack_impact")
		return
	var player := _claim_sfx_player()
	player.stream = stream
	player.play()

## True when a skill has its own file for that phase — used by the test that
## asserts every move in the game actually got its own audio.
func has_move_sfx(move_id: String, phase: String) -> bool:
	return ResourceLoader.exists("%s/%s_%s.wav" % [MOVE_SFX_DIR, move_id, phase])

func _resolve_sfx_path(key: String) -> String:
	var entry: Variant = SFX.get(key, "")
	if entry is Array:
		var takes: Array = entry
		if takes.is_empty():
			return ""
		return String(takes[randi() % takes.size()])
	return String(entry)

func set_music_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), db)

func set_sfx_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), db)

## Volume sliders (title screen, pause menu) work in 0-100, where 100 is the
## mix's designed level, not 0 dB — so the balance already tuned above stays
## intact and the slider only ever attenuates from there. Shared here so
## every settings screen maps the same way instead of re-deriving it.
func set_music_volume_percent(percent: float) -> void:
	set_music_volume_db(_percent_to_db(percent, MUSIC_VOLUME_DB))

func set_sfx_volume_percent(percent: float) -> void:
	set_sfx_volume_db(_percent_to_db(percent, SFX_VOLUME_DB))

## The inverse of the two setters above, read back from the bus.
##
## A settings screen has to open showing the level actually in force; assuming
## 100 is how a panel ends up claiming full volume on a muted game. Kept beside
## _percent_to_db for the reason given above -- one place owns the mapping, so
## the two directions cannot drift apart.
func music_volume_percent() -> float:
	return _db_to_percent(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS)), MUSIC_VOLUME_DB)

func sfx_volume_percent() -> float:
	return _db_to_percent(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SFX_BUS)), SFX_VOLUME_DB)

func _db_to_percent(db: float, base_db: float) -> float:
	# -80 dB is the floor _percent_to_db uses for silence, not a real level.
	if db <= -80.0:
		return 0.0
	return clampf(db_to_linear(db - base_db) * 100.0, 0.0, 100.0)

func _percent_to_db(percent: float, base_db: float) -> float:
	if percent <= 0.0:
		return -80.0
	return base_db + linear_to_db(percent / 100.0)

func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("AudioManager: missing stream %s" % path)
		return null
	return load(path) as AudioStream

## Looping is a property of the stream resource, not the player, and the two
## importable formats expose it separately.
func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)

## Prefers an idle player; falls back to recycling round-robin so a burst of
## sounds never silently drops the newest one.
func _claim_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var recycled := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	return recycled
