extends GutTest
## WorldState's fog triggers: request_fog and end_fog with their signals and the horn, what
## entering a village, an open zone and a dungeon does, the fog chance of each story phase,
## the rule against random fog twice in a row in one zone, fog_scene_active, and the search
## for the nearest lit cairn.
##
## Every test enters zones under ids of its own: WorldState remembers which zones the fog
## last rolled into, and an id shared between tests would carry that over.

const CAIRN: PackedScene = preload("res://world/cairn.tscn")
const VILLAGE := WorldState.ZoneKind.VILLAGE
const OPEN := WorldState.ZoneKind.OPEN
const DUNGEON := WorldState.ZoneKind.DUNGEON
const DAY := WorldState.State.DAY
const FOG := WorldState.State.FOG
## Seeds the fog roll, so that every run of the tests rolls the same numbers.
const SEED := 20261002
## Zone entries the chance tests make per phase.
const ROLLS := 10000
## How far the measured share of entries that brought fog may lie from the chance. Three
## standard deviations over 10 000 rolls are 0.009 at 10 % and 0.013 at 25 %.
const SHARE_TOLERANCE := 0.015
## Zone entries the tests make where no fog may come at all.
const MANY_ENTRIES := 500

var _default_chances: Dictionary[int, float] = {}


func before_all() -> void:
	_default_chances = WorldState.fog_chance_by_phase.duplicate()


func before_each() -> void:
	_reset()
	WorldState.rng.seed = SEED


func after_each() -> void:
	_reset()
	WorldState.rng.randomize()


func _reset() -> void:
	WorldState.fog_scene_active = false
	WorldState.zone_kind = OPEN
	WorldState.state = DAY
	WorldState.fog_chance_by_phase = _default_chances.duplicate()
	GameState.phase = 1
	GameState.zone_state.clear()


## Makes every roll for fog succeed in the phases of act 1.
func _always_roll_fog() -> void:
	for phase: int in [1, 2, 3]:
		WorldState.fog_chance_by_phase[phase] = 1.0


func test_request_fog_brings_the_fog_and_sounds_the_horn() -> void:
	watch_signals(EventBus)
	assert_true(WorldState.request_fog(&"FOG_1"), "the fog started")
	assert_eq(WorldState.state, FOG)
	assert_signal_emitted_with_parameters(EventBus, "world_state_changed", [FOG])
	assert_signal_emitted_with_parameters(EventBus, "fog_started", [&"FOG_1"])
	assert_signal_emit_count(EventBus, "fog_started", 1)
	assert_signal_emit_count(EventBus, "horn_sounded", 1)


func test_request_fog_does_nothing_while_it_is_fog() -> void:
	WorldState.request_fog(&"FOG_1")
	watch_signals(EventBus)
	assert_false(WorldState.request_fog(&"FOG_2"), "it is fog already")
	assert_eq(WorldState.state, FOG)
	assert_signal_not_emitted(EventBus, "fog_started")
	assert_signal_not_emitted(EventBus, "horn_sounded")
	assert_signal_not_emitted(EventBus, "world_state_changed")


func test_request_fog_is_refused_in_a_village() -> void:
	WorldState.on_zone_entered(&"refused_village", VILLAGE)
	watch_signals(EventBus)
	assert_false(WorldState.request_fog(&"FOG_1"), "fog never enters a village")
	assert_eq(WorldState.state, DAY)
	assert_signal_not_emitted(EventBus, "fog_started")
	assert_signal_not_emitted(EventBus, "horn_sounded")
	assert_signal_not_emitted(EventBus, "world_state_changed")


func test_request_fog_in_a_dungeon_brings_fog_without_the_horn() -> void:
	WorldState.on_zone_entered(&"hornless_dungeon", DUNGEON)
	watch_signals(EventBus)
	assert_true(WorldState.request_fog(&"FOG_3"))
	assert_eq(WorldState.state, FOG)
	assert_signal_emitted_with_parameters(EventBus, "fog_started", [&"FOG_3"])
	assert_signal_not_emitted(EventBus, "horn_sounded", "the horn is not heard inside a dungeon")


func test_end_fog_brings_the_day_back() -> void:
	WorldState.request_fog(&"FOG_1")
	watch_signals(EventBus)
	WorldState.end_fog()
	assert_eq(WorldState.state, DAY)
	assert_signal_emitted_with_parameters(EventBus, "world_state_changed", [DAY])
	assert_signal_emit_count(EventBus, "fog_ended", 1)


func test_end_fog_by_day_does_nothing() -> void:
	watch_signals(EventBus)
	WorldState.end_fog()
	assert_eq(WorldState.state, DAY)
	assert_signal_not_emitted(EventBus, "fog_ended")
	assert_signal_not_emitted(EventBus, "world_state_changed")


