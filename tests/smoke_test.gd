extends Node
## Scripted smoke playtest for the graybox platformer.
##
## Runs the real game under a virtual display, drives it with synthetic input,
## captures screenshots at each stage, and asserts the core loop works:
## spawn, move, jump, coin collect, victory, fall respawn.
##
## Run:  xvfb-run -a godot --path . res://tests/smoke_test.tscn
## Exit code 0 = pass, 1 = fail. Screenshots land in test-results/screenshots/.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SPAWN := Vector3(0.0, 1.5, 6.0)

var _failures: Array[String] = []
var _game: Node3D
var _player: PlatformerPlayer
var _shot_dir: String
## Set before retry_game() triggers a scene reload: the reloaded test
## instance skips the full suite and only verifies the autostart worked.
static var _is_retry_run := false


func _ready() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://test-results/screenshots")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	_run()


func _run() -> void:
	print("SMOKE: starting scripted playtest")
	# Let the game finish _ready() and the player settle onto the ground.
	await get_tree().process_frame
	await get_tree().process_frame
	for child in _game.get_children():
		if child is PlatformerPlayer:
			_player = child
	_check(_player != null, "player spawned")

	if _is_retry_run:
		print("SMOKE: verifying retry autostart")
		_check(_game.is_started(), "retry auto-started the game")
		var retry_menu: Control = _game.get_node("UI/StartMenu")
		_check(not retry_menu.visible, "start menu skipped on retry")
		_check(_player.controls_enabled, "player controls enabled on retry")
		_finish()
		return

	# Start menu: visible on boot, game starts on dismissal.
	print("SMOKE: stage start-menu")
	var menu: Control = _game.get_node("UI/StartMenu")
	_check(menu.visible, "start menu shown on boot")
	_check(not _game.is_started(), "game not started before dismissal")
	await _shot("00-start-menu")

	# Credits: open from the menu, any-key dismissal suppressed, back returns.
	var credits_button: Button = _game.get_node("UI/StartMenu/Center/MainView/CreditsButton")
	credits_button.pressed.emit()
	_check(menu.is_credits_open(), "credits view open")
	await _shot("00-credits")
	var key_ev := InputEventKey.new()
	key_ev.pressed = true
	key_ev.keycode = KEY_A
	_game._unhandled_input(key_ev)
	_check(not _game.is_started(), "game not started while credits open")
	var back_button: Button = _game.get_node("UI/StartMenu/Center/CreditsView/BackButton")
	back_button.pressed.emit()
	_check(not menu.is_credits_open(), "credits view closed")

	_game.start_game()
	_check(not menu.visible, "start menu hidden after dismissal")
	_check(_game.is_started(), "game started after dismissal")
	_check(_player.controls_enabled, "player controls enabled after dismissal")

	# Pause: tree freezes, overlay shows; resume restores play.
	print("SMOKE: stage pause")
	var pause_menu: Control = _game.get_node("UI/PauseMenu")
	_check(not pause_menu.visible, "pause menu hidden while playing")
	_game.pause_game()
	_check(_game.is_paused(), "tree paused")
	_check(pause_menu.visible, "pause menu shown while paused")
	await _shot("06-paused")
	_game.resume_game()
	_check(not _game.is_paused(), "tree resumed")
	_check(not pause_menu.visible, "pause menu hidden after resume")

	await _physics_frames(90)
	_check(_player.is_on_floor(), "player resting on floor")
	await _shot("01-spawned")

	# Move right: position.x must clearly increase.
	print("SMOKE: stage move-right")
	var start_x: float = _player.global_position.x
	Input.action_press("move_right")
	await _physics_frames(120)
	Input.action_release("move_right")
	var moved: float = _player.global_position.x - start_x
	_check(moved > 2.0, "player moved right (dx=%.2f)" % moved)
	await _shot("02-moved-right")

	# Jump: track the apex over the next second.
	print("SMOKE: stage jump")
	var ground_y: float = _player.global_position.y
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	var apex: float = ground_y
	for i in 60:
		await get_tree().physics_frame
		apex = maxf(apex, _player.global_position.y)
	_check(apex - ground_y > 1.0, "player jumped (dy=%.2f)" % (apex - ground_y))
	await _shot("03-jump-apex")
	await _physics_frames(60) # land before teleporting

	# Coin: drop the player beside a real coin and walk into it.
	print("SMOKE: stage coin-collect")
	var coin := _first_coin()
	if coin == null:
		_check(false, "found a coin to collect")
	else:
		_player.global_position = coin.global_position + Vector3(0.0, 0.5, 2.0)
		_player.velocity = Vector3.ZERO
		await _physics_frames(5)
		Input.action_press("move_forward")
		await _physics_frames(90)
		Input.action_release("move_forward")
		var label: Label = _game.get_node("UI/CoinLabel")
		_check(label.text == "Coins: 1/6", "coin collected (label='%s')" % label.text)
		await _shot("04-coin-collected")

	# Goal: drop the player onto the goal platform; the win screen must appear.
	# The win screen pauses the tree, so unpause after the screenshot or the
	# fall game-over stage would never advance a physics frame.
	print("SMOKE: stage victory")
	_player.global_position = Vector3(-6.0, 7.0, -20.0)
	_player.velocity = Vector3.ZERO
	await _physics_frames(90)
	var win_menu: Control = _game.get_node("UI/WinMenu")
	_check(win_menu.visible, "goal triggered win screen")
	_check(get_tree().paused, "tree paused on win screen")
	await _shot("05-victory")
	win_menu.visible = false
	get_tree().paused = false

	# Fall game-over: touching the ocean plays the death animation (splash,
	# bob, sink), then the game-over screen shows.
	# Final stage: retry_game() reloads the scene (deferred to end of frame).
	# The reloaded test instance sees _is_retry_run and only verifies the
	# autostart, so this instance just arms the flag and lets the reload fire.
	print("SMOKE: stage fall-game-over")
	_player.global_position = Vector3(40.0, 2.0, 6.0)
	_player.velocity = Vector3.ZERO
	var waited := 0
	while not _game._dying and waited < 120:
		await _physics_frames(1)
		waited += 1
	_check(_game._dying, "death animation started after touching ocean")
	_check(not _player.controls_enabled, "player controls disabled during death animation")
	await _shot("07a-death-splash")
	await _physics_frames(150)
	_check(_game._game_over_menu.visible, "fell in ocean and game-over menu shown after death animation")
	_check(get_tree().paused, "tree paused on game-over")
	await _shot("07-game-over")
	_is_retry_run = true
	_game.retry_game()


## Prints the result and quits with the appropriate exit code.
func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE PASS")
	else:
		for f in _failures:
			print("SMOKE FAIL: ", f)
		await _shot("99-failure")
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _first_coin() -> Coin:
	for child in _game.get_children():
		if child is Coin:
			return child
	return null


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_shot_dir.path_join(name + ".png"))
	if err != OK:
		_failures.append("screenshot '%s' failed to save" % name)


func _check(ok: bool, what: String) -> void:
	print(("SMOKE PASS: " if ok else "SMOKE FAIL: ") + what)
	if not ok:
		_failures.append(what)
