extends GutTest
## J11's test scene as a whole: the environment controller owns the arena's environment and
## sun, the day and the fog signpost stand on one post and swap, the landmark hides and the
## fog path appears, one cairn is lit and E lights the other, the player's light follows the
## state and the lantern, and every key does what the overlay says.
##
## The scene runs in a viewport of its own, which the tests send their key presses to.

const TEST_SCENE: PackedScene = preload("res://test/test_world_state.tscn")
const DAY := WorldState.State.DAY
const FOG := WorldState.State.FOG
const TOLERANCE := 0.0001

var _viewport: SubViewport
var _scene: WorldStateTestScene
var _player: Player
var _controller: EnvironmentController
var _label: Label


func before_each() -> void:
	_reset()
	_viewport = SubViewport.new()
	add_child_autofree(_viewport)
	_scene = TEST_SCENE.instantiate()
	_viewport.add_child(_scene)
	_player = _scene.get_node("Player")
	_controller = _scene.get_node("EnvironmentController")
	_label = _scene.get_node("Overlay/Label")
	await wait_process_frames(2)


func after_each() -> void:
	_reset()


func _reset() -> void:
	WorldState.fog_scene_active = false
	WorldState.zone_kind = WorldState.ZoneKind.OPEN
	WorldState.state = DAY
	GameState.phase = 1
	GameState.flags.erase(PlayerLight.LANTERN_FLAG)
	GameState.zone_state.clear()


func test_the_controller_owns_the_arena_environment_and_sun() -> void:
	assert_eq(_controller.world_environment, _scene.get_node("Arena/WorldEnvironment"))
	assert_eq(_controller.sun, _scene.get_node("Arena/Sun"))
	assert_eq(_scene.find_children("*", "WorldEnvironment", true, false).size(), 1, "one environment in the scene")
	assert_eq(_scene.find_children("*", "DirectionalLight3D", true, false).size(), 1, "and one sun")
	assert_eq(_controller.world_environment.environment.ambient_light_energy, 0.5, "showing the day preset")


func test_day_and_fog_signposts_stand_on_one_post_and_swap() -> void:
	var day_sign: Signpost = _scene.get_node("StateNodes/SignDay")
	var fog_sign: Signpost = _scene.get_node("StateNodes/SignFog")
	assert_eq(day_sign.global_position, fog_sign.global_position, "the same post")
	assert_eq(day_sign.text, "Sjön")
	assert_eq(fog_sign.text, "Norr")
	assert_true(day_sign.visible, "by day the day sign")
	assert_false(fog_sign.visible)
	_press(WorldStateTestScene.KEY_FOG)
	assert_false(day_sign.visible, "in fog the fog sign")
	assert_true(fog_sign.visible)


func test_the_landmark_hides_and_the_fog_path_appears() -> void:
	var landmark: BoxProp = _scene.get_node("StateNodes/Landmark")
	var path: Node3D = _scene.get_node("StateNodes/FogPath")
	var slab: BoxProp = _scene.get_node("StateNodes/FogPath/Slab1")
	var dead_end: Signpost = _scene.get_node("StateNodes/FogPath/SignDeadEnd")
	assert_true(landmark.visible, "by day the landmark stands")
	assert_false(landmark.collision_shape.disabled)
	assert_false(path.visible, "and there is no path")
	assert_true(slab.collision_shape.disabled)
	_press(WorldStateTestScene.KEY_FOG)
	await wait_process_frames(2)
	assert_false(landmark.visible, "the fog swallows the landmark")
	assert_true(landmark.collision_shape.disabled, "and it can be walked through")
	assert_true(path.visible, "and lays out the path")
	assert_false(slab.collision_shape.disabled)
	assert_true(dead_end.is_visible_in_tree(), "to the sign at its dead end")
	assert_eq(dead_end.text, "Ingen väg")


func test_one_cairn_is_lit_and_one_is_not() -> void:
	var lit: Cairn = _scene.get_node("Cairns/CairnLit")
	var unlit: Cairn = _scene.get_node("Cairns/CairnUnlit")
	assert_true(lit.lit)
	assert_false(unlit.lit)
	assert_eq(WorldState.nearest_lit_cairn(unlit.global_position), lit, "the bell would point at the lit one")
	_press(WorldStateTestScene.KEY_FOG)
	assert_true(lit.beacon.is_visible_in_tree(), "in fog its beacon stands")
	assert_false(unlit.beacon.is_visible_in_tree(), "and the unlit one has none")


func test_the_fog_keys_bring_and_end_the_fog_and_the_environment_follows() -> void:
	_controller.transition_seconds = 0.0
	_press(WorldStateTestScene.KEY_FOG)
	assert_eq(WorldState.state, FOG)
	assert_true(_controller.world_environment.environment.fog_enabled, "the arena is in fog")
	_press(WorldStateTestScene.KEY_END_FOG)
	assert_eq(WorldState.state, DAY)
	assert_false(_controller.world_environment.environment.fog_enabled, "and clear again")


