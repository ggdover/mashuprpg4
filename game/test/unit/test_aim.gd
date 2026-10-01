extends GutTest
## The aim: a ray onto the ground plane at the height of the player gives the aim point and a
## flat unit direction; a ray or a point that gives no direction keeps the last one.

const TOLERANCE := Vector3.ONE * 0.0001
## Size in pixels of the viewport the camera test runs in.
const VIEW_SIZE := Vector2i(800, 600)
## How far above the ground the camera of that test hangs, in metres.
const CAMERA_HEIGHT := 20.0

var _origin: Node3D
var _aim: Aim


func before_each() -> void:
	_origin = Node3D.new()
	_aim = Aim.new()
	_origin.add_child(_aim)
	add_child_autofree(_origin)


func test_aim_point_is_where_the_ray_meets_the_ground() -> void:
	_origin.position = Vector3(1.0, 0.0, 2.0)
	_aim.update_from_ray(Vector3(4.0, 10.0, 6.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_point, Vector3(4.0, 0.0, 6.0), TOLERANCE)
	assert_almost_eq(_aim.aim_dir, Vector3(0.6, 0.0, 0.8), TOLERANCE, "from the player toward the point, unit length")


func test_a_slanted_ray_lands_where_it_crosses_the_plane() -> void:
	_aim.update_from_ray(Vector3(0.0, 10.0, 10.0), Vector3(0.0, -1.0, -1.0).normalized())
	assert_almost_eq(_aim.aim_point, Vector3.ZERO, TOLERANCE, "ten down and ten forward from the start")
	_aim.update_from_ray(Vector3(3.0, 10.0, 10.0), Vector3(0.0, -1.0, -1.0).normalized())
	assert_almost_eq(_aim.aim_point, Vector3(3.0, 0.0, 0.0), TOLERANCE)
	assert_almost_eq(_aim.aim_dir, Vector3.RIGHT, TOLERANCE)


func test_the_ground_plane_sits_at_the_height_of_the_player() -> void:
	_origin.position = Vector3(0.0, 2.0, 0.0)
	_aim.update_from_ray(Vector3(0.0, 10.0, -5.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_point, Vector3(0.0, 2.0, -5.0), TOLERANCE, "a slab two metres up raises the plane with the player")
	assert_almost_eq(_aim.aim_dir, Vector3.FORWARD, TOLERANCE)
	assert_eq(_aim.aim_dir.y, 0.0, "the direction stays flat")


func test_a_ray_that_misses_the_ground_keeps_the_last_aim() -> void:
	_aim.update_from_ray(Vector3(5.0, 10.0, 0.0), Vector3.DOWN)
	_aim.update_from_ray(Vector3(0.0, 10.0, 5.0), Vector3.UP)
	assert_almost_eq(_aim.aim_point, Vector3(5.0, 0.0, 0.0), TOLERANCE, "a ray going up never meets the ground")
	_aim.update_from_ray(Vector3(0.0, 10.0, 5.0), Vector3.FORWARD)
	assert_almost_eq(_aim.aim_point, Vector3(5.0, 0.0, 0.0), TOLERANCE, "nor does a level one")
	assert_almost_eq(_aim.aim_dir, Vector3.RIGHT, TOLERANCE)


func test_the_mouse_on_the_player_keeps_the_last_direction() -> void:
	_origin.position = Vector3(2.0, 0.0, 2.0)
	_aim.update_from_ray(Vector3(2.0, 10.0, 7.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_dir, Vector3.BACK, TOLERANCE)

	_aim.update_from_ray(Vector3(2.0, 10.0, 2.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_point, Vector3(2.0, 0.0, 2.0), TOLERANCE, "the point follows the mouse onto the player")
	assert_almost_eq(_aim.aim_dir, Vector3.BACK, TOLERANCE, "the direction has nothing to point at and stays")

	var inside := _aim.min_aim_distance * 0.5
	_aim.update_from_ray(Vector3(2.0 + inside, 10.0, 2.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_dir, Vector3.BACK, TOLERANCE, "closer than min_aim_distance still counts as on the player")

	var outside := _aim.min_aim_distance * 2.0
	_aim.update_from_ray(Vector3(2.0 + outside, 10.0, 2.0), Vector3.DOWN)
	assert_almost_eq(_aim.aim_dir, Vector3.RIGHT, TOLERANCE, "further out the direction follows again")


func test_aim_starts_where_the_player_faces() -> void:
	var turned := Node3D.new()
	turned.rotation.y = PI * 0.5
	var aim := Aim.new()
	turned.add_child(aim)
	add_child_autofree(turned)
	assert_almost_eq(aim.aim_dir, Vector3.LEFT, TOLERANCE, "a quarter turn to the left faces -X")
	assert_almost_eq(_aim.aim_dir, Vector3.FORWARD, TOLERANCE, "an unturned player faces -Z")


func test_aim_follows_the_mouse_through_the_active_camera() -> void:
	# A viewport of its own gives the test a mouse it can place, in a window as well as
	# headless: a SubViewport takes its mouse position from the last mouse event handed to it.
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	add_child_autofree(viewport)
	var below := Vector3(3.0, 0.0, -2.0)
	var camera := Camera3D.new()
	camera.position = below + Vector3.UP * CAMERA_HEIGHT
	camera.rotation.x = -PI * 0.5
	viewport.add_child(camera)
	var origin := Node3D.new()
	var aim := Aim.new()
	origin.add_child(aim)
	viewport.add_child(origin)

	_put_mouse(viewport, Vector2(VIEW_SIZE) * 0.5)
	await _steps(2)
	assert_almost_eq(aim.aim_point, below, TOLERANCE * 10.0, "the middle of the screen is the ground straight below the camera")
	assert_almost_eq(aim.aim_dir, below.normalized(), TOLERANCE * 10.0, "and the direction leads there")

	# The camera looks straight down with -Z up the screen, so the top edge of the picture
	# lies half the vertical field of view further along -Z.
	_put_mouse(viewport, Vector2(VIEW_SIZE.x * 0.5, 0.0))
	await _steps(2)
	var reach := CAMERA_HEIGHT * tan(deg_to_rad(camera.fov * 0.5))
	assert_almost_eq(aim.aim_point, below + Vector3.FORWARD * reach, Vector3.ONE * 0.01, "the top edge of the screen is that much further up")


## Hands [param viewport] a mouse motion to [param at], in its own pixels.
func _put_mouse(viewport: SubViewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)


func _steps(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
