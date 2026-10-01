extends GutTest
## The player body on a floor: one top speed in every direction, walking relative to the
## camera, a facing that follows the aim and never the walk, the attack slowdown, the dodge,
## and sliding along what it walks into. Every test steps real physics frames, so the numbers
## are the ones the game produces.

const PLAYER: PackedScene = preload("res://player/player.tscn")
const CAMERA_RIG: PackedScene = preload("res://player/camera_rig.tscn")
const GROUND: PackedScene = preload("res://graybox/ground_plane.tscn")
const BOX_PROP: PackedScene = preload("res://graybox/box_prop.tscn")

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
## Physics frames for the body to settle on the floor after it is added.
const SETTLE_FRAMES := 3
## Physics frames to reach top speed from a standstill: 9 at the default acceleration, plus spare.
const RUN_UP_FRAMES := 12
## Physics frames to brake from top speed to a stop: 12 at the default friction, plus spare.
const BRAKE_FRAMES := 16
## Physics frames a speed is measured over.
const MEASURE_FRAMES := 10
## Longest wait for a dash, a cooldown, a landing or a way around a pillar, in physics frames.
const TIMEOUT_FRAMES := 120
const SPEED_TOLERANCE := 0.05
const DISTANCE_TOLERANCE := 0.05
const DIRECTION_TOLERANCE := 0.001
## How far above the ground point a test ray starts.
const RAY_HEIGHT := 10.0
## Radius of the body capsule, from the job spec.
const BODY_RADIUS := 0.4

var _player: Player


func before_each() -> void:
	add_child_autofree(GROUND.instantiate())
	_player = PLAYER.instantiate()
	add_child_autofree(_player)
	await _steps(SETTLE_FRAMES)


func after_each() -> void:
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)


func test_body_is_built_to_the_spec() -> void:
	assert_eq(_player.collision_layer, 2, "the body is on layer 2, player_body")
	assert_eq(_player.collision_mask, 1, "and collides with layer 1, world")
	var collision: CollisionShape3D = _player.get_node("Collision")
	var capsule := collision.shape as CapsuleShape3D
	assert_not_null(capsule, "the shape is a capsule")
	assert_almost_eq(capsule.radius, BODY_RADIUS, 0.0001)
	assert_almost_eq(capsule.height, 1.8, 0.0001)
	assert_almost_eq(collision.position.y, capsule.height * 0.5, 0.0001, "the capsule stands on the origin")
	assert_almost_eq(_player.floor_max_angle, deg_to_rad(45.0), 0.0001, "slopes up to 45 degrees are floor")
	assert_gt(_player.floor_snap_length, 0.0, "the body snaps to the floor")
	assert_eq(_player.visual.size_class, Graybox.SizeClass.PLAYER, "the placeholder is the player-sized box")
	assert_lt(_player.aim.process_physics_priority, _player.process_physics_priority, "the aim is measured before the body turns")


func test_stands_on_the_floor() -> void:
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.global_position.y, 0.0, DISTANCE_TOLERANCE)
	assert_almost_eq(_player.velocity.length(), 0.0, SPEED_TOLERANCE, "nothing moves it without input")


func test_falls_at_the_gravity_and_lands() -> void:
	var fall_frames := 6
	_player.global_position = Vector3(0.0, 3.0, 0.0)
	var frames := 0
	while _player.is_on_floor() and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_false(_player.is_on_floor(), "lifted off the floor, it is airborne")
	var speed_before := _player.velocity.y
	await _steps(fall_frames)
	var gained := speed_before - _player.velocity.y
	var expected := _player.gravity * fall_frames / Engine.physics_ticks_per_second
	assert_almost_eq(gained, expected, 0.001, "downward speed gained in %d frames of falling" % fall_frames)

	frames = 0
	while not _player.is_on_floor() and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_true(_player.is_on_floor(), "it lands")
	assert_almost_eq(_player.global_position.y, 0.0, DISTANCE_TOLERANCE, "on the ground, not in it")


