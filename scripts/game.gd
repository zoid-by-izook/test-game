extends Node3D
## Root of the graybox level. Builds the ground, floating platforms,
## coins, and goal from code; spawns the player; tracks the coin counter;
## shows the win label; respawns the player when they fall off the world.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const GOAL_SCENE: PackedScene = preload("res://scenes/goal.tscn")
## Quaternius grass blocks, scaled to each platform's size. Collision stays
## an exact box. The ground uses the flat "Center" tile (top face only —
## the camera never sees its sides); floating platforms use the closed
## "Single" cube so they look right from every angle.
const GROUND_MODEL: PackedScene = preload("res://assets/quaternius/Cube_Grass_Center.gltf")
const PLATFORM_MODEL: PackedScene = preload("res://assets/quaternius/Cube_Grass_Single.gltf")
## Cube_Grass_Single measures ~2.23 x 2.0 x 2.23 units.
const PLATFORM_BASE_SIZE := Vector3(2.23, 2.0, 2.23)

const SPAWN := Vector3(0.0, 1.5, 6.0)
const KILL_Y := -12.0

var _coins_total := 0
var _coins_got := 0
var _player: PlatformerPlayer
var _started := false

@onready var _coin_label: Label = $UI/CoinLabel
@onready var _win_label: Label = $UI/WinLabel
@onready var _camera: Camera3D = $Camera3D
@onready var _menu: StartMenu = $UI/StartMenu
@onready var _pause_menu: PauseMenu = $UI/PauseMenu


func _ready() -> void:
	_build_level()
	_player = PLAYER_SCENE.instantiate()
	_player.position = SPAWN
	_player.controls_enabled = false
	add_child(_player)
	_camera.target = _player
	_menu.start_requested.connect(start_game)
	_pause_menu.resume_requested.connect(resume_game)
	_pause_menu.restart_requested.connect(restart_game)
	_menu.show_menu()
	_update_coin_label()


func is_started() -> bool:
	return _started


func is_paused() -> bool:
	return get_tree().paused


func start_game() -> void:
	if _started:
		return
	_started = true
	_menu.hide_menu()
	_player.controls_enabled = true


func pause_game() -> void:
	if not _started or get_tree().paused:
		return
	get_tree().paused = true
	_pause_menu.show_menu()


func resume_game() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	_pause_menu.hide_menu()


func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		if _menu.is_credits_open():
			return
		if event is InputEventKey and event.pressed and not event.echo:
			start_game()
		elif event is InputEventMouseButton and event.pressed:
			start_game()
		elif event is InputEventScreenTouch and event.pressed:
			start_game()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		pause_game()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		pause_game()


func _process(_delta: float) -> void:
	if _player and _player.global_position.y < KILL_Y:
		_player.velocity = Vector3.ZERO
		_player.global_position = SPAWN


func _build_level() -> void:
	_add_platform(Vector3(0, -0.5, 0), Vector3(60, 1, 60), true)
	_add_platform(Vector3(0, 1.0, -8), Vector3(5, 0.6, 5))
	_add_platform(Vector3(6, 2.5, -12), Vector3(4, 0.6, 4))
	_add_platform(Vector3(0, 4.0, -16), Vector3(4, 0.6, 4))
	_add_platform(Vector3(-6, 5.5, -20), Vector3(5, 0.6, 5))

	var coin_spots: Array[Vector3] = [
		Vector3(3, 1.2, -4),
		Vector3(-3, 1.2, 2),
		Vector3(0, 2.4, -8),
		Vector3(6, 3.9, -12),
		Vector3(0, 5.4, -16),
		Vector3(-6, 6.9, -20),
	]
	for spot in coin_spots:
		var coin: Coin = COIN_SCENE.instantiate()
		coin.position = spot
		coin.collected.connect(_on_coin_collected)
		add_child(coin)
		_coins_total += 1

	var goal: Goal = GOAL_SCENE.instantiate()
	goal.position = Vector3(-6, 5.8, -20)
	goal.reached.connect(_on_goal_reached)
	add_child(goal)


func _add_platform(pos: Vector3, size: Vector3, is_ground := false) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	var model: Node3D
	if is_ground:
		model = GROUND_MODEL.instantiate()
		model.scale = size / 2.0
	else:
		model = PLATFORM_MODEL.instantiate()
		model.scale = size / PLATFORM_BASE_SIZE
	body.add_child(collision)
	body.add_child(model)
	add_child(body)


func _on_coin_collected(_coin: Coin) -> void:
	_coins_got += 1
	_update_coin_label()


func _on_goal_reached() -> void:
	_win_label.visible = true


func _update_coin_label() -> void:
	_coin_label.text = "Coins: %d/%d" % [_coins_got, _coins_total]
