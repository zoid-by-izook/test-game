class_name StartMenu
extends Control
## Title screen overlay. Shown on boot; hidden once the player starts the
## game. Emits `start_requested` when the Start button is pressed — the
## game root also dismisses the menu on any key/mouse/touch via
## `_unhandled_input`, so this signal only covers the button itself.
##
## Each CREDITS entry is a Dictionary with "title", "artist", and "license" keys.

signal start_requested

var _audio_menu: AudioMenu

const CREDITS: Array = [
	{
		"title": "Ultimate Platformer Pack (character, coins, platforms, flag)",
		"artist": "Quaternius",
		"license": "CC0 1.0 Universal",
	},
	{
		"title": "Stylized Sky shader (adapted for this game's daytime sky)",
		"artist": "GDQuest",
		"license": "MIT",
	},
	{
		"title": "\"Casa Bossa Nova\" (title theme)",
		"artist": "Kevin MacLeod (incompetech.com)",
		"license": "CC BY 4.0",
	},
	{
		"title": "\"Bassa Island Game Loop\" (gameplay theme)",
		"artist": "Kevin MacLeod (incompetech.com)",
		"license": "CC BY 4.0",
	},
	{
		"title": "SFX: jump, land, coin, win jingle",
		"artist": "Kenney (kenney.nl)",
		"license": "CC0 1.0 Universal",
	},
	{
		"title": "\"Retro video game sfx - Splash\" (ocean death splash)",
		"artist": "OwlStorm (Ashe Kirk, freesound.org)",
		"license": "CC0 1.0 Universal",
	},
	{
		"title": "Fredoka (UI font)",
		"artist": "Milena Brandão, Hafontia",
		"license": "SIL Open Font License 1.1",
	},
]


func _ready() -> void:
	%StartButton.pressed.connect(_on_start_button_pressed)
	%AudioButton.pressed.connect(show_audio)
	%MuteButton.pressed.connect(_on_mute_pressed)
	%CreditsButton.pressed.connect(show_credits)
	%BackButton.pressed.connect(show_main)
	_build_credits_list()
	_audio_menu = AudioMenu.new()
	_audio_menu.back_requested.connect(show_main)
	_audio_menu.visible = false
	%Center.add_child(_audio_menu)
	show_main()


func show_menu() -> void:
	visible = true
	show_main()


func hide_menu() -> void:
	visible = false


func show_credits() -> void:
	%MainView.visible = false
	%CreditsView.visible = true
	%BackButton.grab_focus()


func show_main() -> void:
	%CreditsView.visible = false
	_audio_menu.visible = false
	%MainView.visible = true
	_sync_mute_button()
	%StartButton.grab_focus()


func show_audio() -> void:
	%MainView.visible = false
	%CreditsView.visible = false
	_audio_menu.visible = true
	_audio_menu.refresh()


func is_credits_open() -> bool:
	return visible and %CreditsView.visible


func _on_mute_pressed() -> void:
	AudioManager.set_muted(not AudioManager.is_muted())
	_sync_mute_button()


func _sync_mute_button() -> void:
	%MuteButton.text = "Sound: Off" if AudioManager.is_muted() else "Sound: On"


func _unhandled_input(event: InputEvent) -> void:
	if is_credits_open() and event.is_action_pressed("ui_cancel"):
		show_main()


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _build_credits_list() -> void:
	for entry in CREDITS:
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 20)
		line.text = "%s\n%s — %s" % [entry["title"], entry["artist"], entry["license"]]
		%CreditsList.add_child(line)