func test_diagonal_is_as_fast_as_cardinal() -> void:
	Input.action_press(&"move_up")
	await _steps(RUN_UP_FRAMES)
	var cardinal := await _measure_speed(MEASURE_FRAMES)
	assert_almost_eq(_player.move_dir, Vector3.FORWARD, Vector3.ONE * DIRECTION_TOLERANCE, "W is -Z without a camera yaw")

	Input.action_press(&"move_right")
	await _steps(RUN_UP_FRAMES)
	var diagonal := await _measure_speed(MEASURE_FRAMES)
	var north_east := Vector3(1.0, 0.0, -1.0).normalized()
	assert_almost_eq(_player.move_dir, north_east, Vector3.ONE * DIRECTION_TOLERANCE, "W and D together point between them")

	assert_almost_eq(cardinal, _player.move_speed, SPEED_TOLERANCE, "cardinal speed is the move speed")
	assert_almost_eq(diagonal, _player.move_speed, SPEED_TOLERANCE, "diagonal speed is the move speed")
	assert_almost_eq(diagonal, cardinal, SPEED_TOLERANCE, "and the two are the same")


func test_opposite_keys_cancel() -> void:
	Input.action_press(&"move_left")
	Input.action_press(&"move_right")
	await _steps(RUN_UP_FRAMES)
	assert_eq(_player.move_dir, Vector3.ZERO)
	assert_almost_eq(_player.velocity.length(), 0.0, SPEED_TOLERANCE)


func test_releasing_the_keys_stops_the_body() -> void:
	Input.action_press(&"move_down")
	await _steps(RUN_UP_FRAMES)
	Input.action_release(&"move_down")
	await _steps(BRAKE_FRAMES)
	assert_eq(_player.move_dir, Vector3.ZERO)
	assert_almost_eq(_player.velocity.length(), 0.0, 0.001, "friction brings it to a stop")


func test_walking_is_relative_to_the_camera_yaw() -> void:
	var rig: CameraRig = CAMERA_RIG.instantiate()
	add_child_autofree(rig)
	rig.rotation.y = PI * 0.5
	_player.camera_rig = rig
	Input.action_press(&"move_up")
	await _steps(RUN_UP_FRAMES)
	# A camera turned a quarter to the left looks along -X, so up on screen is -X.
	assert_almost_eq(_player.move_dir, Vector3.LEFT, Vector3.ONE * DIRECTION_TOLERANCE)
	assert_lt(_player.global_position.x, -0.5, "W walks where the camera looks")
	assert_almost_eq(_player.global_position.z, 0.0, DISTANCE_TOLERANCE)


func test_movement_multiplier_scales_the_top_speed() -> void:
	Input.action_press(&"move_right")
	_player.movement_multiplier = 0.6
	await _steps(RUN_UP_FRAMES)
	var slowed := await _measure_speed(MEASURE_FRAMES)
	assert_almost_eq(slowed, _player.move_speed * 0.6, SPEED_TOLERANCE, "60 % while attacking")

	_player.movement_multiplier = 1.0
	await _steps(RUN_UP_FRAMES)
	var released := await _measure_speed(MEASURE_FRAMES)
	assert_almost_eq(released, _player.move_speed, SPEED_TOLERANCE, "full speed again once released")


func test_facing_follows_the_aim_not_the_walk() -> void:
	_aim_at(_player.global_position + Vector3.RIGHT * 5.0)
	Input.action_press(&"move_up")
	await _steps(RUN_UP_FRAMES)
	assert_almost_eq(_facing().dot(Vector3.RIGHT), 1.0, DIRECTION_TOLERANCE, "the nose points at the aim, east")
	assert_almost_eq(_player.velocity.normalized().dot(Vector3.FORWARD), 1.0, DIRECTION_TOLERANCE, "while the body walks north")


