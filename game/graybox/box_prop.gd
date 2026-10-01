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
	_apply()


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
