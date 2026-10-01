class_name Aim
extends Node
## Where the mouse points on the ground. A child of the [Player]: every physics frame it
## casts a ray from the active camera through the mouse onto the horizontal plane at the
## player's feet. In the player scene its physics priority puts it ahead of the player, so
## the player turns toward a direction that was measured in the same tick.

## The mouse closer to the player than this, in metres along the ground, keeps the previous
## [member aim_dir]: right on top of the player the direction would flip at every twitch.
@export var min_aim_distance := 0.1

## The point under the mouse on the ground plane. Read-only.
var aim_point: Vector3:
	get:
		return _aim_point
## Unit vector on the XZ plane from the player toward [member aim_point]. Keeps its last
## valid value while the mouse has no ground point or sits on the player. Read-only.
var aim_dir: Vector3:
	get:
		return _aim_dir

var _aim_point := Vector3.ZERO
var _aim_dir := Vector3.FORWARD

## The node the aim is measured from: the player.
@onready var _origin: Node3D = get_parent() as Node3D


func _ready() -> void:
	# Until the first mouse ray lands, aim where the player already faces.
	var facing := -_origin.global_basis.z
	facing.y = 0.0
	if not facing.is_zero_approx():
		_aim_dir = facing.normalized()
	_aim_point = _origin.global_position + _aim_dir


func _physics_process(_delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var mouse := viewport.get_mouse_position()
	update_from_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))


## Aims along a ray: [member aim_point] becomes the point where the ray meets the horizontal
## plane at the player's height, and [member aim_dir] the direction from the player to it.
## A ray that never meets the plane changes nothing.
func update_from_ray(ray_origin: Vector3, ray_normal: Vector3) -> void:
	var origin := _origin.global_position
	var hit: Variant = Plane(Vector3.UP, origin.y).intersects_ray(ray_origin, ray_normal)
	if hit == null:
		return
	_aim_point = hit
	var offset := Vector3(_aim_point.x - origin.x, 0.0, _aim_point.z - origin.z)
	if offset.length() >= min_aim_distance and not offset.is_zero_approx():
		_aim_dir = offset.normalized()
