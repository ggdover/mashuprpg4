extends GutTest
## The autoload skeletons: flags announce once, world state announces changes, the save stub says no.


func before_each() -> void:
	GameState.flags.clear()
	WorldState.state = WorldState.State.DAY


func test_set_flag_announces_once_and_has_flag_reads_it() -> void:
	watch_signals(EventBus)
	GameState.set_flag(&"met_old_lady")
	GameState.set_flag(&"met_old_lady")
	assert_true(GameState.has_flag(&"met_old_lady"))
	assert_false(GameState.has_flag(&"met_headman"))
	assert_signal_emit_count(EventBus, "flag_set", 1)
	assert_signal_emitted_with_parameters(EventBus, "flag_set", [&"met_old_lady"])


func test_world_state_announces_changes_only() -> void:
	watch_signals(EventBus)
	WorldState.state = WorldState.State.FOG
	WorldState.state = WorldState.State.FOG
	assert_eq(WorldState.state, WorldState.State.FOG)
	assert_signal_emit_count(EventBus, "world_state_changed", 1)
	assert_signal_emitted_with_parameters(EventBus, "world_state_changed", [WorldState.State.FOG])


func test_world_state_accepts_a_plain_int_assignment() -> void:
	watch_signals(EventBus)
	var saved: Variant = 1
	WorldState.state = saved
	assert_eq(WorldState.state, WorldState.State.FOG, "an int from a save file lands in the enum property")
	assert_signal_emit_count(EventBus, "world_state_changed", 1)


func test_world_state_accepts_a_dynamic_set() -> void:
	watch_signals(EventBus)
	WorldState.set("state", WorldState.State.FOG)
	assert_eq(WorldState.state, WorldState.State.FOG, "Object.set reaches the setter")
	assert_signal_emit_count(EventBus, "world_state_changed", 1)


func test_save_system_is_a_stub() -> void:
	assert_false(SaveSystem.save())
	assert_false(SaveSystem.load())


func test_game_state_defaults() -> void:
	assert_eq(GameState.phase, 1)
	assert_eq(GameState.current_zone, &"")
