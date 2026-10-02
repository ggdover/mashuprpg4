extends GutTest
## StateVisibility shows its parent in the states it is told to and hides it in the others,
## takes the collision of what it hides along (the parent's own shapes, shapes further down
## and shapes under a StateVisibility of their own), and does so when it becomes ready and
## at every change of state. The signpost scene carries one.

const BOX_PROP: PackedScene = preload("res://graybox/box_prop.tscn")
const SIGNPOST: PackedScene = preload("res://world/signpost.tscn")
const DAY := WorldState.State.DAY
const FOG := WorldState.State.FOG


func before_each() -> void:
	WorldState.state = DAY


func after_each() -> void:
	WorldState.state = DAY


func test_a_day_only_thing_is_gone_in_fog() -> void:
	var prop := _make_prop(true, false)
	add_child_autofree(prop)
	await _settle()
	assert_true(prop.visible, "by day it is there")
	assert_false(prop.collision_shape.disabled, "and solid")
	WorldState.state = FOG
	await _settle()
	assert_false(prop.visible, "in fog it is hidden")
	assert_true(prop.collision_shape.disabled, "and what is hidden does not collide")
	WorldState.state = DAY
	await _settle()
	assert_true(prop.visible, "back by day")
	assert_false(prop.collision_shape.disabled, "and solid again")


func test_a_fog_only_thing_appears_in_fog() -> void:
	var prop := _make_prop(false, true)
	add_child_autofree(prop)
	await _settle()
	assert_false(prop.visible, "by day it is not there")
	assert_true(prop.collision_shape.disabled, "and can be walked through")
	WorldState.state = FOG
	await _settle()
	assert_true(prop.visible, "the fog brings it")
	assert_false(prop.collision_shape.disabled, "solid")


func test_a_thing_for_both_states_stays_and_one_for_neither_never_shows() -> void:
	var always := _make_prop(true, true)
	var never := _make_prop(false, false)
	add_child_autofree(always)
	add_child_autofree(never)
	for state: WorldState.State in [DAY, FOG]:
		WorldState.state = state
		await _settle()
		assert_true(always.visible, "both flags set, state %d" % state)
		assert_false(always.collision_shape.disabled)
		assert_false(never.visible, "no flag set, state %d" % state)
		assert_true(never.collision_shape.disabled)


func test_it_takes_the_state_it_becomes_ready_in() -> void:
	WorldState.state = FOG
	var prop := _make_prop(true, false)
	add_child_autofree(prop)
	await _settle()
	assert_false(prop.visible, "a zone loaded in fog starts without its day things")
	assert_true(prop.collision_shape.disabled)


func test_one_node_on_a_group_covers_every_shape_under_it() -> void:
	var group := Node3D.new()
	var first: BoxProp = BOX_PROP.instantiate()
	var second: BoxProp = BOX_PROP.instantiate()
	group.add_child(first)
	group.add_child(second)
	group.add_child(_make_visibility(false, true))
	add_child_autofree(group)
	await _settle()
	assert_false(group.visible, "the fog path is not there by day")
	assert_true(first.collision_shape.disabled, "and none of its boxes collides")
	assert_true(second.collision_shape.disabled)
	WorldState.state = FOG
	await _settle()
	assert_true(group.visible)
	assert_false(first.collision_shape.disabled, "in fog all of them do")
	assert_false(second.collision_shape.disabled)


func test_a_thing_inside_a_hidden_group_does_not_collide_whatever_its_own_flags_say() -> void:
	var group := Node3D.new()
	var day_thing := _make_prop(true, false)
	var both_thing := _make_prop(true, true)
	group.add_child(day_thing)
	group.add_child(both_thing)
	group.add_child(_make_visibility(false, true))
	add_child_autofree(group)
	await _settle()
	assert_true(day_thing.collision_shape.disabled, "by day the group is hidden, and its day thing with it")
	assert_true(both_thing.collision_shape.disabled)
	WorldState.state = FOG
	await _settle()
	assert_true(day_thing.collision_shape.disabled, "in fog the group shows, but the day thing in it does not")
	assert_false(both_thing.collision_shape.disabled, "the thing for both states is solid")


func test_changing_a_flag_while_the_game_runs_applies_it() -> void:
	var prop := _make_prop(true, true)
	add_child_autofree(prop)
	var visibility: StateVisibility = prop.get_node("StateVisibility")
	visibility.day = false
	await _settle()
	assert_false(prop.visible, "no longer a day thing")
	assert_true(prop.collision_shape.disabled)


func test_is_shown_in_reads_the_flag_of_the_state() -> void:
	var visibility := _make_visibility(true, false)
	autofree(visibility)
	assert_true(visibility.is_shown_in(DAY))
	assert_false(visibility.is_shown_in(FOG))


func test_signpost_shows_its_text_above_the_post() -> void:
	var signpost := _make_signpost("Sjön", true, true)
	assert_eq(signpost.label.text, "Sjön")
	assert_eq(signpost.label.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "the text turns to the camera")
	var post: BoxProp = signpost.get_node("Post")
	assert_gt(signpost.label.position.y, post.size.y, "and stands above the post")
	assert_eq(signpost.label.modulate, Palette.DAY["text"], "in the day's text colour")
	signpost.text = "Berget"
	assert_eq(signpost.label.text, "Berget", "a new text shows at once")


func test_a_fog_signpost_is_written_in_the_fog_text_colour() -> void:
	var signpost := _make_signpost("Frost", false, true)
	assert_eq(signpost.label.modulate, Palette.FOG["text"])


func test_day_and_fog_signposts_on_one_spot_swap_with_the_state() -> void:
	var day_sign := _make_signpost("Sjön", true, false)
	var fog_sign := _make_signpost("Norr", false, true)
	var day_post: BoxProp = day_sign.get_node("Post")
	var fog_post: BoxProp = fog_sign.get_node("Post")
	await _settle()
	assert_true(day_sign.visible, "by day the day sign stands")
	assert_false(fog_sign.visible)
	assert_false(day_post.collision_shape.disabled)
	assert_true(fog_post.collision_shape.disabled, "and the hidden post is not in the way")
	WorldState.state = FOG
	await _settle()
	assert_false(day_sign.visible, "in fog the fog sign has taken its place")
	assert_true(fog_sign.visible)
	assert_true(day_post.collision_shape.disabled)
	assert_false(fog_post.collision_shape.disabled)


## A box prop that carries a StateVisibility with the two flags. Not yet in the tree.
func _make_prop(day: bool, fog: bool) -> BoxProp:
	var prop: BoxProp = BOX_PROP.instantiate()
	prop.add_child(_make_visibility(day, fog))
	return prop


func _make_visibility(day: bool, fog: bool) -> StateVisibility:
	var visibility := StateVisibility.new()
	visibility.name = &"StateVisibility"
	visibility.day = day
	visibility.fog = fog
	return visibility


func _make_signpost(text: String, day: bool, fog: bool) -> Signpost:
	var signpost: Signpost = SIGNPOST.instantiate()
	signpost.text = text
	signpost.day = day
	signpost.fog = fog
	add_child_autofree(signpost)
	return signpost


## Collision shapes are switched at the end of the frame; this waits for it.
func _settle() -> void:
	await wait_process_frames(2)
