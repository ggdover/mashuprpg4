class_name Player
extends CharacterBody3D
## The player's body. The move keys walk it relative to the camera, it turns toward the mouse
## whichever way it walks, and the dodge key dashes. game/README.md, "Player, aim and
## camera", describes the movement model.
##
## Hooks for later jobs: [member movement_multiplier] (J04 slows the player while a skill
## runs), [member can_act] and [member is_invulnerable] (the dash), [signal dodge_requested]
## (J04 charges stamina) and [member aim] (J04 reads [member Aim.aim_dir] when a skill fires).

## A dodge was asked for while none is running or cooling down. It starts unless a listener
## calls [method DodgeRequest.deny] on [param request]; J04 does when the stamina is short.
signal dodge_requested(request: DodgeRequest)

@export_group("Movement")
## Top walking speed in m/s, before [member movement_multiplier].
@export var move_speed := 6.0
## How fast the velocity closes on the wanted velocity while a move key is held, in m/s².
@export var acceleration := 40.0
## How fast the body brakes once the move keys are released, in m/s².
@export var friction := 30.0
## Downward acceleration while off the floor, in m/s².
@export var gravity := 20.0
## How fast the body turns toward the aim direction, in rad/s.
@export var turn_speed := 20.0

@export_group("Dodge")
## Length of the dash in metres.
@export var dodge_distance := 5.0
## Seconds the dash takes. [member can_act] is false and [member is_invulnerable] true for that long.
@export_range(0.05, 2.0, 0.01) var dodge_duration := 0.25
## Seconds from the start of one dash until the next may start.
@export var dodge_cooldown := 0.8

@export_group("Camera")
## The rig whose yaw the move keys are relative to, so that W is up on screen. Without a rig
## the yaw is 0 and W is -Z.
@export var camera_rig: CameraRig

## Scales the wanted walking speed. 1 is full speed; J04 sets a skill's multiplier (0.6)
## for as long as the skill runs.
var movement_multiplier: float = 1.0
## True for the length of a dash: nothing may hurt the player.
var is_invulnerable: bool = false

## The direction the move keys ask for, on the XZ plane and relative to the camera: unit
## length while a key is held, zero otherwise. Refreshed every physics frame. Read-only.
var move_dir: Vector3:
	get:
		return _move_dir
	set(_value):
		push_error("Player.move_dir is read-only.")
## False while the player may not start an attack or a skill: during a dash. Read-only.
var can_act: bool:
	get:
		return not _is_dodging
	set(_value):
		push_error("Player.can_act is read-only.")
## True while a dash is under way. Read-only.
var is_dodging: bool:
	get:
		return _is_dodging
	set(_value):
		push_error("Player.is_dodging is read-only.")
## Seconds until the next dodge may start, 0 when it is ready. Read-only.
var dodge_cooldown_left: float:
	get:
		return _dodge_cooldown_left
	set(_value):
		push_error("Player.dodge_cooldown_left is read-only.")

var _move_dir := Vector3.ZERO
var _is_dodging := false
var _dodge_dir := Vector3.ZERO
var _dodge_time_left := 0.0
var _dodge_cooldown_left := 0.0

## Where the mouse points. [member Aim.aim_dir] is the direction the player faces and attacks in.
@onready var aim: Aim = $Aim
## The gray-box placeholder. Its nose is the front.
@onready var visual: BoxActor = $Visual


func _physics_process(delta: float) -> void:
	_move_dir = _read_move_dir()
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _is_dodging:
		_dash(delta)
	else:
		_walk(delta)
	_turn_toward_aim(delta)
	move_and_slide()
	if _is_dodging and is_zero_approx(_dodge_time_left):
		_end_dodge()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dodge"):
		try_dodge()


## Starts a dash if none is running or cooling down and no listener of
## [signal dodge_requested] denies it. The dash goes where the move keys point, or along the
## aim direction while no key is held. Returns whether it started.
func try_dodge() -> bool:
	if _is_dodging or not is_zero_approx(_dodge_cooldown_left):
		return false
	var request := DodgeRequest.new()
	dodge_requested.emit(request)
	if not request.allowed:
		return false
	var wanted := _read_move_dir()
	_dodge_dir = aim.aim_dir if wanted.is_zero_approx() else wanted.normalized()
	_dodge_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown
	_is_dodging = true
	is_invulnerable = true
	return true


## The move keys as a direction on the XZ plane, turned by the camera's yaw.
func _read_move_dir() -> Vector3:
	# get_vector caps the length at 1, so a diagonal is no faster than a straight line.
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var yaw := camera_rig.get_yaw() if is_instance_valid(camera_rig) else 0.0
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)


## One physics step of walking: the horizontal velocity closes on the wanted one.
func _walk(delta: float) -> void:
	var wanted := _move_dir * move_speed * movement_multiplier
	var rate := friction if _move_dir.is_zero_approx() else acceleration
	_set_horizontal_velocity(_get_horizontal_velocity().move_toward(wanted, rate * delta))


## One physics step of the dash. The last step may be shorter than a tick; its velocity is
## scaled down to match, so the dash covers [member dodge_distance] at any tick rate.
func _dash(delta: float) -> void:
	var step_time := minf(delta, _dodge_time_left)
	_dodge_time_left -= step_time
	var speed := dodge_distance / dodge_duration
	_set_horizontal_velocity(_dodge_dir * speed * (step_time / delta))


func _end_dodge() -> void:
	_is_dodging = false
	is_invulnerable = false
	# Carry on at walking pace where the keys point, or stand: the dash must not coast on.
	_set_horizontal_velocity(_move_dir * move_speed * movement_multiplier)


## Turns the body toward the aim direction at [member turn_speed]. The move direction plays
## no part in the facing.
func _turn_toward_aim(delta: float) -> void:
	var direction := aim.aim_dir
	# The front of the body is -Z, so a yaw of atan2(-x, -z) points it along the direction.
	var wanted_yaw := atan2(-direction.x, -direction.z)
	var yaw := rotate_toward(global_rotation.y, wanted_yaw, turn_speed * delta)
	global_rotation = Vector3(0.0, yaw, 0.0)


func _get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z
