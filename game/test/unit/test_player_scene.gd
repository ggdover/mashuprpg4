extends GutTest
## The J02 test scene as a whole: the player, the camera rig, the arena and the debug overlay
## are wired together, W goes up the screen, the player turns to the mouse, the rig follows
## what is drawn, stays on a player that is teleported and follows it on when it walks
## through the teleport, and holding skill_1 stands in for the attack slowdown.
##
## The scene runs in a viewport of its own. That gives the tests a mouse they can place and a
## camera nothing competes for, in a window as well as headless.

const TEST_SCENE: PackedScene = preload("res://test/test_player.tscn")
const ARENA: PackedScene = preload("res://test/arena.tscn")
const ACTIONS: Array[StringName] = [&"move_up", &"skill_1"]
## Canvas size of the viewport the scene runs in: the size of the project window.
const VIEW_SIZE := Vector2i(1600, 900)
## The pixels that canvas is drawn at. Half as many each way, so the mouse and the camera
## count in different units, as they do in a stretched window.
const DRAWN_SIZE := Vector2i(800, 450)
## Physics frames the player walks for in the walking test.
const WALK_FRAMES := 30
## Physics frames for the body to finish any turn: half a turn takes 10 at the default turn speed.
const TURN_FRAMES := 15
## Physics frames the rig is watched for at each frame rate.
const FOLLOW_FRAMES := 20
## The frame rates the job asks the follow to be smooth at.
const FRAME_RATES: Array[int] = [30, 60, 144]
## The one among them that is no multiple or divisor of the 60 physics ticks per second.
const UNEVEN_FPS := 144
## How far the teleport tests move the player, from the spawn to a free spot of the arena
## and back: far enough for a rig that eases any part of the way to show.
const TELEPORT := Vector3(9.0, 0.0, -12.0)
## Rendered frames the rig is watched for after a teleport.
const TELEPORT_FRAMES := 4
## Furthest the rig may stand from a player it was snapped to, in metres.
const ON_TARGET := 0.001
## Furthest the rig may end a frame from where following the drawn player puts it, in metres.
const ON_COURSE := 0.0005
## The key of the input events the tests send themselves. No action is bound to it.
const TAP_KEY := KEY_F24

var _viewport: SubViewport
var _scene: Node3D
var _player: Player
var _rig: CameraRig
var _label: Label


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = DRAWN_SIZE
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


func test_the_rig_follows_the_drawn_player_at_every_frame_rate() -> void:
	# The player is drawn between its physics ticks. A rig that chased the tick position
	# instead would make the player shake on screen whenever frames and ticks fall out of
	# step, as they do at 144 frames against 60 ticks a second.
	var max_fps := Engine.max_fps
	Input.action_press(&"move_up")
	await wait_physics_frames(TURN_FRAMES)
	for fps: int in FRAME_RATES:
		Engine.max_fps = fps
		var sampler := FollowSampler.new()
		sampler.rig = _rig
		sampler.target = _player
		sampler.process_priority = _rig.process_priority + 1
		add_child_autofree(sampler)
		await wait_physics_frames(FOLLOW_FRAMES)
		sampler.set_process(false)
		assert_lt(sampler.largest_miss, ON_COURSE, "at %d fps the rig closed, every frame, on where the player was drawn" % fps)
		if fps == UNEVEN_FPS and DisplayServer.get_name() == "headless":
			# Only a headless run is free of the monitor: a window may be held to its refresh
			# rate, and frames in step with the ticks cannot tell the two apart.
			assert_gt(sampler.largest_tick_miss, 0.002, "which at %d fps is not where the last physics tick left it" % fps)
	Engine.max_fps = max_fps


func test_a_teleport_before_the_rig_has_had_its_frame_leaves_no_glide() -> void:
	# A coroutine that process_frame resumes runs ahead of every _process of that frame, the
	# rig's included. The engine has worked out where the player is drawn by then, and after
	# a jump that is still the old place: a rig that eased toward it would be pulled back.
	await _assert_a_teleport_leaves_no_glide(get_tree().process_frame)


func test_a_teleport_in_a_physics_tick_leaves_no_glide() -> void:
	await _assert_a_teleport_leaves_no_glide(get_tree().physics_frame)


func test_a_teleport_in_an_input_event_leaves_no_glide() -> void:
	await _assert_a_teleport_leaves_no_glide(_tap_input_events())


func test_a_walk_through_a_teleport_in_a_physics_tick_is_followed_as_drawn() -> void:
	# The player walks on in the tick it is teleported in, and the frame draws it up to a
	# tick of travel behind where it then stands. A rig that headed for the player's own
	# position in that frame would run ahead of the picture, by up to 23 mm at 30 fps.
	await _assert_a_walk_through_a_teleport_is_followed_as_drawn(get_tree().physics_frame)


func test_a_walk_through_a_teleport_in_an_input_event_is_followed_as_drawn() -> void:
	# A key press or a click reaches a script ahead of the frame's physics ticks, so the
	# player walks on in the same frame here too.
	await _assert_a_walk_through_a_teleport_is_followed_as_drawn(_tap_input_events())


## Puts the mouse over [param point] on the ground, the way a player would point at it.
func _point_mouse_at(point: Vector3) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _rig.camera.unproject_position(point)
	motion.global_position = motion.position
	_viewport.push_input(motion, true)