func test_turning_takes_time_and_arrives() -> void:
	# The body starts facing -Z; the aim goes straight behind it, half a turn away.
	_aim_at(_player.global_position + Vector3.BACK * 5.0)
	await get_tree().physics_frame
	var step_limit := _player.turn_speed / Engine.physics_ticks_per_second
	var frames_needed := ceili(PI / step_limit)
	var halfway := floori(frames_needed * 0.5)
	var yaw := _player.global_rotation.y
	var largest_step := 0.0
	for frame: int in frames_needed + 2:
		if frame == halfway:
			assert_lt(_facing().dot(Vector3.BACK), 0.9, "half way through, it has not arrived")
		await get_tree().physics_frame
		var new_yaw := _player.global_rotation.y
		largest_step = maxf(largest_step, absf(angle_difference(yaw, new_yaw)))
		yaw = new_yaw
	assert_gt(largest_step, 0.0, "it turned")
	assert_lte(largest_step, step_limit + 0.0001, "never more than turn_speed allows in one frame: no snapping")
	assert_almost_eq(_facing().dot(Vector3.BACK), 1.0, DIRECTION_TOLERANCE, "it ends facing the aim")


func test_dodge_covers_its_distance_and_stops() -> void:
	_aim_at(_player.global_position + Vector3.RIGHT * 5.0)
	await get_tree().physics_frame
	var from := _player.global_position
	assert_true(_player.try_dodge(), "the dodge starts")
	assert_true(_player.is_dodging)
	assert_true(_player.is_invulnerable, "invulnerable for the dash")
	assert_false(_player.can_act, "and unable to act")

	var frames := await _wait_for_dash_end()
	var covered := _player.global_position - from
	assert_eq(frames, roundi(_player.dodge_duration * Engine.physics_ticks_per_second), "the dash lasts its duration")
	assert_almost_eq(covered.x, _player.dodge_distance, DISTANCE_TOLERANCE, "standing still, it dashes along the aim")
	assert_almost_eq(covered.z, 0.0, DISTANCE_TOLERANCE)
	assert_false(_player.is_invulnerable, "vulnerable again")
	assert_true(_player.can_act, "and able to act")

	await _steps(SETTLE_FRAMES)
	var coasted := _player.global_position - from - covered
	assert_almost_eq(coasted.length(), 0.0, 0.001, "the dash does not coast on")


func test_dodge_follows_the_move_keys_over_the_aim() -> void:
	_aim_at(_player.global_position + Vector3.RIGHT * 5.0)
	Input.action_press(&"move_down")
	await _steps(RUN_UP_FRAMES)
	await get_tree().physics_frame
	var from := _player.global_position
	assert_true(_player.try_dodge())
	await _wait_for_dash_end()
	var covered := _player.global_position - from
	assert_almost_eq(covered.z, _player.dodge_distance, DISTANCE_TOLERANCE, "it dashes where the keys point, south")
	assert_almost_eq(covered.x, 0.0, DISTANCE_TOLERANCE, "not along the aim")
	assert_almost_eq(_facing().dot(Vector3.RIGHT), 1.0, DIRECTION_TOLERANCE, "and keeps facing the aim")
	var after := await _measure_speed(MEASURE_FRAMES)
	assert_almost_eq(after, _player.move_speed, SPEED_TOLERANCE, "with the key still held it walks on at walking speed")


func test_dodge_cannot_be_chained_inside_the_cooldown() -> void:
	await get_tree().physics_frame
	assert_true(_player.try_dodge(), "the first dodge starts")
	assert_almost_eq(_player.dodge_cooldown_left, _player.dodge_cooldown, 0.0001)
	var frames := 0
	var started_again := false
	while not started_again and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
		started_again = _player.try_dodge()
	var cooldown_frames := roundi(_player.dodge_cooldown * Engine.physics_ticks_per_second)
	assert_true(started_again, "the next dodge starts in the end")
	assert_eq(frames, cooldown_frames, "but only when the cooldown, counted from the start of the first dash, has run out")


