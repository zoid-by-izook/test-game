extends Node3D
## Root of the graybox level. Builds the island, animated ocean, floating platforms,
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
## Tileable fBm noise driving the ocean's organic variation (swell, whitecaps).
const OCEAN_NOISE: Texture2D = preload("res://assets/water/noise_fbm.png")
## Cube_Grass_Single measures ~2.23 x 2.0 x 2.23 units.
const PLATFORM_BASE_SIZE := Vector3(2.23, 2.0, 2.23)
## Island: two stepped layers of grass cubes centered near the spawn area.
## The top layer's edge is jittered per-column so the shoreline is not a
## perfect circle.
const ISLAND_CUBE := 2.23
const ISLAND_CENTER := Vector3(0.0, 0.0, -6.0)
## Max shoreline shape multiplier (1.0 + sum of _island_shape amplitudes),
## used to size the build grid so lobes aren't cut off.
const ISLAND_SHAPE_MAX := 1.5
const ISLAND_LAYERS := [
	{"top_y": 0.0, "radius": 20.0},
	{"top_y": -2.0, "radius": 17.5},
]
## Shoreline SDF: world-space bake of the island footprint. Covers
## SDF_SIZE x SDF_SIZE meters centered on SDF_CENTER; each texel stores
## signed meters to the shore edge. World-space so extra islands just add
## land cells — no shader changes.
const SDF_RES := 256
const SDF_SIZE := 150.0
const SDF_CENTER := Vector2(0.0, -6.0)
const SDF_MAX_DIST := 12.0
const OCEAN_Y := -1.0
const OCEAN_SIZE := 600.0

const SPAWN := Vector3(0.0, 1.5, 6.0)
## Just below the ocean surface: touching the water respawns the player.
const KILL_Y := -2.0

var _coins_total := 0
var _coins_got := 0
## World-xz of top-layer island cubes, collected during _build_island().
var _top_layer_cubes: Array[Vector2] = []
## Baked shoreline distance texture, created by _bake_shore_sdf().
var _shore_sdf: ImageTexture
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
	AudioManager.play_title_theme()


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
	AudioManager.play_game_theme()


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
	_bake_shore_sdf()
	_build_ocean()
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


## Island shoreline shape: angular modulation for an irregular (non-circular)
## coastline with lobes and inlets. Returns a multiplier on the layer radius.
## Deterministic — same angle always gives the same shape.
func _island_shape(angle: float) -> float:
	return 1.0 + 0.35 * sin(2.0 * angle + 0.8) + 0.15 * sin(3.0 * angle + 1.7)


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
		var extent := int(ceil(radius * ISLAND_SHAPE_MAX * 1.08 / ISLAND_CUBE)) + 1
		for ix in range(-extent, extent + 1):
			for iz in range(-extent, extent + 1):
				var x := ISLAND_CENTER.x + float(ix) * ISLAND_CUBE
				var z := ISLAND_CENTER.z + float(iz) * ISLAND_CUBE
				var dist := Vector2(x - ISLAND_CENTER.x, z - ISLAND_CENTER.z).length()
				var angle := atan2(z - ISLAND_CENTER.z, x - ISLAND_CENTER.x)
				var edge := radius * _island_shape(angle) * (0.92 + 0.16 * _hash2(ix, iz))
				if dist > edge:
					continue
				var cube_pos := Vector3(x, center_y, z)
				transforms.append(Transform3D(Basis(), cube_pos))
				if layer_index == 0:
					_top_layer_cubes.append(Vector2(x, z))
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