## A signal that fires once every rendered frame from inside the handling of an input event.
func _tap_input_events() -> Signal:
	var tap := InputTap.new()
	add_child_autofree(tap)
	return tap.arrived


## Teleports the player by [param jump] the way J12's zone change and J20's respawn will:
## move it, reset its interpolation, snap the rig.
func _teleport(jump: Vector3) -> void:
	_player.global_position += jump
	_player.reset_physics_interpolation()
	_rig.snap_to_target()


## Teleports the standing player as soon as [param resumed_by] fires, once at each frame
## rate. Asserts that the rig stands on the player from that very frame on.
func _assert_a_teleport_leaves_no_glide(resumed_by: Signal) -> void:
	var max_fps := Engine.max_fps
	var jump := TELEPORT
	for fps: int in FRAME_RATES:
		Engine.max_fps = fps
		# Two frames for the new cap to set the length of a frame.
		await wait_process_frames(2)
		await resumed_by
		var frame := Engine.get_process_frames()
		_teleport(jump)
		var sampler := StraySampler.new()
		sampler.rig = _rig
		sampler.target = _player
		sampler.process_priority = _rig.process_priority + 1
		add_child_autofree(sampler)
		for i: int in TELEPORT_FRAMES:
			await get_tree().process_frame
		sampler.set_process(false)
		assert_eq(sampler.first_frame, frame, "at %d fps the rig had yet to move in the frame of the teleport" % fps)
		assert_lt(sampler.largest, ON_TARGET, "at %d fps it stood on the player from that frame on" % fps)
		# There, back and there again.
		jump = -jump
	Engine.max_fps = max_fps


## Walks the player through a teleport made as soon as [param resumed_by] fires, once at
## each frame rate. Asserts that the rig ends the frame of the teleport, and the frames
## after it, where following the drawn player puts it.
func _assert_a_walk_through_a_teleport_is_followed_as_drawn(resumed_by: Signal) -> void:
	var max_fps := Engine.max_fps
	var jump := TELEPORT
	Input.action_press(&"move_up")
	await wait_physics_frames(TURN_FRAMES)
	for fps: int in FRAME_RATES:
		Engine.max_fps = fps
		# Two frames for the new cap to set the length of a frame.
		await wait_process_frames(2)
		await resumed_by
		var frame := Engine.get_process_frames()
		_teleport(jump)
		var sampler := FollowSampler.new()
		sampler.rig = _rig
		sampler.target = _player
		sampler.process_priority = _rig.process_priority + 1
		sampler.start_from_here()
		add_child_autofree(sampler)
		for i: int in TELEPORT_FRAMES:
			await get_tree().process_frame
		sampler.set_process(false)
		assert_eq(sampler.first_frame, frame, "at %d fps the rig was watched from the frame of the teleport on" % fps)
		assert_lt(sampler.largest_miss, ON_COURSE, "at %d fps it closed, every frame, on where the player was drawn" % fps)
		# There, back and there again.
		jump = -jump
	Engine.max_fps = max_fps


## Runs right after the rig every rendered frame and works out where the rig should have
## ended up had it closed on the drawn position of its target, and on the tick position.
class FollowSampler:
	extends Node

	var rig: CameraRig
	var target: Node3D
	## The rendered frame the first comparison was made in.
	var first_frame := -1
	## Furthest the rig ended from where following the drawn position puts it, in metres.
	var largest_miss := 0.0
	## Furthest the rig ended from where following the tick position would have put it.
	var largest_tick_miss := 0.0

	var _rig_before := Vector3.ZERO
	var _has_before := false

	## Takes where the rig stands now for where it starts its next frame from, so that the
	## comparing begins with that frame. Left out, it begins one frame later.
	func start_from_here() -> void:
		_rig_before = rig.global_position
		_has_before = true

	func _process(delta: float) -> void:
		if _has_before:
			if first_frame < 0:
				first_frame = Engine.get_process_frames()
			var weight := 1.0 - exp(-rig.follow_rate * delta)
			var drawn := _rig_before.lerp(target.get_global_transform_interpolated().origin, weight)
			var ticked := _rig_before.lerp(target.global_position, weight)
			largest_miss = maxf(largest_miss, rig.global_position.distance_to(drawn))
			largest_tick_miss = maxf(largest_tick_miss, rig.global_position.distance_to(ticked))
		_rig_before = rig.global_position
		_has_before = true


## Runs right after the rig every rendered frame and keeps how far the rig stood from its
## target's own position, the place a teleport and a snap put both on.
class StraySampler:
	extends Node

	var rig: CameraRig
	var target: Node3D
	var frames := 0
	## The rendered frame the first sample was taken in.
	var first_frame := -1
	## Furthest the rig stood from its target, in metres.
	var largest := 0.0

	func _process(_delta: float) -> void:
		if frames == 0:
			first_frame = Engine.get_process_frames()
		largest = maxf(largest, rig.global_position.distance_to(target.global_position))
		frames += 1


## Sends itself an input event every rendered frame and emits [signal arrived] from inside
## the handling of each. The engine hands an event out when the next frame begins, ahead of
## that frame's physics ticks: the place in a frame where a key press or a click reaches a
## script.
class InputTap:
	extends Node

	signal arrived

	func _process(_delta: float) -> void:
		var event := InputEventKey.new()
		event.physical_keycode = TAP_KEY
		Input.parse_input_event(event)

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.physical_keycode == TAP_KEY:
			arrived.emit()