func test_the_horn_sounds_at_every_fog_start() -> void:
	_press(WorldStateTestScene.KEY_FOG)
	_press(WorldStateTestScene.KEY_FOG)
	assert_eq(_scene.horn_count, 1, "once for the fog, not for the second press")
	_press(WorldStateTestScene.KEY_END_FOG)
	_press(WorldStateTestScene.KEY_FOG)
	assert_eq(_scene.horn_count, 2)


func test_the_phase_key_walks_through_the_three_phases() -> void:
	_press(WorldStateTestScene.KEY_PHASE)
	assert_eq(GameState.phase, 2)
	_press(WorldStateTestScene.KEY_PHASE)
	assert_eq(GameState.phase, 3)
	_press(WorldStateTestScene.KEY_PHASE)
	assert_eq(GameState.phase, 1)


func test_the_player_light_is_off_by_day_6_m_in_fog_and_12_m_with_the_lantern() -> void:
	var light: OmniLight3D = (_player.get_node("PlayerLight") as PlayerLight).light
	assert_false(light.visible, "off by day")
	_press(WorldStateTestScene.KEY_FOG)
	await wait_process_frames(2)
	assert_true(light.visible, "on in fog")
	assert_almost_eq(light.omni_range, 6.0, TOLERANCE)
	_press(WorldStateTestScene.KEY_LANTERN)
	await wait_process_frames(2)
	assert_almost_eq(light.omni_range, 12.0, TOLERANCE, "the lantern doubles its reach")
	_press(WorldStateTestScene.KEY_LANTERN)
	await wait_process_frames(2)
	assert_almost_eq(light.omni_range, 6.0, TOLERANCE, "the key takes the lantern away again")
	_press(WorldStateTestScene.KEY_END_FOG)
	await wait_process_frames(2)
	assert_false(light.visible, "off when the fog ends")


func test_entering_a_village_ends_the_fog_and_keeps_it_out() -> void:
	_press(WorldStateTestScene.KEY_FOG)
	_press(WorldStateTestScene.KEY_ENTER_VILLAGE)
	assert_eq(WorldState.state, DAY, "home: the fog ends")
	assert_eq(WorldState.zone_kind, WorldState.ZoneKind.VILLAGE)
	_press(WorldStateTestScene.KEY_FOG)
	assert_eq(WorldState.state, DAY, "and none starts in a village")
	_press(WorldStateTestScene.KEY_ENTER_OPEN)
	assert_eq(WorldState.zone_kind, WorldState.ZoneKind.OPEN)
	assert_eq(WorldState.state, DAY, "phase 1 rolls no fog on the way out")
	_press(WorldStateTestScene.KEY_FOG)
	assert_eq(WorldState.state, FOG, "out in the open the fog can come again")


func test_entering_a_dungeon_shows_the_cave_and_lights_the_player() -> void:
	_controller.transition_seconds = 0.0
	_press(WorldStateTestScene.KEY_ENTER_DUNGEON)
	await wait_process_frames(2)
	assert_eq(WorldState.state, DAY, "the state stays")
	assert_true(_controller.force_cave)
	assert_eq(_controller.world_environment.environment.background_mode, Environment.BG_COLOR, "the cave preset: no sky")
	assert_false(_controller.sun.visible, "no sun")
	assert_true((_player.get_node("PlayerLight") as PlayerLight).light.visible, "the player's light burns")
	_press(WorldStateTestScene.KEY_ENTER_OPEN)
	await wait_process_frames(2)
	assert_false(_controller.force_cave)
	assert_true(_controller.sun.visible, "back under the sun")


func test_e_lights_the_cairn_the_player_stands_at() -> void:
	var unlit: Cairn = _scene.get_node("Cairns/CairnUnlit")
	watch_signals(EventBus)
	_press(KEY_E)
	assert_false(unlit.lit, "too far away from the spawn")
	_player.global_position = unlit.global_position + Vector3(1.5, 0.0, 0.0)
	_press(KEY_E)
	assert_true(unlit.lit, "within reach, with tallow")
	assert_eq(_scene.tallow, 0, "the tallow is burnt")
	assert_signal_emitted_with_parameters(EventBus, "cairn_lit", [unlit])


func test_the_overlay_reports_the_world_state() -> void:
	_press(WorldStateTestScene.KEY_FOG)
	_press(WorldStateTestScene.KEY_PHASE)
	await wait_process_frames(2)
	for expected: String in ["state FOG", "zone kind OPEN", "phase 2", "10 %", "player light 6 m", "horn sounded 1 times", "tallow 1", "nearest lit cairn"]:
		assert_string_contains(_label.text, expected)


## Presses a key in the scene's viewport, the way the keyboard would.
func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	_viewport.push_input(event)
