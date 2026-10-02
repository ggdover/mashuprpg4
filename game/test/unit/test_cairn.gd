extends GutTest
## The cairn: what it shows lit and unlit, the beacon the fog cannot hide, lighting it with
## tallow, the announcement, and how it is remembered in GameState.zone_state and comes back
## lit when its zone is entered again.

const CAIRN: PackedScene = preload("res://world/cairn.tscn")
## The collision layer the player's interactor looks on (project settings, layer 9).
const INTERACTABLE_LAYER := 9
## A beacon counts as tall and thin from this many times its width in height.
const TALL := 10.0


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _reset() -> void:
	GameState.zone_state.clear()
	GameState.current_zone = &""
	WorldState.state = WorldState.State.DAY


func test_an_unlit_cairn_is_dark_and_no_safe_point() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	assert_false(cairn.lit)
	assert_false(cairn.fire.visible, "no fire")
	assert_false(cairn.beacon.visible, "no beacon")
	assert_false(cairn.is_safe_point, "no place to respawn at")


func test_a_lit_cairn_burns_and_is_a_safe_point() -> void:
	var cairn := _make_cairn(&"Cairn_1", true)
	assert_true(cairn.fire.visible, "the fire burns")
	assert_true(cairn.beacon.visible, "the beacon stands")
	assert_true(cairn.is_safe_point)


func test_fire_and_beacon_are_ember() -> void:
	var cairn := _make_cairn(&"Cairn_1", true)
	var material := cairn.beacon.material_override as StandardMaterial3D
	assert_eq(cairn.fire.light_color, Palette.FOG["ember"], "the only warm light in fog")
	assert_eq(material.albedo_color, Palette.FOG["ember"])


func test_the_beacon_is_tall_and_thin_and_the_fog_does_not_hide_it() -> void:
	var cairn := _make_cairn(&"Cairn_1", true)
	var material := cairn.beacon.material_override as StandardMaterial3D
	var size := (cairn.beacon.mesh as BoxMesh).size
	assert_gt(size.y, size.x * TALL, "tall and thin")
	assert_true(material.disable_fog, "its material takes no fog, however far away it stands")
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "and glows by itself, whatever light there is")


func test_in_fog_the_beacon_of_a_lit_cairn_shows_and_an_unlit_cairn_has_none() -> void:
	WorldState.state = WorldState.State.FOG
	var lit := _make_cairn(&"Cairn_1", true)
	var unlit := _make_cairn(&"Cairn_2", false)
	assert_true(lit.beacon.is_visible_in_tree())
	assert_false(unlit.beacon.is_visible_in_tree())


func test_interact_without_tallow_leaves_the_cairn_unlit() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	watch_signals(EventBus)
	assert_eq(cairn.interact(0), 0, "nothing is burnt")
	assert_false(cairn.lit)
	assert_signal_not_emitted(EventBus, "cairn_lit")
	assert_false(GameState.has_zone_state(&"", Cairn.ZONE_STATE_KEY, &"Cairn_1"), "and nothing is remembered")


func test_interact_with_tallow_lights_the_cairn_and_says_what_it_burnt() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	watch_signals(EventBus)
	assert_eq(cairn.interact(3), 1, "one of the three tallow is burnt")
	assert_true(cairn.lit)
	assert_true(cairn.fire.visible)
	assert_true(cairn.is_safe_point)
	assert_signal_emitted_with_parameters(EventBus, "cairn_lit", [cairn])
	assert_true(GameState.has_zone_state(&"", Cairn.ZONE_STATE_KEY, &"Cairn_1"), "the zone remembers it")


func test_interact_on_a_lit_cairn_burns_nothing() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	watch_signals(EventBus)
	cairn.interact(5)
	assert_eq(cairn.interact(5), 0, "it burns already")
	assert_signal_emit_count(EventBus, "cairn_lit", 1)


func test_a_dearer_cairn_needs_all_of_its_tallow() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	cairn.tallow_cost = 2
	assert_eq(cairn.interact(1), 0, "one is not enough")
	assert_false(cairn.lit)
	assert_eq(cairn.interact(2), 2)
	assert_true(cairn.lit)


func test_the_prompt_names_the_cost_and_is_empty_once_lit() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	assert_string_contains(cairn.get_prompt(), "Light the cairn")
	assert_string_contains(cairn.get_prompt(), "1 tallow")
	cairn.light()
	assert_eq(cairn.get_prompt(), "")


