extends Node3D
## Root of the graybox level. Builds the ground, floating platforms,
## coins, and goal from code; spawns the player; tracks the coin counter;
## shows the win label; respawns the player when they fall off the world.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const GOAL_SCENE: PackedScene = preload("res://scenes/goal.tscn")

const SPAWN := Vector3(0.0, 1.5, 6.0)
const KILL_Y := -12.0

var _coins_total := 0
var _coins_got := 0
var _player: PlatformerPlayer

@onready var _coin_label: Label = $UI/CoinLabel
@onready var _win_label: Label = $UI/WinLabel
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_build_level()
	_player = PLAYER_SCENE.instantiate()
	_player.position = SPAWN
	add_child(_player)
	_camera.target = _player
	_update_coin_label()


func _process(_delta: float) -> void:
	if _player and _player.global_position.y < KILL_Y:
		_player.velocity = Vector3.ZERO
		_player.global_position = SPAWN


func _build_level() -> void:
	var ground_mat := _make_material(Color(0.32, 0.33, 0.36))
	var plat_mat := _make_material(Color(0.55, 0.56, 0.60))

	_add_platform(Vector3(0, -0.5, 0), Vector3(60, 1, 60), ground_mat)
	_add_platform(Vector3(0, 1.0, -8), Vector3(5, 0.6, 5), plat_mat)
	_add_platform(Vector3(6, 2.5, -12), Vector3(4, 0.6, 4), plat_mat)
	_add_platform(Vector3(0, 4.0, -16), Vector3(4, 0.6, 4), plat_mat)
	_add_platform(Vector3(-6, 5.5, -20), Vector3(5, 0.6, 5), plat_mat)

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


func _add_platform(pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh_instance.mesh = box_mesh
	body.add_child(collision)
	body.add_child(mesh_instance)
	add_child(body)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _on_coin_collected(_coin: Coin) -> void:
	_coins_got += 1
	_update_coin_label()


func _on_goal_reached() -> void:
	_win_label.visible = true


func _update_coin_label() -> void:
	_coin_label.text = "Coins: %d/%d" % [_coins_got, _coins_total]
