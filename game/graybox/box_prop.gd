@tool
class_name BoxProp
extends StaticBody3D
## A gray-box wall, pillar or crate: a BoxMesh with a matching collision box on the world
## layer. The origin sits at the bottom centre, so a prop placed at y = 0 stands on the ground.

## Width, height and depth in metres.
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
		_apply()
## Material of the box. Use the kit materials from [Graybox].
@export var material: Material:
	set(value):
		material = value
		_apply()

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $Collision


func _ready() -> void:
	_own_resources()
	_apply()


## Swaps the mesh and the shape for copies that only this prop holds, because [method _apply]
## resizes them in place. [method Node.duplicate] and the editor's Duplicate hand a copy the
## original's mesh and shape, so without this, resizing one prop would resize both.
func _own_resources() -> void:
	if Graybox.is_edited_scene_root(self):
		return
	mesh_instance.mesh = mesh_instance.mesh.duplicate() as Mesh
	collision_shape.shape = collision_shape.shape.duplicate() as Shape3D


func _apply() -> void:
	if not is_node_ready():
		return
	var mesh := mesh_instance.mesh as BoxMesh
	mesh.size = size
	mesh.material = material
	var shape := collision_shape.shape as BoxShape3D
	shape.size = size
	var centre := Vector3(0.0, size.y * 0.5, 0.0)
	mesh_instance.position = centre
	collision_shape.position = centre
