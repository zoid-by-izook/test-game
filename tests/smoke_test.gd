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

	# Goal: drop the player onto the goal platform; the win label must appear.
	print("SMOKE: stage victory")
	_player.global_position = Vector3(-6.0, 7.0, -20.0)
	_player.velocity = Vector3.ZERO
	await _physics_frames(90)
	var win_label: Label = _game.get_node("UI/WinLabel")
	_check(win_label.visible, "goal triggered victory label")
	await _shot("05-victory")

	# Fall respawn: below the kill plane the player must return to spawn.
	print("SMOKE: stage fall-respawn")
	_player.global_position = Vector3(0.0, -20.0, 6.0)
	_player.velocity = Vector3.ZERO
	await _physics_frames(30)
	var dist: float = _player.global_position.distance_to(SPAWN)
	_check(dist < 2.0, "fell below kill plane and respawned (d=%.2f)" % dist)

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
