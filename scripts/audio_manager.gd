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
	"menu": "res://assets/audio/music/menu_theme.ogg",
	"battle": "res://assets/audio/music/battle_theme.ogg",
	"victory": "res://assets/audio/music/victory.ogg",
	"defeat": "res://assets/audio/music/defeat.ogg",
}

## Per-track level match, applied on the player rather than baked into the file.
##
## The tracks were not mastered together: the menu theme is 4 LU quieter than
## the battle theme, so on one shared bus volume the title screen would sound
## like the game had been turned down. Correcting it here keeps the source audio
## untouched and puts the balance somewhere it can be read and re-tuned, instead
## of hiding it in a re-encode nobody can see.
const MUSIC_TRIM_DB := {
	"menu": 4.0,
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
## Whether the player has interacted with the page yet, and the music request
## being held until they do. See _input.
var _user_gestured: bool = false
var _pending_music: String = ""

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
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = SFX_BUS
	# A voice should sit slightly above the impact noise it arrives with,
	# otherwise the grunt is buried under its own hit.
	_voice_player.volume_db = 2.0
	add_child(_voice_player)

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

## Requesting the track that is already playing is a no-op, so a scene that
## re-asks for the loop it is already under does not restart it mid-phrase.
func play_music(key: String) -> void:
	if not _user_gestured:
		# Held, not dropped: the browser will refuse this, and the request is
		# replayed the moment the player touches anything. See _input.
		_pending_music = key
		return
	_start_music(key, true)

## One-shot music: stops the loop and plays a sting through to its end
## (victory fanfare, defeat sting).
func play_sting(key: String) -> void:
	_start_music(key, false)

func stop_music() -> void:
	# Clearing the pending request too, or a track suppressed before the first
	# gesture would start up again after something else deliberately silenced it.
	_pending_music = ""
	_music_player.stop()

func _start_music(key: String, loop: bool) -> void:
	var stream := _load_stream(MUSIC.get(key, ""))
	if stream == null:
		return
	if loop and _music_player.stream == stream and _music_player.playing:
		return
	_set_loop(stream, loop)
	_music_player.volume_db = float(MUSIC_TRIM_DB.get(key, 0.0))
	_music_player.stream = stream
	_music_player.play()

## Web browsers refuse to start any audio until the player has interacted with
## the page, and a play_music() from a scene's _ready() is silently dropped
## there with no error. So the request is remembered and flushed on the first
## real gesture of any kind — a key or a tap on blank space counts, not just a
## press of one of our own buttons.
##
## This lives on the autoload rather than the title screen, where it used to,
## because the flag has to outlive the scene. Held per-scene, coming back to the
## menu after a battle reset it, and the title screen sat under the battle loop
## until the player clicked something. Desktop is unaffected either way.
func _input(event: InputEvent) -> void:
	if _user_gestured:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventKey:
		pressed = (event as InputEventKey).pressed
	if not pressed:
		return
	_user_gestured = true
	if not _pending_music.is_empty():
		_start_music(_pending_music, true)
		_pending_music = ""

## An SFX entry is either a single path or an array of interchangeable takes;
## an array picks one at random each call.
func play_sfx(key: String) -> void:
	var stream := _load_stream(_resolve_sfx_path(key))
	if stream == null:
		return
	var player := _claim_sfx_player()
	player.stream = stream
	player.play()

# --- character voices -----------------------------------------------------
#
# The shared "enemy_hurt" set above is three takes played by every rival in the
# game, so an ogre and a cashier yelped in the same voice. These are per
# character instead: assets/audio/sfx/voices/<voice>_<kind>_<n>.ogg.

const VOICE_DIR := "res://assets/audio/sfx/voices"
const VOICE_TAKES := 3
## A rival may not grunt again inside this window.
##
## Multi-hit skills land four or five blows inside half a second, and one grunt
## per blow is the machine-gun "UGH UGH UGH" that makes a fight sound cheap.
## The window is a little longer than the longest take, so a reaction is always
## allowed to finish rather than being retriggered over itself.
const VOICE_COOLDOWN := 0.55

## Voices get their OWN player rather than a slot in the SFX pool. Two reasons:
## a rival must never be heard grunting in two voices at once, which pooling
## allows; and a fresh grunt should cut the previous one rather than layer over
## it, which a dedicated player gives for free.
var _voice_player: AudioStreamPlayer
var _voice_until: float = 0.0
## Which take played last, so the same one is never heard twice running -- with
## only three takes, plain random repeats often enough to notice.
var _voice_last: int = -1


## Plays one of a character's takes. Returns false if nothing played, so a
## caller can fall back to the shared sound for a character with no voice yet.
##
## `kind` selects the register: "hurt" for everyone, plus "rage" for the boss,
## whose composure is supposed to break as the fight turns.
func play_voice(voice: String, kind: String = "hurt") -> bool:
	if voice.is_empty():
		return false
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < _voice_until:
		return true      # deliberately suppressed, not a failure -- do not fall back
	var take := randi() % VOICE_TAKES + 1
	if take == _voice_last:
		take = take % VOICE_TAKES + 1
	var stream := _load_stream("%s/%s_%s_%d.ogg" % [VOICE_DIR, voice, kind, take])
	if stream == null:
		return false
	_voice_last = take
	_voice_until = now + VOICE_COOLDOWN
	_voice_player.stream = stream
	_voice_player.play()
	return true


## Lets a fight start clean: without this a rival could be silenced by the
## cooldown left over from the previous encounter's last blow.
func reset_voice() -> void:
	_voice_until = 0.0
	_voice_last = -1
	if _voice_player != null:
		_voice_player.stop()

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