func test_a_cairn_lit_on_an_earlier_visit_comes_back_lit_without_saying_so() -> void:
	GameState.current_zone = &"crossroads"
	var first := _make_cairn(&"Cairn_1", false)
	first.light()
	first.free()
	watch_signals(EventBus)
	var again := _make_cairn(&"Cairn_1", false)
	assert_true(again.lit, "the zone remembered it")
	assert_true(again.fire.visible)
	assert_signal_not_emitted(EventBus, "cairn_lit", "it was lit long ago: no quest counts it twice")
	var other := _make_cairn(&"Cairn_2", false)
	assert_false(other.lit, "its neighbour was never lit")


func test_a_cairn_is_remembered_in_its_own_zone_only() -> void:
	GameState.current_zone = &"crossroads"
	var first := _make_cairn(&"Cairn_1", false)
	first.light()
	first.free()
	GameState.current_zone = &"frost_line"
	var namesake := _make_cairn(&"Cairn_1", false)
	assert_eq(namesake.cairn_id, &"Cairn_1")
	assert_false(namesake.lit, "a cairn of the same name in another zone")


func test_the_zone_announcement_puts_a_cairn_right_that_became_ready_too_early() -> void:
	# The zone manager may name the new zone only after the zone's scene is in the tree.
	GameState.add_zone_state(&"crossroads", Cairn.ZONE_STATE_KEY, &"Cairn_1")
	GameState.add_zone_state(&"frost_line", Cairn.ZONE_STATE_KEY, &"Cairn_2")
	GameState.current_zone = &"frost_line"
	var lit_here := _make_cairn(&"Cairn_1", false)
	var lit_there := _make_cairn(&"Cairn_2", false)
	assert_false(lit_here.lit, "read under the zone the player just left")
	assert_true(lit_there.lit)
	GameState.current_zone = &"crossroads"
	EventBus.zone_entered.emit(&"crossroads")
	assert_true(lit_here.lit, "the announcement names the right zone")
	assert_false(lit_there.lit, "and what the old zone remembered does not stick")


func test_a_cairn_lit_in_its_scene_stays_lit() -> void:
	var cairn := _make_cairn(&"Cairn_1", true)
	EventBus.zone_entered.emit(&"crossroads")
	assert_true(cairn.lit, "the scene says lit; no memory is needed")


func test_cairn_id_is_the_node_name_unless_one_is_given() -> void:
	var named := _make_cairn(&"Cairn_Crossroads", false)
	assert_eq(named.cairn_id, &"Cairn_Crossroads")
	var given: Cairn = CAIRN.instantiate()
	given.cairn_id = &"first_cairn"
	add_child_autofree(given)
	assert_eq(given.cairn_id, &"first_cairn")


func test_the_interactor_finds_the_cairn_on_the_interactable_layer() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	assert_eq(cairn.interact_area.collision_layer, 1 << (INTERACTABLE_LAYER - 1), "layer 9 and no other")
	assert_eq(cairn.interact_area.collision_mask, 0, "it looks for nothing itself")
	assert_eq(cairn.interact_area.find_children("*", "CollisionShape3D", true, false).size(), 1)


func test_the_stones_stand_in_the_way() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	var stones := cairn.find_children("*", "StaticBody3D", true, false)
	assert_eq(stones.size(), 3, "a stack of three boxes")
	for stone: StaticBody3D in stones:
		assert_eq(stone.collision_layer, 1, "on the world layer")


func test_cairns_are_in_the_group_the_world_state_searches() -> void:
	var cairn := _make_cairn(&"Cairn_1", false)
	assert_true(cairn.is_in_group(WorldState.CAIRN_GROUP))


func _make_cairn(node_name: StringName, lit: bool) -> Cairn:
	var cairn: Cairn = CAIRN.instantiate()
	cairn.name = node_name
	cairn.lit = lit
	add_child_autofree(cairn)
	return cairn


func test_a_lit_cairn_is_still_remembered_after_a_trip_through_json() -> void:
	# J19 saves GameState.zone_state as JSON, which hands every id back as a plain String.
	GameState.current_zone = &"crossroads"
	var first := _make_cairn(&"Cairn_1", false)
	first.light()
	first.free()
	var saved := JSON.stringify(GameState.zone_state)
	GameState.zone_state = JSON.parse_string(saved)
	assert_true(GameState.has_zone_state(&"crossroads", Cairn.ZONE_STATE_KEY, &"Cairn_1"), "the loaded state answers for the same ids")
	assert_true(_make_cairn(&"Cairn_1", false).lit, "and the cairn comes back lit")
	GameState.add_zone_state(&"crossroads", Cairn.ZONE_STATE_KEY, &"Cairn_1")
	var lists: Dictionary = GameState.zone_state["crossroads"]
	var remembered: Array = lists["cairns_lit"]
	assert_eq(remembered.size(), 1, "remembering it again adds no second entry")
