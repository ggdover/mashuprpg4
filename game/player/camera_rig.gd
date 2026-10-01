class_name CameraRig
extends Node3D
## The fixed-angle top-down camera. The rig stands in the scene next to the player, never
## under it, and glides after its target every rendered frame. The camera hangs above and
## behind the rig's origin at a fixed pitch and looks at it; the yaw stays at 0.
##
## The project interpolates physics, so the player is drawn between its physics ticks. The
## rig moves per rendered frame instead: camera_rig.tscn sets its physics interpolation mode
## to Off, and it follows the target's interpolated position, the one that is drawn. That
## keeps the picture free of jitter at any frame rate.

## The node to follow: the player.
@export var target: Node3D
## How fast the rig closes the gap to its target, and the camera the gap to its zoom
## distance, per second. The gap shrinks by the same share in the same time at any frame rate.
@export var follow_rate := 8.0
## Downward tilt of the camera in degrees: 0 looks at the horizon, 90 straight down.
@export_range(0.0, 90.0, 0.1) var pitch_degrees := 55.0
## Distance from the rig's origin to the camera in metres. The mouse wheel changes it.
@export var distance := 18.0
## Closest zoom in metres.
@export var min_distance := 12.0
## Farthest zoom in metres.
@export var max_distance := 24.0
## Metres per notch of the mouse wheel.
@export var zoom_step := 1.0

## Where the camera is right now on its way to [member distance].
var _current_distance := 0.0

## The camera. Its place under the rig is set from the pitch and the distance every frame.
@onready var camera: Camera3D = $Camera


func _ready() -> void:
	distance = clampf(distance, min_distance, max_distance)
	_current_distance = distance
	_place_camera()
	snap_to_target()


func _process(delta: float) -> void:
	# 1 - exp(-rate * delta) is the share of the gap to close this frame. Unlike a plain
	# rate * delta it adds up to the same motion however the time is cut into frames.
	var weight := 1.0 - exp(-follow_rate * delta)
	if is_instance_valid(target):
		global_position = global_position.lerp(target.get_global_transform_interpolated().origin, weight)
	_current_distance = lerpf(_current_distance, distance, weight)
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom(-zoom_step)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom(zoom_step)


## The rig's rotation around the vertical axis in radians. The player's move keys are
## relative to it, so that W is always up on screen. Stays 0 while nothing turns the rig.
func get_yaw() -> float:
	return global_rotation.y


## Moves the camera [param metres] away from the target, or toward it when negative, within
## [member min_distance] and [member max_distance]. The camera eases to the new distance.
func zoom(metres: float) -> void:
	distance = clampf(distance + metres, min_distance, max_distance)


## Jumps to the target and to the zoom distance without gliding: for the start of a scene
## and for teleports.
func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position
	_current_distance = distance
	_place_camera()


func _place_camera() -> void:
	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	camera.transform = Transform3D(tilt, tilt.z * _current_distance)
