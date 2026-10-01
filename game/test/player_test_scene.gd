class_name PlayerTestScene
extends Node3D
## J02's test scene: the player in the arena with the camera rig, and a debug overlay for
## judging the feel. Until J04 brings skills, holding skill_1 (RMB) stands in for an attack
## and slows the player the way an attack will.

## What [member Player.movement_multiplier] is set to while skill_1 is held: the gdd's
## slowdown for any attack or skill.
@export var attack_multiplier := 0.6

@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _spawn: Marker3D = $Arena/PlayerSpawn
@onready var _label: Label = $Overlay/Label


func _ready() -> void:
	_player.global_position = _spawn.global_position
	_player.reset_physics_interpolation()
	_camera_rig.snap_to_target()
	_label.add_theme_color_override(&"font_color", Palette.role(&"text", WorldState.state))
	_label.add_theme_color_override(&"font_outline_color", Palette.role(&"deepest", WorldState.state))


func _process(_delta: float) -> void:
	_player.movement_multiplier = attack_multiplier if Input.is_action_pressed(&"skill_1") else 1.0
	_label.text = _describe()


## The overlay text: what the job spec asks to see, and the keys.
func _describe() -> String:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var aim_point := _player.aim.aim_point
	var cooldown := _player.dodge_cooldown_left
	return "\n".join([
		"speed %.2f m/s" % speed,
		"multiplier %.2f" % _player.movement_multiplier,
		"aim point (%.1f, %.1f, %.1f)" % [aim_point.x, aim_point.y, aim_point.z],
		"dodge cooldown %s" % ("ready" if is_zero_approx(cooldown) else "%.2f s" % cooldown),
		"fps %d" % roundi(Engine.get_frames_per_second()),
		"",
		"WASD move, mouse aim, Space dodge, hold RMB to slow as an attack will, wheel zoom",
	])