func test_assigning_the_state_changes_it_without_fog_signals() -> void:
	watch_signals(EventBus)
	WorldState.state = FOG
	assert_signal_emit_count(EventBus, "world_state_changed", 1)
	assert_signal_not_emitted(EventBus, "fog_started", "a loaded save and a debug key switch the state silently")
	assert_signal_not_emitted(EventBus, "horn_sounded")


func test_zone_kind_is_open_until_a_zone_is_entered_and_then_follows_the_zone() -> void:
	assert_eq(WorldState.zone_kind, OPEN, "a scene without zones can have fog")
	WorldState.on_zone_entered(&"kind_village", VILLAGE)
	assert_eq(WorldState.zone_kind, VILLAGE)
	WorldState.on_zone_entered(&"kind_dungeon", DUNGEON)
	assert_eq(WorldState.zone_kind, DUNGEON)
	WorldState.on_zone_entered(&"kind_open", OPEN)
	assert_eq(WorldState.zone_kind, OPEN)


func test_entering_a_village_ends_the_fog() -> void:
	WorldState.request_fog(&"FOG_1")
	watch_signals(EventBus)
	WorldState.on_zone_entered(&"ending_village", VILLAGE)
	assert_eq(WorldState.state, DAY)
	assert_signal_emit_count(EventBus, "fog_ended", 1)


func test_no_fog_ever_starts_in_a_village() -> void:
	_always_roll_fog()
	watch_signals(EventBus)
	for phase: int in [1, 2, 3]:
		GameState.phase = phase
		for i: int in MANY_ENTRIES:
			WorldState.on_zone_entered(&"quiet_village", VILLAGE)
			WorldState.request_fog(WorldState.RANDOM_REASON)
	assert_eq(WorldState.state, DAY, "not once in %d entries per phase, with every roll set to succeed" % MANY_ENTRIES)
	assert_signal_not_emitted(EventBus, "fog_started")
	assert_signal_not_emitted(EventBus, "horn_sounded")


func test_fog_chances_are_those_of_the_job_spec() -> void:
	assert_eq(WorldState.fog_chance_by_phase.size(), 3)
	assert_eq(WorldState.fog_chance_by_phase[1], 0.0)
	assert_eq(WorldState.fog_chance_by_phase[2], 0.10)
	assert_eq(WorldState.fog_chance_by_phase[3], 0.25)


func test_phase_1_never_rolls_fog() -> void:
	watch_signals(EventBus)
	for i: int in MANY_ENTRIES:
		WorldState.on_zone_entered(StringName("phase_1_zone_%d" % i), OPEN)
	assert_eq(WorldState.state, DAY)
	assert_signal_not_emitted(EventBus, "fog_started")


func test_open_zones_get_fog_at_the_chance_of_the_phase() -> void:
	assert_almost_eq(_measure_fog_share(2), 0.10, SHARE_TOLERANCE, "phase 2: one entry in ten")
	assert_almost_eq(_measure_fog_share(3), 0.25, SHARE_TOLERANCE, "phase 3: one entry in four")


func test_a_phase_without_a_chance_gets_no_fog() -> void:
	GameState.phase = 4
	for i: int in MANY_ENTRIES:
		WorldState.on_zone_entered(StringName("phase_4_zone_%d" % i), OPEN)
	assert_eq(WorldState.state, DAY, "a phase the table does not list has no random fog")


func test_random_fog_names_its_reason_and_sounds_the_horn() -> void:
	_always_roll_fog()
	watch_signals(EventBus)
	WorldState.on_zone_entered(&"random_reason_zone", OPEN)
	assert_eq(WorldState.state, FOG)
	assert_signal_emitted_with_parameters(EventBus, "fog_started", [WorldState.RANDOM_REASON])
	assert_eq(WorldState.RANDOM_REASON, &"random")
	assert_signal_emit_count(EventBus, "horn_sounded", 1)


## Enters [constant ROLLS] open zones by day in story phase [param phase], each under an id
## of its own, and returns the share of entries that brought fog.
func _measure_fog_share(phase: int) -> float:
	GameState.phase = phase
	var fogged := 0
	for i: int in ROLLS:
		WorldState.on_zone_entered(StringName("share_%d_zone_%d" % [phase, i]), OPEN)
		if WorldState.state == FOG:
			fogged += 1
			WorldState.end_fog()
	return float(fogged) / ROLLS


