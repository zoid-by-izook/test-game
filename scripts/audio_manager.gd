extends Node
## Global audio manager (autoload). Owns the Music and SFX audio buses,
## background music playback (title theme <-> game theme), one-shot SFX,
## and volume settings (persisted to user://).
##
## Buses: Master (built-in) -> Music, SFX (created here at runtime).
## Music crossfades between two players so theme switches don't click.

const TITLE_THEME: AudioStream = preload("res://assets/audio/music/title_theme.ogg")
const GAME_THEME: AudioStream = preload("res://assets/audio/music/game_theme.ogg")

const SFX := {
	"jump": preload("res://assets/audio/sfx/jump.ogg"),
	"land": preload("res://assets/audio/sfx/land.ogg"),
	"coin": preload("res://assets/audio/sfx/coin.ogg"),
	"win": preload("res://assets/audio/sfx/win.ogg"),
}

const SETTINGS_PATH := "user://audio_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## Seconds for the music crossfade when switching themes.
const CROSSFADE_TIME := 1.5

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

var music_volume := 0.8
var sfx_volume := 0.8
var master_volume := 1.0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_active_music = _music_a
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)
	_load_settings()
	_apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = MUSIC_BUS
	add_child(p)
	return p


## Starts the title theme (looped). Called from the main menu.
func play_title_theme() -> void:
	_switch_music(TITLE_THEME)


## Starts the gameplay theme (looped). Called when the run begins.
func play_game_theme() -> void:
	_switch_music(GAME_THEME)


func _switch_music(stream: AudioStream) -> void:
	if _active_music.stream == stream and _active_music.playing:
		return
	var next_player := _music_b if _active_music == _music_a else _music_a
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_active_music, "volume_db", -80.0, CROSSFADE_TIME)
	tween.tween_property(next_player, "volume_db", 0.0, CROSSFADE_TIME)
	tween.chain().tween_callback(_active_music.stop)
	_active_music = next_player


## Plays a one-shot SFX by name ("jump", "land", "coin", "win").
func play_sfx(sfx_name: String) -> void:
	if not SFX.has(sfx_name):
		push_warning("AudioManager: unknown sfx '%s'" % sfx_name)
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = SFX[sfx_name]
			p.play()
			return
	# Pool exhausted: steal the first player.
	_sfx_players[0].stream = SFX[sfx_name]
	_sfx_players[0].play()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "master", master_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
