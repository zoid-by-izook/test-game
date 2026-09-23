class_name WinMenu
extends Control
## Win overlay. Shown when the player reaches the goal flag; this node
## runs with PROCESS_MODE_ALWAYS (set in main.tscn) so its buttons keep
## working while the tree is paused. Emits signals — the game root owns
## the actual state transitions.

signal play_again_requested
signal main_menu_requested


func _ready() -> void:
	%PlayAgainButton.pressed.connect(func() -> void: play_again_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())


func set_stats(coins_got: int, coins_total: int) -> void:
	%StatsLabel.text = "Coins: %d/%d" % [coins_got, coins_total]


func show_menu() -> void:
	visible = true
	%PlayAgainButton.grab_focus()


func hide_menu() -> void:
	visible = false
