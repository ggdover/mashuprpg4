extends SceneTree
## Measures how steadily the camera rig follows the player at one frame rate.
## tools\camera_follow_probe.cmd runs it at 30, 60 and 144 frames per second.
##
## It runs game/test/test_player.tscn headless, holds W, and watches the distance between
## the rig and the position the player is drawn at. On a steady walk that distance should
## hold still: any change in it is the player shaking on screen. This is J02's "camera
## follows without jitter at 30, 60 and 144 fps", measured instead of looked at. Next to it
## the probe prints what a rig chasing the physics ticks would have done.
##
## The frame rate comes from Godot's --fixed-fps option, which gives every frame the same
## length of game time whatever the machine is doing. A frame cap will not do. How long a
## capped frame really takes is up to the timer of the machine, and the distance between
## the rig and the player changes with the length of the frame. Run without --fixed-fps
## the probe gives no verdict.
##
## The script names neither Player nor CameraRig. Godot compiles a script it runs with -s,
## and every class that script names, before the autoloads are registered, so naming them
## would break the probe on the day one of them reaches an autoload. It finds both nodes by
## their path in the scene and reaches what it needs of the rig by name.

const SCENE := "res://test/test_player.tscn"
## Where the walk starts: a lane of the arena with no pillar in it.
const START := Vector3(4.0, 0.0, 18.0)
## Seconds for the walk and the follow to settle before the measuring starts.
const SETTLE_SECONDS := 1.5
## Seconds measured.
const MEASURE_SECONDS := 2.5
## Largest change of the distance that still counts as steady, in metres.
const STEADY_WITHIN := 0.002
## Largest difference between the longest and the shortest frame that still counts as a
## fixed frame rate, in seconds.
const SAME_LENGTH_WITHIN := 0.000001
## The property and the method of CameraRig the probe uses.
const FOLLOW_RATE := &"follow_rate"
const SNAP_TO_TARGET := &"snap_to_target"

const EXIT_OK := 0
const EXIT_FAILED := 1

var _sampler: Sampler
var _elapsed := 0.0
var _started := false


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_set_up()
		return false
	if _sampler == null:
		# The set-up stopped on an error, which has been printed. End the run instead of
		# leaving a headless Godot behind.
		quit(EXIT_FAILED)
		return true
	_elapsed += delta
	_sampler.measuring = _elapsed >= SETTLE_SECONDS
	if _elapsed < SETTLE_SECONDS + MEASURE_SECONDS:
		return false
	quit(_report())
	return true


func _set_up() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node_or_null("Player") as CharacterBody3D
	var rig := scene.get_node_or_null("CameraRig") as Node3D
	if player == null or rig == null or not rig.has_method(SNAP_TO_TARGET) or FOLLOW_RATE not in rig:
		push_error("camera_follow_probe: %s must hold a CharacterBody3D named Player and a Node3D named CameraRig that has %s and %s()." % [SCENE, FOLLOW_RATE, SNAP_TO_TARGET])
		return
	Input.action_press(&"move_up")
	player.global_position = START
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	rig.call(SNAP_TO_TARGET)
	_sampler = Sampler.new()
	_sampler.player = player
	_sampler.rig = rig
	_sampler.process_priority = rig.process_priority + 1
	root.add_child(_sampler)


## Prints what was measured and returns the exit code that goes with it.
func _report() -> int:
	if _sampler.longest_frame - _sampler.shortest_frame > SAME_LENGTH_WITHIN:
		print("No verdict: the frames were between %.2f and %.2f ms long. Run tools/camera_follow_probe.cmd, which fixes the frame rate with --fixed-fps." % [
			_sampler.shortest_frame * 1000.0, _sampler.longest_frame * 1000.0,
		])
		return EXIT_FAILED
	var spread := _sampler.largest - _sampler.smallest
	var tick_spread := _sampler.tick_largest - _sampler.tick_smallest
	var steady := _sampler.frames > 0 and spread <= STEADY_WITHIN
	print("%3d fps: %3d frames, rig %.3f m behind the drawn player, varying by %.2f mm (%s); chasing the physics ticks it would vary by %.2f mm" % [
		roundi(1.0 / _sampler.longest_frame), _sampler.frames, _sampler.largest, spread * 1000.0,
		"steady" if steady else "NOT STEADY", tick_spread * 1000.0,
	])
	return EXIT_OK if steady else EXIT_FAILED


## Runs right after the rig every rendered frame and records how far the rig is from the
## position the player is drawn at, and how far a rig chasing the tick position would be.
class Sampler:
	extends Node

	var player: Node3D
	var rig: Node3D
	var measuring := false
	var frames := 0
	var smallest := INF
	var largest := -INF
	var tick_smallest := INF
	var tick_largest := -INF
	var shortest_frame := INF
	var longest_frame := -INF

	var _tick_chaser := Vector3.ZERO

	func _ready() -> void:
		_tick_chaser = player.global_position

	func _process(delta: float) -> void:
		var drawn := player.get_global_transform_interpolated().origin
		var follow_rate: float = rig.get(FOLLOW_RATE)
		_tick_chaser = _tick_chaser.lerp(player.global_position, 1.0 - exp(-follow_rate * delta))
		if not measuring:
			return
		var gap := drawn.distance_to(rig.global_position)
		var tick_gap := drawn.distance_to(_tick_chaser)
		smallest = minf(smallest, gap)
		largest = maxf(largest, gap)
		tick_smallest = minf(tick_smallest, tick_gap)
		tick_largest = maxf(tick_largest, tick_gap)
		shortest_frame = minf(shortest_frame, delta)
		longest_frame = maxf(longest_frame, delta)
		frames += 1
