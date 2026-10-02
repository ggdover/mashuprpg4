@tool
class_name QuestTrigger
extends Area3D
## A box-shaped volume that tells the quest system the player has come to a place. When
## the player's body enters it, it emits marker_reached on the EventBus with
## [member marker_id], every time. REACH objectives and auto-start markers name that id.
##
## It has no visual of its own. The origin sits at the bottom centre, so a trigger placed
## at y = 0 stands on the ground.

## The id announced on marker_reached. A trigger without one announces nothing.
@export var marker_id: StringName = &""
## Width, height and depth of the volume in metres.
@export var size: Vector3 = Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value
		_apply()

@onready var _collision: CollisionShape3D = $Shape


func _ready() -> void:
	_own_shape()
	_apply()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


## Swaps the shape for a copy that only this trigger holds, because [method _apply] resizes
## it in place. [method Node.duplicate] and the editor's Duplicate hand a copy the
## original's shape, so without this, resizing one trigger would resize both.
func _own_shape() -> void:
	if Graybox.is_edited_scene_root(self):
		return
	_collision.shape = _collision.shape.duplicate() as Shape3D


func _apply() -> void:
	if not is_node_ready():
		return
	var shape := _collision.shape as BoxShape3D
	shape.size = size
	_collision.position = Vector3(0.0, size.y * 0.5, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and marker_id != &"":
		EventBus.marker_reached.emit(marker_id)
