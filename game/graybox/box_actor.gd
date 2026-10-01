@tool
class_name BoxActor
extends Node3D
## A gray-box creature or player placeholder: a body box with a smaller nose box on its
## front, which is -Z (Godot forward, where [method Node3D.look_at] points). The origin
## sits at the feet, so a BoxActor placed at y = 0 stands on the ground.

## Picks the body size from [constant Graybox.SIZES].
@export var size_class: Graybox.SizeClass = Graybox.SizeClass.MEDIUM:
	set(value):
		size_class = value
		_apply()
## Material of the body and the nose. Use the kit materials from [Graybox].
@export var material: Material:
	set(value):
		material = value
		_apply()

## The body box.
@onready var body: MeshInstance3D = $Body
## The nose box on the front; later jobs tint and scale it for attack feedback.
@onready var nose: MeshInstance3D = $Nose


func _ready() -> void:
	_own_resources()
	_apply()


## The body dimensions in metres.
func get_body_size() -> Vector3:
	return Graybox.size_of(size_class)


## Swaps the body and nose meshes for copies that only this actor holds, because
## [method _fit] resizes them in place. [method Node.duplicate] and the editor's Duplicate
## hand a copy the original's meshes, so without this, resizing one actor would resize both.
func _own_resources() -> void:
	if Graybox.is_edited_scene_root(self):
		return
	body.mesh = body.mesh.duplicate() as Mesh
	nose.mesh = nose.mesh.duplicate() as Mesh


func _apply() -> void:
	if not is_node_ready():
		return
	var size := get_body_size()
	_fit(body, size, Vector3(0.0, size.y * 0.5, 0.0))
	var nose_side := size.x * Graybox.NOSE_FRACTION
	var nose_offset := Vector3(0.0, size.y * Graybox.NOSE_HEIGHT_FRACTION, -(size.z + nose_side) * 0.5)
	_fit(nose, Vector3(nose_side, nose_side, nose_side), nose_offset)


func _fit(part: MeshInstance3D, size: Vector3, offset: Vector3) -> void:
	var mesh := part.mesh as BoxMesh
	mesh.size = size
	mesh.material = material
	part.position = offset
