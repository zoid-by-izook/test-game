class_name StartMenu
extends Control
## Title screen overlay. Shown on boot; hidden once the player starts the
## game. Emits `start_requested` when the Start button is pressed — the
## game root also dismisses the menu on any key/mouse/touch via
## `_unhandled_input`, so this signal only covers the button itself.
##
## The menu has two views: the main title view and a credits view listing
## third-party assets (artist / asset / license). Each entry in CREDITS is a
## Dictionary with "title", "artist", and "license" keys — asset PRs append
## their entries here so the in-game credits stay current.

signal start_requested

const CREDITS: Array = [
	{
		"title": "Ultimate Platformer Pack (character, coins, platforms, flag)",
		"artist": "Quaternius",
		"license": "CC0 1.0 Universal",
	},
	{
		"title": "Game code & level design",
		"artist": "Zoid",
		"license": "All original",
	},
]


func _ready() -> void:
	%StartButton.pressed.connect(_on_start_button_pressed)
	%CreditsButton.pressed.connect(show_credits)
	%BackButton.pressed.connect(show_main)
	_build_credits_list()
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
	%MainView.visible = true
	%StartButton.grab_focus()


func is_credits_open() -> bool:
	return visible and %CreditsView.visible


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