func test_dodge_stops_at_a_wall() -> void:
	var wall := _add_prop(Vector3(2.0, 0.0, 0.0), Vector3(0.5, 3.0, 20.0))
	var wall_face := wall.position.x - wall.size.x * 0.5
	_aim_at(_player.global_position + Vector3.RIGHT * 5.0)
	await _steps(SETTLE_FRAMES)
	assert_true(_player.try_dodge())
	await _wait_for_dash_end()
	assert_almost_eq(_player.global_position.x, wall_face - BODY_RADIUS, DISTANCE_TOLERANCE, "the dash ends against the wall, not behind it")


func test_a_denied_dodge_request_starts_nothing() -> void:
	watch_signals(_player)
	var deny := func(request: DodgeRequest) -> void: request.deny()
	_player.dodge_requested.connect(deny)
	assert_false(_player.try_dodge(), "a listener said no")
	assert_signal_emit_count(_player, "dodge_requested", 1)
	assert_false(_player.is_dodging)
	assert_false(_player.is_invulnerable)
	assert_eq(_player.dodge_cooldown_left, 0.0, "a denied dodge costs no cooldown")

	_player.dodge_requested.disconnect(deny)
	assert_true(_player.try_dodge(), "with nobody denying it the dodge starts")
	assert_false(_player.try_dodge(), "and a second one is not even asked for while the first runs")
	assert_signal_emit_count(_player, "dodge_requested", 2)


func test_the_dodge_action_starts_a_dash() -> void:
	var press := InputEventAction.new()
	press.action = &"dodge"
	press.pressed = true
	_player._unhandled_input(press)
	assert_true(_player.is_dodging)


func test_walking_into_a_wall_slides_along_it() -> void:
	var wall := _add_prop(Vector3(0.0, 0.0, -1.5), Vector3(20.0, 3.0, 0.5))
	var wall_face := wall.position.z + wall.size.z * 0.5
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	await _steps(RUN_UP_FRAMES * 2)
	assert_almost_eq(_player.global_position.z, wall_face + BODY_RADIUS, DISTANCE_TOLERANCE, "the wall stops the way north")
	var along := await _measure_speed(MEASURE_FRAMES)
	var expected := _player.move_speed * cos(PI * 0.25)
	assert_almost_eq(along, expected, SPEED_TOLERANCE, "and the body keeps the eastward part of its speed")
	assert_almost_eq(_player.global_position.z, wall_face + BODY_RADIUS, DISTANCE_TOLERANCE, "without sinking into the wall")


func test_walking_into_a_pillar_slides_around_it() -> void:
	var pillar := _add_prop(Vector3(1.5, 0.0, -2.0), Vector3(1.0, 3.0, 1.0))
	var half := pillar.size.x * 0.5
	var far_side := pillar.global_position.z - half
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	var closest := INF
	var frames := 0
	while _player.global_position.z > far_side and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
		var offset := _player.global_position - pillar.global_position
		# Distance from the axis of the body to the footprint of the pillar; the capsule keeps it at its radius.
		var gap := Vector2(maxf(absf(offset.x) - half, 0.0), maxf(absf(offset.z) - half, 0.0)).length()
		closest = minf(closest, gap)
	assert_gt(closest, BODY_RADIUS - DISTANCE_TOLERANCE, "the body never enters the pillar")
	assert_lt(closest, BODY_RADIUS + DISTANCE_TOLERANCE, "though it did run into it")
	assert_lt(_player.global_position.z, far_side, "and it got past the far side by sliding around")


func test_slips_around_a_pillar_corner_it_only_clips() -> void:
	# The axis of the body runs 4 cm outside the edge of the pillar, so the capsule meets
	# the corner almost head-on. Godot's default wall_min_slide_angle stops a body there.
	var pillar := _add_prop(Vector3(0.0, 0.0, -2.0), Vector3(1.0, 3.0, 1.0))
	var half := pillar.size.x * 0.5
	var far_side := pillar.global_position.z - half
	_player.global_position.x = -(half + 0.04)
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	var frames := 0
	while _player.global_position.z > far_side and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_lt(_player.global_position.z, far_side, "it slipped past the corner instead of stopping on it")


