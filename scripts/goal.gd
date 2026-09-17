class_name Goal
extends Area3D
## Finish flag. Emits `reached` once when the player enters the area.

signal reached

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _done:
		return
	if body is PlatformerPlayer:
		_done = true
		reached.emit()
