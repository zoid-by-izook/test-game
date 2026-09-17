extends Node3D
## Root of the graybox level. Builds the island, ocean, floating platforms,
## coins, and goal from code; spawns the player; tracks the coin counter;
## shows the win label; respawns the player when they fall off the world.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const GOAL_SCENE: PackedScene = preload("res://scenes/goal.tscn")
## Quaternius grass blocks. Floating platforms use the closed "Single" cube
## (scaled to size) so they look right from every angle; the island below is
## many unscaled Single cubes arranged as a rounded, stepped blob via a
## MultiMesh, with one StaticBody3D holding a collision box per top cube.
const PLATFORM_MODEL: PackedScene = preload("res://assets/quaternius/Cube_Grass_Single.gltf")
const ISLAND_MODEL: PackedScene = preload("res://assets/quaternius/Cube_Grass_Single.gltf")
const OCEAN_SHADER: Shader = preload("res://assets/water/ocean.gdshader")
## Cube_Grass_Single measures ~2.23 x 2.0 x 2.23 units.
const PLATFORM_BASE_SIZE := Vector3(2.23, 2.0, 2.23)
## Island: two stepped layers of grass cubes centered near the spawn area.
## The top layer's edge is jittered per-column so the shoreline is not a
## perfect circle.
const ISLAND_CUBE := 2.23
const ISLAND_CENTER := Vector3(0.0, 0.0, -6.0)
const ISLAND_LAYERS := [
	{"top_y": 0.0, "radius": 20.0},
	{"top_y": -2.0, "radius": 17.5},
]
const OCEAN_Y := -2.8
const OCEAN_SIZE := 600.0

const SPAWN := Vector3(0.0, 1.5, 6.0)
## Just below the ocean surface: touching the water respawns the player.
const KILL_Y := -4.0

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
	_build_island()
	# TEMP-DIAG: water disabled to isolate SwiftShader boot hang.
	# _build_ocean()
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


func _add_platform(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	var model: Node3D = PLATFORM_MODEL.instantiate()
	model.scale = size / PLATFORM_BASE_SIZE
	body.add_child(collision)
	body.add_child(model)
	add_child(body)


## Builds the island: grass cubes in stepped circular layers merged into a
## single ArrayMesh (one draw call, no instancing — MultiMesh hangs
## SwiftShader's WebGL2 during boot) plus one StaticBody3D with a collision
## box per top-layer cube.
func _build_island() -> void:
	var cube_mesh := _extract_mesh(ISLAND_MODEL)
	var transforms: Array[Transform3D] = []
	var body := StaticBody3D.new()
	body.name = "IslandBody"
	for layer_index in ISLAND_LAYERS.size():
		var layer: Dictionary = ISLAND_LAYERS[layer_index]
		var top_y: float = layer["top_y"]
		var radius: float = layer["radius"]
		var center_y := top_y - 1.0
		var extent := int(ceil(radius / ISLAND_CUBE)) + 1
		for ix in range(-extent, extent + 1):
			for iz in range(-extent, extent + 1):
				var x := ISLAND_CENTER.x + float(ix) * ISLAND_CUBE
				var z := ISLAND_CENTER.z + float(iz) * ISLAND_CUBE
				var dist := Vector2(x - ISLAND_CENTER.x, z - ISLAND_CENTER.z).length()
				var edge := radius * (0.92 + 0.16 * _hash2(ix, iz))
				if dist > edge:
					continue
				var cube_pos := Vector3(x, center_y, z)
				transforms.append(Transform3D(Basis(), cube_pos))
				if layer_index == 0:
					var shape := CollisionShape3D.new()
					var box := BoxShape3D.new()
					box.size = Vector3(ISLAND_CUBE, 2.0, ISLAND_CUBE)
					shape.shape = box
					shape.position = cube_pos
					body.add_child(shape)
	# Merge the cube mesh into a single ArrayMesh (one draw call, no
	# instancing). MultiMesh instancing hangs SwiftShader's WebGL2 during
	# boot; a merged mesh renders identically and works everywhere.
	var merged := ArrayMesh.new()
	var surface_count := cube_mesh.get_surface_count()
	for s in surface_count:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(cube_mesh.surface_get_material(s))
		for t in transforms:
			tool.append_from(cube_mesh, s, t)
		tool.commit(merged)
	var visual := MeshInstance3D.new()
	visual.name = "IslandVisual"
	visual.mesh = merged
	visual.custom_aabb = AABB(Vector3(-25, -5, -33), Vector3(50, 8, 54))
	add_child(visual)
	add_child(body)


## Builds the ocean: one large subdivided plane with the animated stylized
## water shader. It has no collision — falling in means hitting KILL_Y.
func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var material := ShaderMaterial.new()
	material.shader = OCEAN_SHADER
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	water.mesh = plane
	water.material_override = material
	water.position = Vector3(ISLAND_CENTER.x, OCEAN_Y, ISLAND_CENTER.z)
	add_child(water)


## Pulls the ArrayMesh out of a single-mesh glTF PackedScene without
## keeping the probe instance around.
func _extract_mesh(packed: PackedScene) -> Mesh:
	var probe := packed.instantiate()
	var mesh_instance := _find_mesh_instance(probe)
	var mesh := mesh_instance.mesh
	probe.queue_free()
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


## Deterministic 0..1 hash for shoreline jitter (stable across runs).
func _hash2(x: int, z: int) -> float:
	var h := x * 374761393 + z * 668265263 + 974711
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


func _on_coin_collected(_coin: Coin) -> void:
	_coins_got += 1
	_update_coin_label()


func _on_goal_reached() -> void:
	_win_label.visible = true


func _update_coin_label() -> void:
	_coin_label.text = "Coins: %d/%d" % [_coins_got, _coins_total]
