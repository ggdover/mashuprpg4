extends GutTest
## The gray-box kit sizes its boxes from the size class, keeps collision in step with the
## mesh, and gives every instance its own mesh.

const BOX_ACTOR: PackedScene = preload("res://graybox/box_actor.tscn")
const BOX_PROP: PackedScene = preload("res://graybox/box_prop.tscn")


func test_actor_body_takes_the_size_class_dimensions() -> void:
	_assert_body_size(Graybox.SizeClass.PLAYER)
	_assert_body_size(Graybox.SizeClass.SMALL)
	_assert_body_size(Graybox.SizeClass.MEDIUM)
	_assert_body_size(Graybox.SizeClass.LARGE)
	_assert_body_size(Graybox.SizeClass.BOSS)
	_assert_body_size(Graybox.SizeClass.TROLL)


func test_actor_nose_sits_on_the_front() -> void:
	var actor := _make_actor(Graybox.SizeClass.PLAYER)
	assert_lt(actor.nose.position.z, -actor.get_body_size().z * 0.5, "nose is in front of the body, on -Z")
	assert_eq(actor.nose.position.x, 0.0, "nose is centred")


func test_actor_instances_do_not_share_meshes() -> void:
	var small := _make_actor(Graybox.SizeClass.SMALL)
	_make_actor(Graybox.SizeClass.TROLL)
	assert_eq((small.body.mesh as BoxMesh).size, Graybox.size_of(Graybox.SizeClass.SMALL), "small keeps its size after a troll is built")


func test_actor_material_reaches_body_and_nose() -> void:
	var actor := _make_actor(Graybox.SizeClass.MEDIUM)
	actor.material = Graybox.MAT_FROST
	assert_eq((actor.body.mesh as BoxMesh).material, Graybox.MAT_FROST)
	assert_eq((actor.nose.mesh as BoxMesh).material, Graybox.MAT_FROST)


func test_prop_mesh_and_collision_follow_size() -> void:
	var prop: BoxProp = BOX_PROP.instantiate()
	prop.size = Vector3(4.0, 2.0, 0.5)
	add_child_autofree(prop)
	assert_eq((prop.mesh_instance.mesh as BoxMesh).size, Vector3(4.0, 2.0, 0.5))
	assert_eq((prop.collision_shape.shape as BoxShape3D).size, Vector3(4.0, 2.0, 0.5))
	assert_eq(prop.collision_shape.position.y, 1.0, "collision box stands on the origin")
	assert_eq(prop.collision_layer, 1, "props sit on the world layer")


func test_make_box_builds_a_box_mesh_with_the_material() -> void:
	var box := Graybox.make_box(Vector3(0.3, 0.3, 0.3), Graybox.MAT_RARITY_RARE)
	autofree(box)
	assert_eq((box.mesh as BoxMesh).size, Vector3(0.3, 0.3, 0.3))
	assert_eq((box.mesh as BoxMesh).material, Graybox.MAT_RARITY_RARE)


func _make_actor(size_class: Graybox.SizeClass) -> BoxActor:
	var actor: BoxActor = BOX_ACTOR.instantiate()
	actor.size_class = size_class
	add_child_autofree(actor)
	return actor


func _assert_body_size(size_class: Graybox.SizeClass) -> void:
	var actor := _make_actor(size_class)
	var expected := Graybox.size_of(size_class)
	assert_eq((actor.body.mesh as BoxMesh).size, expected, "body size for class %d" % size_class)
	assert_eq(actor.body.position.y, expected.y * 0.5, "body is centred above the feet")
