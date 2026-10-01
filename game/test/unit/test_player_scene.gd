extends GutTest
## The J02 test scene as a whole: the player, the camera rig, the arena and the debug overlay
## are wired together, W goes up the screen, the player turns to the mouse, the rig follows
## what is drawn, and holding skill_1 stands in for the attack slowdown.
##
## The scene runs in a viewport of its own. That gives the tests a mouse they can place and a
## camera nothing competes for, in a window as well as headless.

const TEST_SCENE: PackedScene = preload("res://test/test_player.tscn")
const ARENA: PackedScene = preload("res://test/arena.tscn")
const ACTIONS: Array[StringName] = [&"move_up", &"skill_1"]
## Canvas size of the viewport the scene runs in: the size of the project window. It is drawn
## at half that many pixels, so the mouse and the camera count in different units, as they do
## in a stretched window.
const VIEW_SIZE := Vector2i(1600, 900)
## Physics frames the player walks for in the walking tests.
const WALK_FRAMES := 30
## Physics frames for the body to finish any turn: half a turn takes 10 at the default turn speed.
const TURN_FRAMES := 15
## A frame rate that is no multiple or divisor of the 60 physics ticks per second.
const UNEVEN_FPS := 144

var _viewport: SubViewport
var _scene: Node3D
var _player: Player
var _rig: CameraRig
var _label: Label


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE / 2
	_viewport.size_2d_override = VIEW_SIZE
	_viewport.size_2d_override_stretch = true
	add_child_autofree(_viewport)
	_scene = TEST_SCENE.instantiate()
	_viewport.add_child(_scene)
	_player = _scene.get_node("Player")
	_rig = _scene.get_node("CameraRig")
	_label = _scene.get_node("Overlay/Label")
	await wait_physics_frames(2)


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func test_player_and_rig_are_wired_to_each_other() -> void:
	assert_eq(_player.camera_rig, _rig, "the player walks relative to the rig")
	assert_eq(_rig.target, _player, "the rig follows the player")
	assert_eq(_rig.get_parent(), _scene, "the rig stands in the scene")
	assert_false(_player.is_ancestor_of(_rig), "not under the player")


func test_player_starts_on_the_spawn_marker() -> void:
	var spawn: Marker3D = _scene.get_node("Arena/PlayerSpawn")
	assert_almost_eq(_player.global_position, spawn.global_position, Vector3.ONE * 0.05)
	assert_true(_player.is_on_floor(), "standing on the arena floor")


func test_the_rig_camera_is_the_only_camera() -> void:
	var cameras := _scene.find_children("*", "Camera3D", true, false)
	assert_eq(cameras.size(), 1, "one camera in the whole scene")
	assert_eq(_viewport.get_camera_3d(), _rig.camera, "and the viewport draws with it")


func test_arena_has_no_camera_of_its_own() -> void:
	var arena: Node3D = ARENA.instantiate()
	add_child_autofree(arena)
	assert_eq(arena.find_children("*", "Camera3D", true, false).size(), 0, "a camera here would compete with the rig in every test scene")
	assert_not_null(arena.get_node_or_null("PlayerSpawn"), "the spawn marker is what test scenes place the player on")


func test_overlay_shows_the_debug_values() -> void:
	await wait_process_frames(2)
	assert_is(_label.get_parent(), CanvasLayer, "the overlay is a CanvasLayer with a Label")
	for expected: String in ["speed", "multiplier", "aim point", "dodge cooldown", "fps"]:
		assert_string_contains(_label.text, expected)


func test_holding_skill_1_slows_and_releasing_restores() -> void:
	Input.action_press(&"skill_1")
	await wait_process_frames(2)
	assert_almost_eq(_player.movement_multiplier, 0.6, 0.0001, "held: 60 % as an attack will")
	assert_string_contains(_label.text, "multiplier 0.60")
	Input.action_release(&"skill_1")
	await wait_process_frames(2)
	assert_almost_eq(_player.movement_multiplier, 1.0, 0.0001, "released: full speed")


