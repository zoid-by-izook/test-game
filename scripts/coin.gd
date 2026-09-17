class_name Coin
extends Area3D
## Spinning collectible. Emits `collected` when the player touches it,
## then frees itself.

signal collected(coin: Coin)

@export var spin_speed: float = 2.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is PlatformerPlayer:
		collected.emit(self)
		queue_free()