func test_no_random_fog_twice_in_a_row_for_the_same_zone() -> void:
	_always_roll_fog()
	WorldState.on_zone_entered(&"twice_woods", OPEN)
	assert_eq(WorldState.state, FOG, "first entry: the roll succeeds")
	WorldState.on_zone_entered(&"twice_village", VILLAGE)
	assert_eq(WorldState.state, DAY, "home: the fog ends")
	WorldState.on_zone_entered(&"twice_woods", OPEN)
	assert_eq(WorldState.state, DAY, "second entry in a row: no roll")
	WorldState.on_zone_entered(&"twice_village", VILLAGE)
	WorldState.on_zone_entered(&"twice_woods", OPEN)
	assert_eq(WorldState.state, FOG, "third entry: the zone rolls again")


func test_fog_in_another_zone_does_not_lift_the_rule() -> void:
	_always_roll_fog()
	WorldState.on_zone_entered(&"other_woods", OPEN)
	WorldState.on_zone_entered(&"other_village", VILLAGE)
	WorldState.on_zone_entered(&"other_meadow", OPEN)
	assert_eq(WorldState.state, FOG, "another zone rolls for itself")
	WorldState.on_zone_entered(&"other_village", VILLAGE)
	WorldState.on_zone_entered(&"other_woods", OPEN)
	assert_eq(WorldState.state, DAY, "the woods had fog on their last entry and get none on this one")


func test_walking_into_an_open_zone_in_fog_changes_nothing() -> void:
	_always_roll_fog()
	WorldState.on_zone_entered(&"walk_woods", OPEN)
	watch_signals(EventBus)
	WorldState.on_zone_entered(&"walk_meadow", OPEN)
	assert_eq(WorldState.state, FOG, "the fog came along")
	assert_signal_not_emitted(EventBus, "fog_started", "and did not start a second time")
	WorldState.on_zone_entered(&"walk_village", VILLAGE)
	WorldState.on_zone_entered(&"walk_meadow", OPEN)
	assert_eq(WorldState.state, FOG, "the meadow never rolled, so it may roll now")


func test_a_dungeon_leaves_the_state_alone() -> void:
	_always_roll_fog()
	watch_signals(EventBus)
	WorldState.on_zone_entered(&"quiet_dungeon", DUNGEON)
	assert_eq(WorldState.state, DAY, "no roll on the way in")
	WorldState.state = FOG
	WorldState.on_zone_entered(&"quiet_dungeon", DUNGEON)
	assert_eq(WorldState.state, FOG, "and fog outside stays fog inside")
	assert_signal_not_emitted(EventBus, "fog_started")
	assert_signal_not_emitted(EventBus, "fog_ended")


func test_a_scripted_scene_keeps_its_fog_through_a_village() -> void:
	WorldState.request_fog(&"FOG_1")
	WorldState.fog_scene_active = true
	WorldState.on_zone_entered(&"scene_village", VILLAGE)
	assert_eq(WorldState.state, FOG, "the scene owns the fog")
	WorldState.fog_scene_active = false
	WorldState.on_zone_entered(&"scene_village", VILLAGE)
	assert_eq(WorldState.state, DAY, "once the scene is over, a village ends it again")


func test_a_scripted_scene_keeps_random_fog_out() -> void:
	_always_roll_fog()
	WorldState.fog_scene_active = true
	for i: int in MANY_ENTRIES:
		WorldState.on_zone_entered(StringName("scene_zone_%d" % i), OPEN)
	assert_eq(WorldState.state, DAY, "no roll while a scripted scene runs")


func test_a_scripted_scene_starts_and_ends_its_own_fog() -> void:
	WorldState.fog_scene_active = true
	assert_true(WorldState.request_fog(&"FOG_2"))
	assert_eq(WorldState.state, FOG)
	WorldState.end_fog()
	assert_eq(WorldState.state, DAY)


func test_nearest_lit_cairn_is_the_closest_one_that_burns() -> void:
	var near_unlit := _make_cairn(Vector3(1.0, 0.0, 0.0), false)
	var east_lit := _make_cairn(Vector3(10.0, 0.0, 0.0), true)
	var west_lit := _make_cairn(Vector3(-30.0, 0.0, 0.0), true)
	assert_eq(WorldState.nearest_lit_cairn(Vector3.ZERO), east_lit, "the unlit cairn is nearer but does not count")
	assert_eq(WorldState.nearest_lit_cairn(Vector3(-25.0, 0.0, 0.0)), west_lit)
	near_unlit.lit = true
	assert_eq(WorldState.nearest_lit_cairn(Vector3.ZERO), near_unlit, "once lit, it is the nearest")


func test_nearest_lit_cairn_is_null_when_none_burns() -> void:
	_make_cairn(Vector3(2.0, 0.0, 0.0), false)
	assert_null(WorldState.nearest_lit_cairn(Vector3.ZERO))


func _make_cairn(at: Vector3, lit: bool) -> Cairn:
	var cairn: Cairn = CAIRN.instantiate()
	cairn.position = at
	cairn.lit = lit
	add_child_autofree(cairn)
	return cairn
