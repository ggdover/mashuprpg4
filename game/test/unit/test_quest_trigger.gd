extends GutTest
## QuestTrigger: the volume that announces marker_reached on the EventBus when the player's
## body enters it. The player is put into the volume and out of it on real physics frames.

const TRIGGER: PackedScene = preload("res://quests/quest_trigger.tscn")
const PLAYER: PackedScene = preload("res://player/player.tscn")
const GROUND: PackedScene = preload("res://graybox/ground_plane.tscn")
const MARKER := &"test_oak"
## Physics frames a trigger gets to notice that a body came or went.
const NOTICE_FRAMES := 4
## A spot on the ground well outside every trigger of these tests.
const AWAY := Vector3(20.0, 0.0, 20.0)
const TOLERANCE := 0.0001

var _trigger: QuestTrigger
var _player: Player


func before_each() -> void:
	add_child_autofree(GROUND.instantiate())
	_trigger = TRIGGER.instantiate()
	_trigger.marker_id = MARKER
	add_child_autofree(_trigger)
	_player = PLAYER.instantiate()
	add_child_autofree(_player)
	await _put_player_at(AWAY)


func test_the_trigger_watches_the_player_layer_and_sits_on_none() -> void:
	assert_eq(_trigger.collision_mask, 2, "it sees layer 2, player_body")
	assert_eq(_trigger.collision_layer, 0, "and nothing can run into it")


func test_the_player_walking_in_is_announced_once() -> void:
	watch_signals(EventBus)
	await _put_player_at(_trigger.global_position)
	assert_signal_emitted_with_parameters(EventBus, "marker_reached", [MARKER])
	await _steps(NOTICE_FRAMES)
	assert_signal_emit_count(EventBus, "marker_reached", 1, "once for the entry, not once a frame while the player stands in it")


func test_every_entry_is_announced() -> void:
	watch_signals(EventBus)
	await _put_player_at(_trigger.global_position)
	await _put_player_at(AWAY)
	assert_signal_emit_count(EventBus, "marker_reached", 1, "leaving announces nothing")
	await _put_player_at(_trigger.global_position)
	assert_signal_emit_count(EventBus, "marker_reached", 2, "a repeatable quest can be started here again")


func test_a_body_that_is_not_the_player_is_not_announced() -> void:
	var body := CharacterBody3D.new()
	body.collision_layer = _player.collision_layer
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	body.add_child(collision)
	add_child_autofree(body)
	watch_signals(EventBus)
	body.global_position = _trigger.global_position + Vector3.UP
	await _steps(NOTICE_FRAMES)
	assert_true(_trigger.overlaps_body(body), "the body is in the volume")
	assert_signal_not_emitted(EventBus, "marker_reached")


func test_a_trigger_without_a_marker_id_announces_nothing() -> void:
	_trigger.marker_id = &""
	watch_signals(EventBus)
	await _put_player_at(_trigger.global_position)
	assert_true(_trigger.overlaps_body(_player), "the player is in the volume")
	assert_signal_not_emitted(EventBus, "marker_reached")


func test_the_size_sets_the_volume() -> void:
	var beside := _trigger.global_position + Vector3(2.5, 0.0, 0.0)
	watch_signals(EventBus)
	await _put_player_at(beside)
	assert_signal_not_emitted(EventBus, "marker_reached", "2.5 m to the side is outside a volume 2 m wide")
	await _put_player_at(AWAY)
	_trigger.size = Vector3(6.0, 2.0, 2.0)
	var collision: CollisionShape3D = _trigger.get_node("Shape")
	assert_almost_eq((collision.shape as BoxShape3D).size, Vector3(6.0, 2.0, 2.0), Vector3.ONE * TOLERANCE)
	assert_almost_eq(collision.position, Vector3(0.0, 1.0, 0.0), Vector3.ONE * TOLERANCE, "the volume stands on the trigger's origin")
	await _put_player_at(beside)
	assert_signal_emit_count(EventBus, "marker_reached", 1, "and inside one 6 m wide")


func test_a_duplicated_trigger_announces_its_own_marker_once() -> void:
	var copy: QuestTrigger = _trigger.duplicate()
	copy.marker_id = &"test_birch"
	add_child_autofree(copy)
	copy.global_position = Vector3(-10.0, 0.0, -10.0)
	await _steps(NOTICE_FRAMES)
	watch_signals(EventBus)
	await _put_player_at(copy.global_position)
	assert_signal_emit_count(EventBus, "marker_reached", 1, "the copy speaks for itself, and the original stays silent")
	assert_signal_emitted_with_parameters(EventBus, "marker_reached", [&"test_birch"])


func test_each_trigger_owns_its_shape() -> void:
	var other: QuestTrigger = TRIGGER.instantiate()
	add_child_autofree(other)
	var copy: QuestTrigger = _trigger.duplicate()
	add_child_autofree(copy)
	_trigger.size = Vector3(4.0, 3.0, 5.0)
	for untouched: QuestTrigger in [other, copy]:
		var shape := (untouched.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
		assert_almost_eq(shape.size, Vector3(2.0, 2.0, 2.0), Vector3.ONE * TOLERANCE, "resizing one trigger leaves the others alone")


## Puts the player at [param place] and gives the trigger the frames it takes to notice.
func _put_player_at(place: Vector3) -> void:
	_player.global_position = place
	_player.reset_physics_interpolation()
	await _steps(NOTICE_FRAMES)


func _steps(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