func test_w_goes_up_the_screen_and_the_rig_follows() -> void:
	Input.action_press(&"move_up")
	await wait_physics_frames(WALK_FRAMES)
	var camera := _rig.camera
	var here := camera.unproject_position(_player.global_position)
	var ahead := camera.unproject_position(_player.global_position + _player.move_dir)
	assert_lt(ahead.y, here.y, "the way W walks is up on screen")
	assert_almost_eq(ahead.x, here.x, 0.5, "straight up, not sideways")

	var walked := -_player.global_position.z
	var followed := -_rig.global_position.z
	assert_gt(walked, 1.0, "the player walked north")
	assert_gt(followed, walked * 0.5, "the rig came along")
	assert_lt(followed, walked, "trailing behind, not ahead")
	assert_almost_eq(_rig.global_position.x, _player.global_position.x, 0.01, "and stays in line")


func test_the_player_turns_to_the_ground_under_the_mouse() -> void:
	var mark := _player.global_position + Vector3(3.0, 0.0, -2.0)
	_point_mouse_at(mark)
	await wait_physics_frames(TURN_FRAMES)
	assert_almost_eq(_player.aim.aim_point, mark, Vector3.ONE * 0.05, "the aim point is the ground under the mouse")
	var wanted := (mark - _player.global_position).normalized()
	assert_almost_eq((-_player.global_basis.z).dot(wanted), 1.0, 0.001, "and the nose points at it")

	Input.action_press(&"move_up")
	await wait_physics_frames(TURN_FRAMES)
	wanted = (_player.aim.aim_point - _player.global_position).normalized()
	assert_almost_eq((-_player.global_basis.z).dot(wanted), 1.0, 0.001, "walking another way, it still faces the mouse")
	assert_lt(wanted.dot(_player.move_dir), 0.99, "which is not the way it walks")


func test_the_rig_follows_the_drawn_player_not_the_physics_tick() -> void:
	# The player is drawn between its physics ticks. A rig that chased the tick position
	# instead would make the player shake on screen whenever frames and ticks fall out of
	# step, so ask for a frame rate that does not divide the tick rate.
	var max_fps := Engine.max_fps
	Engine.max_fps = UNEVEN_FPS
	Input.action_press(&"move_up")
	await wait_physics_frames(TURN_FRAMES)
	var sampler := FollowSampler.new()
	sampler.rig = _rig
	sampler.target = _player
	sampler.process_priority = _rig.process_priority + 1
	add_child_autofree(sampler)
	await wait_physics_frames(WALK_FRAMES)
	Engine.max_fps = max_fps

	assert_lt(sampler.largest_miss, 0.0005, "every frame the rig closed on where the player was drawn")
	if DisplayServer.get_name() == "headless":
		# Only a headless run is sure to get the frame rate it asked for; a window may be
		# held to the monitor, and frames in step with the ticks cannot tell the two apart.
		assert_gt(sampler.frames, WALK_FRAMES, "more frames than ticks were drawn")
		assert_gt(sampler.largest_tick_miss, 0.002, "which is not where the last physics tick left it")


## Puts the mouse over [param point] on the ground, the way a player would point at it.
func _point_mouse_at(point: Vector3) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _rig.camera.unproject_position(point)
	motion.global_position = motion.position
	_viewport.push_input(motion, true)


## Runs right after the rig every rendered frame and works out where the rig should have
## ended up had it closed on the drawn position of its target, and on the tick position.
class FollowSampler:
	extends Node

	var rig: CameraRig
	var target: Node3D
	var frames := 0
	## Furthest the rig ended from where following the drawn position puts it, in metres.
	var largest_miss := 0.0
	## Furthest the rig ended from where following the tick position would have put it.
	var largest_tick_miss := 0.0

	var _rig_before := Vector3.ZERO

	func _process(delta: float) -> void:
		if frames > 0:
			var weight := 1.0 - exp(-rig.follow_rate * delta)
			var drawn := _rig_before.lerp(target.get_global_transform_interpolated().origin, weight)
			var ticked := _rig_before.lerp(target.global_position, weight)
			largest_miss = maxf(largest_miss, rig.global_position.distance_to(drawn))
			largest_tick_miss = maxf(largest_tick_miss, rig.global_position.distance_to(ticked))
		_rig_before = rig.global_position
		frames += 1
