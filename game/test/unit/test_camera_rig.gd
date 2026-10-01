extends GutTest
## The camera rig: where the camera hangs, how the rig closes on its target whatever the
## frame rate, the zoom and its limits, and the yaw the move keys read. The frame-rate tests
## call _process with the frame time of each rate, so they do not depend on the machine.

const CAMERA_RIG: PackedScene = preload("res://player/camera_rig.tscn")
## The frame rates the job asks the follow to be smooth at.
const FRAME_RATES: Array[int] = [30, 60, 144]
const TOLERANCE := 0.001

var _rig: CameraRig
var _target: Node3D


func before_each() -> void:
	_target = _make_target(Vector3.ZERO)
	_rig = CAMERA_RIG.instantiate()
	_rig.target = _target
	add_child_autofree(_rig)


func test_camera_hangs_at_the_pitch_and_distance() -> void:
	var camera := _rig.camera
	var pitch := deg_to_rad(55.0)
	assert_almost_eq(camera.position, Vector3(0.0, sin(pitch), cos(pitch)) * 18.0, Vector3.ONE * TOLERANCE, "18 m out, 55 degrees up, straight behind")
	assert_almost_eq((-camera.basis.z).dot(-camera.position.normalized()), 1.0, 0.0001, "looking at the origin of the rig")
	assert_almost_eq(camera.rotation.y, 0.0, 0.0001, "no yaw")
	assert_almost_eq(camera.fov, 40.0, 0.0001)
	assert_eq(get_viewport().get_camera_3d(), camera, "it is the camera the viewport draws with")


func test_scene_stores_the_camera_where_the_script_puts_it() -> void:
	var fresh: CameraRig = CAMERA_RIG.instantiate()
	var stored := (fresh.get_node("Camera") as Camera3D).transform
	add_child_autofree(fresh)
	var placed := fresh.camera.transform
	assert_almost_eq(stored.origin, placed.origin, Vector3.ONE * TOLERANCE, "the editor preview and the running game agree on the place")
	assert_almost_eq(stored.basis.z, placed.basis.z, Vector3.ONE * TOLERANCE, "and on the tilt")


func test_rig_is_not_physics_interpolated() -> void:
	assert_eq(_rig.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "the rig moves every rendered frame by itself")
	assert_false(_rig.camera.is_physics_interpolated(), "and the camera under it inherits that")


func test_rig_starts_on_its_target() -> void:
	var target := _make_target(Vector3(5.0, 0.0, -5.0))
	var rig: CameraRig = CAMERA_RIG.instantiate()
	rig.target = target
	add_child_autofree(rig)
	assert_eq(rig.global_position, target.global_position, "no glide in from the origin when the scene starts")


func test_follow_closes_the_same_share_of_the_gap_at_any_frame_rate() -> void:
	var goal := Vector3(10.0, 0.0, -4.0)
	var seconds := 0.5
	var expected := goal * (1.0 - exp(-_rig.follow_rate * seconds))
	for fps: int in FRAME_RATES:
		_target.position = Vector3.ZERO
		_rig.snap_to_target()
		_target.position = goal
		_run_frames(fps, seconds)
		assert_almost_eq(_rig.position, expected, Vector3.ONE * TOLERANCE, "after %.1f s at %d fps" % [seconds, fps])


func test_follow_trails_a_steady_walk_by_a_steady_gap() -> void:
	var speed := 6.0
	for fps: int in FRAME_RATES:
		var delta := 1.0 / fps
		_target.position = Vector3.ZERO
		_rig.snap_to_target()
		var smallest := INF
		var largest := -INF
		for frame: int in fps * 3:
			_target.position.x += speed * delta
			_rig._process(delta)
			if frame >= fps * 2:
				var gap := _target.position.x - _rig.position.x
				smallest = minf(smallest, gap)
				largest = maxf(largest, gap)
		assert_almost_eq(largest - smallest, 0.0, 0.0001, "the gap holds still at %d fps: nothing to see as jitter" % fps)
		assert_almost_eq(largest, speed / _rig.follow_rate, 0.15, "about speed / follow_rate behind at %d fps" % fps)


func test_rig_without_a_target_stays_put() -> void:
	_rig.position = Vector3(1.0, 2.0, 3.0)
	_rig.target = null
	_rig._process(0.1)
	assert_eq(_rig.position, Vector3(1.0, 2.0, 3.0))

	var gone := Node3D.new()
	_rig.target = gone
	gone.free()
	_rig._process(0.1)
	_rig.snap_to_target()
	assert_eq(_rig.position, Vector3(1.0, 2.0, 3.0), "a freed target is left alone too")


func test_snap_to_target_jumps_without_gliding() -> void:
	_target.position = Vector3(7.0, 1.0, -3.0)
	_rig.zoom(4.0)
	_rig.snap_to_target()
	assert_eq(_rig.global_position, _target.global_position)
	assert_almost_eq(_rig.camera.position.length(), 22.0, TOLERANCE, "the zoom jumps with it")


func test_zoom_stays_between_the_limits() -> void:
	assert_eq(_rig.min_distance, 12.0)
	assert_eq(_rig.max_distance, 24.0)
	_rig.zoom(-100.0)
	assert_eq(_rig.distance, _rig.min_distance, "no closer than the minimum")
	_rig.zoom(100.0)
	assert_eq(_rig.distance, _rig.max_distance, "no further than the maximum")


func test_mouse_wheel_zooms_a_step_per_notch() -> void:
	var start := _rig.distance
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, true))
	assert_almost_eq(_rig.distance, start - _rig.zoom_step, TOLERANCE, "wheel up zooms in")
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, true))
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, true))
	assert_almost_eq(_rig.distance, start + _rig.zoom_step, TOLERANCE, "wheel down zooms out")
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, false))
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_LEFT, true))
	assert_almost_eq(_rig.distance, start + _rig.zoom_step, TOLERANCE, "a release and another button do nothing")


func test_camera_eases_to_the_zoom_distance() -> void:
	_rig.zoom(-3.0)
	assert_almost_eq(_rig.camera.position.length(), 18.0, TOLERANCE, "it does not jump")
	_run_frames(60, 0.1)
	assert_between(_rig.camera.position.length(), 15.1, 17.9, "it is on its way after a moment")
	_run_frames(60, 1.5)
	assert_almost_eq(_rig.camera.position.length(), 15.0, TOLERANCE, "and arrives")
	assert_almost_eq((-_rig.camera.basis.z).dot(-_rig.camera.position.normalized()), 1.0, 0.0001, "still looking at the origin of the rig")


func test_get_yaw_reports_the_rotation_of_the_rig() -> void:
	assert_almost_eq(_rig.get_yaw(), 0.0, 0.0001, "the yaw is fixed at 0")
	_rig.rotation.y = 0.5
	assert_almost_eq(_rig.get_yaw(), 0.5, 0.0001, "and would be passed on if something turned the rig")


## A stand-in for the player. The rig reads where its target is drawn, and in the frame of a
## snap where it stands. A node that a test moves by hand has no physics ticks to be drawn
## between, so its interpolation is off and the two are the same place.
func _make_target(at: Vector3) -> Node3D:
	var target := Node3D.new()
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	target.position = at
	add_child_autofree(target)
	return target


## Runs the rig for [param seconds] of frames at [param fps] frames per second.
func _run_frames(fps: int, seconds: float) -> void:
	for frame: int in roundi(fps * seconds):
		_rig._process(1.0 / fps)


func _wheel(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
