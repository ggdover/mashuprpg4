extends SceneTree
## Measures how steadily the camera rig follows the player at capped frame rates.
## Run it through tools\camera_follow_probe.cmd.
##
## It runs game/test/test_player.tscn headless, holds W, and for each frame cap watches the
## distance between the rig and the position the player is drawn at. On a steady walk that
## distance should hold still: any change in it is the player shaking on screen. This is
## J02's "camera follows without jitter at 30, 60 and 144 fps", measured instead of looked at.
## Next to it the probe prints what a rig chasing the physics ticks would have done.

const SCENE := "res://test/test_player.tscn"
const FRAME_RATES: Array[int] = [30, 60, 144]
## Where each walk starts: a lane of the arena with no pillar in it.
const START := Vector3(4.0, 0.0, 18.0)
## Seconds for the walk and the follow to settle before the measuring starts.
const SETTLE_SECONDS := 1.5
## Seconds measured at each frame rate.
const MEASURE_SECONDS := 2.5
## Largest change of the distance that still counts as steady, in metres.
const STEADY_WITHIN := 0.002

const EXIT_OK := 0
const EXIT_FAILED := 1

var _player: Player
var _rig: CameraRig
var _sampler: Sampler
var _rate_index := 0
var _elapsed := 0.0
var _started := false
var _exit_code := EXIT_OK


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_set_up()
		return false
	if _sampler == null:
		# The set-up stopped on an error, which the engine has printed. End the run instead
		# of leaving a headless Godot behind.
		quit(EXIT_FAILED)
		return true
	_elapsed += delta
	_sampler.measuring = _elapsed >= SETTLE_SECONDS
	if _elapsed < SETTLE_SECONDS + MEASURE_SECONDS:
		return false
	_report()
	if _rate_index + 1 >= FRAME_RATES.size():
		quit(_exit_code)
		return true
	_start_walk(_rate_index + 1)
	return false


func _set_up() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_rig = scene.get_node("CameraRig")
	_sampler = Sampler.new()
	_sampler.player = _player
	_sampler.rig = _rig
	_sampler.process_priority = _rig.process_priority + 1
	root.add_child(_sampler)
	Input.action_press(&"move_up")
	_start_walk(0)


func _start_walk(rate_index: int) -> void:
	_rate_index = rate_index
	Engine.max_fps = FRAME_RATES[rate_index]
	_player.global_position = START
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_rig.snap_to_target()
	_sampler.restart()
	_elapsed = 0.0


func _report() -> void:
	var spread := _sampler.largest - _sampler.smallest
	var tick_spread := _sampler.tick_largest - _sampler.tick_smallest
	var steady := _sampler.frames > 0 and spread <= STEADY_WITHIN
	if not steady:
		_exit_code = EXIT_FAILED
	print("%3d fps: %3d frames, rig %.3f m behind the drawn player, varying by %.2f mm (%s); chasing the physics ticks it would vary by %.2f mm" % [
		FRAME_RATES[_rate_index], _sampler.frames, _sampler.largest, spread * 1000.0,
		"steady" if steady else "NOT STEADY", tick_spread * 1000.0,
	])


## Runs right after the rig every rendered frame and records how far the rig is from the
## position the player is drawn at, and how far a rig chasing the tick position would be.
class Sampler:
	extends Node

	var player: Player
	var rig: CameraRig
	var measuring := false
	var frames := 0
	var smallest := INF
	var largest := -INF
	var tick_smallest := INF
	var tick_largest := -INF

	var _tick_chaser := Vector3.ZERO

	func restart() -> void:
		measuring = false
		frames = 0
		smallest = INF
		largest = -INF
		tick_smallest = INF
		tick_largest = -INF
		_tick_chaser = player.global_position

	func _process(delta: float) -> void:
		var drawn := player.get_global_transform_interpolated().origin
		_tick_chaser = _tick_chaser.lerp(player.global_position, 1.0 - exp(-rig.follow_rate * delta))
		if not measuring:
			return
		var gap := drawn.distance_to(rig.global_position)
		var tick_gap := drawn.distance_to(_tick_chaser)
		smallest = minf(smallest, gap)
		largest = maxf(largest, gap)
		tick_smallest = minf(tick_smallest, tick_gap)
		tick_largest = maxf(tick_largest, tick_gap)
		frames += 1
