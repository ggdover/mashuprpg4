extends GutTest
## The gray-box kit sizes its boxes from the size class, keeps collision in step with the
## mesh, and gives every instance and every duplicate its own mesh and shape.

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


func test_duplicated_actor_does_not_share_meshes_with_the_original() -> void:
	var original := _make_actor(Graybox.SizeClass.SMALL)
	var small := Graybox.size_of(Graybox.SizeClass.SMALL)
	var small_nose := Vector3.ONE * (small.x * Graybox.NOSE_FRACTION)
	var copy := original.duplicate() as BoxActor
	add_child_autofree(copy)
	copy.size_class = Graybox.SizeClass.TROLL
	copy.material = Graybox.MAT_FROST
	assert_eq((original.body.mesh as BoxMesh).size, small, "the original body keeps its size")
	assert_eq((original.nose.mesh as BoxMesh).size, small_nose, "the original nose keeps its size")
	assert_eq((original.body.mesh as BoxMesh).material, Graybox.MAT_GRAY, "the original body keeps its material")
	assert_eq((original.nose.mesh as BoxMesh).material, Graybox.MAT_GRAY, "the original nose keeps its material")
	assert_eq((copy.body.mesh as BoxMesh).size, Graybox.size_of(Graybox.SizeClass.TROLL), "the copy took the new size")
	assert_eq((copy.body.mesh as BoxMesh).material, Graybox.MAT_FROST, "the copy took the new material")
	original.size_class = Graybox.SizeClass.BOSS
	assert_eq((copy.body.mesh as BoxMesh).size, Graybox.size_of(Graybox.SizeClass.TROLL), "resizing the original leaves the copy alone")


func test_actor_duplicated_without_instantiation_does_not_share_meshes() -> void:
	var original := _make_actor(Graybox.SizeClass.SMALL)
	var copy := original.duplicate(Node.DUPLICATE_SCRIPTS) as BoxActor
	add_child_autofree(copy)
	copy.size_class = Graybox.SizeClass.TROLL
	assert_eq((original.body.mesh as BoxMesh).size, Graybox.size_of(Graybox.SizeClass.SMALL), "the original body keeps its size")
	assert_eq((copy.body.mesh as BoxMesh).size, Graybox.size_of(Graybox.SizeClass.TROLL), "the copy took the new size")


func test_prop_mesh_and_collision_follow_size() -> void:
	var prop: BoxProp = BOX_PROP.instantiate()
	prop.size = Vector3(4.0, 2.0, 0.5)
	add_child_autofree(prop)
	assert_eq((prop.mesh_instance.mesh as BoxMesh).size, Vector3(4.0, 2.0, 0.5))
	assert_eq((prop.collision_shape.shape as BoxShape3D).size, Vector3(4.0, 2.0, 0.5))
	assert_eq(prop.collision_shape.position.y, 1.0, "collision box stands on the origin")
	assert_eq(prop.collision_layer, 1, "props sit on the world layer")


func test_duplicated_prop_does_not_share_mesh_or_shape_with_the_original() -> void:
	var original_size := Vector3(2.0, 3.0, 4.0)
	var original: BoxProp = BOX_PROP.instantiate()
	original.size = original_size
	add_child_autofree(original)

	var resized_later := original.duplicate() as BoxProp
	add_child_autofree(resized_later)
	resized_later.size = Vector3(9.0, 9.0, 9.0)
	resized_later.material = Graybox.MAT_FROST

	var resized_first := original.duplicate() as BoxProp
	resized_first.size = Vector3(7.0, 7.0, 7.0)
	add_child_autofree(resized_first)

	assert_eq((original.mesh_instance.mesh as BoxMesh).size, original_size, "the original mesh keeps its size")
	assert_eq((original.collision_shape.shape as BoxShape3D).size, original_size, "the original collision keeps its size")
	assert_eq((original.mesh_instance.mesh as BoxMesh).material, Graybox.MAT_GRAY, "the original keeps its material")
	assert_eq((resized_later.mesh_instance.mesh as BoxMesh).size, Vector3(9.0, 9.0, 9.0), "a copy resized in the tree took its size")
	assert_eq((resized_later.collision_shape.shape as BoxShape3D).size, Vector3(9.0, 9.0, 9.0), "and so did its collision")
	assert_eq((resized_later.mesh_instance.mesh as BoxMesh).material, Graybox.MAT_FROST, "and it took its material")
	assert_eq((resized_first.mesh_instance.mesh as BoxMesh).size, Vector3(7.0, 7.0, 7.0), "a copy resized before it entered the tree took its size")
	assert_eq((resized_first.collision_shape.shape as BoxShape3D).size, Vector3(7.0, 7.0, 7.0), "and so did its collision")


func test_make_box_builds_a_box_mesh_with_the_material() -> void:
	var box := Graybox.make_box(Vector3(0.3, 0.3, 0.3), Graybox.MAT_RARITY_RARE)
	autofree(box)
	assert_eq((box.mesh as BoxMesh).size, Vector3(0.3, 0.3, 0.3))
	assert_eq((box.mesh as BoxMesh).material, Graybox.MAT_RARITY_RARE)


func test_no_node_is_an_edited_scene_root_while_the_game_runs() -> void:
	var actor := _make_actor(Graybox.SizeClass.MEDIUM)
	assert_false(Graybox.is_edited_scene_root(actor), "only the editor has an edited scene")


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