func test_walks_round_a_corner_it_meets_dead_centre() -> void:
	# Walking the diagonal toward a pillar that sits on it, the capsule meets the corner
	# with nowhere to slide. Left alone it would balance there for as long as the keys are held.
	var pillar := _add_prop(Vector3(3.5, 0.0, -3.5), Vector3(1.0, 3.0, 1.0))
	var beyond := _along_north_east(pillar.global_position) + pillar.size.x
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	var frames := 0
	while _along_north_east(_player.global_position) < beyond and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_gt(_along_north_east(_player.global_position), beyond, "it stepped off the corner and walked on")


func test_a_dash_is_carried_round_a_corner_it_meets_dead_centre() -> void:
	var pillar := _add_prop(Vector3(2.0, 0.0, -2.0), Vector3(1.0, 3.0, 1.0))
	# Along the diagonal the capsule touches the corner half a pillar diagonal and its own
	# radius short of the middle of the pillar.
	var meets_corner := _along_north_east(pillar.global_position) - pillar.size.x * sqrt(0.5) - BODY_RADIUS
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	assert_true(_player.try_dodge())
	await _wait_for_dash_end()
	assert_gt(_along_north_east(_player.global_position), meets_corner + 0.75, "the dash did not end on the corner: it slid on round the pillar")


func test_a_wall_met_head_on_stops_the_body_where_it_is() -> void:
	var wall := _add_prop(Vector3(0.0, 0.0, -1.5), Vector3(20.0, 3.0, 0.5))
	var wall_face := wall.position.z + wall.size.z * 0.5
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	await _steps(RUN_UP_FRAMES * 2)
	assert_almost_eq(_player.global_position.z, wall_face + BODY_RADIUS, DISTANCE_TOLERANCE, "it stands against the wall")
	assert_almost_eq(_player.global_position.x, 0.0, 0.0001, "without creeping along it: a wall is no corner")
	assert_almost_eq(_player.velocity.length(), 0.0, 0.001)


func test_slides_along_a_wall_it_meets_almost_head_on() -> void:
	var turn := deg_to_rad(5.0)
	_add_prop(Vector3(0.0, 0.0, -2.0), Vector3(50.0, 3.0, 0.5), turn)
	await _steps(SETTLE_FRAMES)
	Input.action_press(&"move_up")
	await _steps(RUN_UP_FRAMES * 3)
	var along := await _measure_speed(MEASURE_FRAMES)
	assert_almost_eq(along, _player.move_speed * sin(turn), SPEED_TOLERANCE, "it keeps the part of its speed that runs along the wall, however small")


## Points the aim at [param point] on the ground. These tests have no camera, so the aim
## stays where a test puts it.
func _aim_at(point: Vector3) -> void:
	_player.aim.update_from_ray(point + Vector3.UP * RAY_HEIGHT, Vector3.DOWN)


## The direction the front of the body points in.
func _facing() -> Vector3:
	return -_player.global_basis.z


func _add_prop(at: Vector3, size: Vector3, yaw: float = 0.0) -> BoxProp:
	var prop: BoxProp = BOX_PROP.instantiate()
	prop.size = size
	prop.position = at
	prop.rotation.y = yaw
	add_child_autofree(prop)
	return prop


## Steps [param count] physics frames.
func _steps(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## The average horizontal speed of the player in m/s over [param frames] physics frames.
func _measure_speed(frames: int) -> float:
	await get_tree().physics_frame
	var from := _player.global_position
	await _steps(frames)
	var covered := _player.global_position - from
	covered.y = 0.0
	return covered.length() * Engine.physics_ticks_per_second / frames


## Steps physics frames until the dash is over. Returns how many it took.
func _wait_for_dash_end() -> int:
	var frames := 0
	while _player.is_dodging and frames < TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	return frames


## How far [param point] lies along the north-east diagonal, the way W and D walk together.
func _along_north_east(point: Vector3) -> float:
	return point.dot(Vector3(1.0, 0.0, -1.0).normalized())