## Bakes a world-space signed distance field of the island shoreline from
## the recorded top-layer cube footprints. Each texel stores signed meters
## to the nearest shore edge (positive in water, negative inside the
## island), encoded 0..1. The ocean shader samples this so foam hugs the
## actual cube edges instead of an analytic circle.
func _bake_shore_sdf() -> void:
	var res := SDF_RES
	var grid := PackedByteArray()
	grid.resize(res * res) # 0 = water, 1 = land
	var sdf_min := SDF_CENTER - Vector2(SDF_SIZE, SDF_SIZE) * 0.5
	var half_cube := ISLAND_CUBE * 0.5
	for c in _top_layer_cubes:
		var x0 := int((c.x - half_cube - sdf_min.x) / SDF_SIZE * res)
		var x1 := int((c.x + half_cube - sdf_min.x) / SDF_SIZE * res)
		var z0 := int((c.y - half_cube - sdf_min.y) / SDF_SIZE * res)
		var z1 := int((c.y + half_cube - sdf_min.y) / SDF_SIZE * res)
		for gz in range(maxi(z0, 0), mini(z1, res - 1) + 1):
			for gx in range(maxi(x0, 0), mini(x1, res - 1) + 1):
				grid[gz * res + gx] = 1
	var dist_to_land := _chamfer(grid, res, false)
	var dist_to_water := _chamfer(grid, res, true)
	var cell := SDF_SIZE / res
	# RG8: R = signed shore distance (0..1 encoded), G = confinement mask
	# (1 = narrow channel/inlet where water can't get far from land).
	var img := Image.create(res, res, false, Image.FORMAT_RG8)
	var win := 2 # ±2 texels for confinement window
	for z in res:
		for x in res:
			var i := z * res + x
			var d: float
			var conf := 0.0
			if grid[i] == 1:
				d = -dist_to_water[i] * cell
			else:
				d = dist_to_land[i] * cell
				# Confinement: max distance-to-land in a 5x5 window. In a
				# narrow channel you can't escape land, so the max stays
				# small; in open water you can move away and it grows.
				var max_d := 0.0
				for dz in range(-win, win + 1):
					var nz := clampi(z + dz, 0, res - 1)
					for dx in range(-win, win + 1):
						var nx := clampi(x + dx, 0, res - 1)
						var ni := nz * res + nx
						if grid[ni] == 0:
							max_d = maxf(max_d, dist_to_land[ni] * cell)
				conf = 1.0 - smoothstep(1.2, 2.5, max_d)
			var v := clampf(d / SDF_MAX_DIST * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, z, Color(v, conf, 0.0))
	_shore_sdf = ImageTexture.create_from_image(img)


## Two-pass chamfer distance transform. Returns per-cell distance (in cells)
## to the nearest cell where grid == 1 (or != 1 when invert is true).
func _chamfer(grid: PackedByteArray, res: int, invert: bool) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(res * res)
	for i in res * res:
		var target := grid[i] == 1
		dist[i] = 0.0 if (target != invert) else 1e9
	for z in res:
		for x in res:
			var i := z * res + x
			if dist[i] == 0.0:
				continue
			var b := dist[i]
			if x > 0:
				b = minf(b, dist[i - 1] + 1.0)
			if z > 0:
				b = minf(b, dist[i - res] + 1.0)
				if x > 0:
					b = minf(b, dist[i - res - 1] + 1.41421356)
				if x < res - 1:
					b = minf(b, dist[i - res + 1] + 1.41421356)
			dist[i] = b
	for z in range(res - 1, -1, -1):
		for x in range(res - 1, -1, -1):
			var i := z * res + x
			if dist[i] == 0.0:
				continue
			var b := dist[i]
			if x < res - 1:
				b = minf(b, dist[i + 1] + 1.0)
			if z < res - 1:
				b = minf(b, dist[i + res] + 1.0)
				if x < res - 1:
					b = minf(b, dist[i + res + 1] + 1.41421356)
				if x > 0:
					b = minf(b, dist[i + res - 1] + 1.41421356)
			dist[i] = b
	return dist


## Builds the ocean: one large subdivided plane with the animated stylized
## water shader (six waves + fBm noise, hard-cut whitecaps, plus shore
## foam from the baked SDF). It has no collision; falling in means hitting
## KILL_Y.
func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var material := ShaderMaterial.new()
	material.shader = OCEAN_SHADER
	material.set_shader_parameter("noise_tex", OCEAN_NOISE)
	material.set_shader_parameter("shore_sdf", _shore_sdf)
	material.set_shader_parameter("sdf_min", SDF_CENTER - Vector2(SDF_SIZE, SDF_SIZE) * 0.5)
	material.set_shader_parameter("sdf_size", SDF_SIZE)
	material.set_shader_parameter("sdf_max_dist", SDF_MAX_DIST)
	material.set_shader_parameter("ocean_offset", Vector2(ISLAND_CENTER.x, ISLAND_CENTER.z))
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	water.mesh = plane
	water.material_override = material
	water.position = Vector3(ISLAND_CENTER.x, OCEAN_Y, ISLAND_CENTER.z)
	add_child(water)


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
