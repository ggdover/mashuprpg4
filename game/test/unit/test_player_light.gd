extends GutTest
## The player's light: out by day, 6 m in fog, 12 m with the lantern flag, lit in a dungeon
## whatever the state, ember, and carried by the player scene above the head.

const PLAYER: PackedScene = preload("res://player/player.tscn")
const DAY := WorldState.State.DAY
const FOG := WorldState.State.FOG
const TOLERANCE := 0.0001
## Height of the player box in metres: the light hangs above it.
const PLAYER_HEIGHT := 1.8


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _reset() -> void:
	WorldState.state = DAY
	WorldState.zone_kind = WorldState.ZoneKind.OPEN
	GameState.flags.erase(PlayerLight.LANTERN_FLAG)


func test_the_light_is_out_by_day() -> void:
	var player_light := _make_light()
	assert_false(player_light.light.visible, "the day scene is lit by the sun alone")
	assert_false(player_light.is_needed())


func test_the_light_reaches_6_m_in_fog() -> void:
	var player_light := _make_light()
	WorldState.state = FOG
	player_light.refresh()
	assert_true(player_light.light.visible)
	assert_almost_eq(player_light.light.omni_range, 6.0, TOLERANCE)


func test_the_lantern_widens_it_to_12_m() -> void:
	var player_light := _make_light()
	WorldState.state = FOG
	GameState.set_flag(&"has_lantern")
	player_light.refresh()
	assert_true(player_light.light.visible)
	assert_almost_eq(player_light.light.omni_range, 12.0, TOLERANCE)
	assert_eq(PlayerLight.LANTERN_FLAG, &"has_lantern", "the flag quest Q11 sets")


func test_the_lantern_alone_does_not_light_the_day() -> void:
	var player_light := _make_light()
	GameState.set_flag(PlayerLight.LANTERN_FLAG)
	player_light.refresh()
	assert_false(player_light.light.visible)


func test_the_light_burns_in_a_dungeon_by_day() -> void:
	var player_light := _make_light()
	WorldState.on_zone_entered(&"light_dungeon", WorldState.ZoneKind.DUNGEON)
	player_light.refresh()
	assert_eq(WorldState.state, DAY, "a dungeon leaves the state alone")
	assert_true(player_light.light.visible, "but it is dark in there")
	assert_almost_eq(player_light.light.omni_range, 6.0, TOLERANCE)
	WorldState.on_zone_entered(&"light_village", WorldState.ZoneKind.VILLAGE)
	player_light.refresh()
	assert_false(player_light.light.visible, "and out again in the daylight")


func test_the_light_goes_out_when_the_fog_ends() -> void:
	var player_light := _make_light()
	WorldState.request_fog(&"FOG_1")
	player_light.refresh()
	assert_true(player_light.light.visible)
	WorldState.end_fog()
	player_light.refresh()
	assert_false(player_light.light.visible)


func test_the_light_follows_the_world_by_itself_within_a_frame() -> void:
	var player_light := _make_light()
	WorldState.state = FOG
	GameState.flags[PlayerLight.LANTERN_FLAG] = true
	await wait_process_frames(2)
	assert_true(player_light.light.visible, "nobody called refresh: it looks every frame")
	assert_almost_eq(player_light.light.omni_range, 12.0, TOLERANCE, "and sees a flag that a loaded save set without a signal")


func test_the_light_is_ember() -> void:
	var player_light := _make_light()
	assert_eq(player_light.light.light_color, Palette.FOG["ember"], "light the player made is warm")


func test_the_player_scene_carries_the_light_above_its_head() -> void:
	var player: Player = PLAYER.instantiate()
	add_child_autofree(player)
	var player_light := player.get_node_or_null("PlayerLight") as PlayerLight
	assert_not_null(player_light, "player.tscn has a PlayerLight")
	assert_gt(player_light.light.global_position.y, player.global_position.y + PLAYER_HEIGHT, "above the box, so the box does not shade it")
	assert_false(player_light.light.visible, "and it is out by day")
	WorldState.state = FOG
	await wait_process_frames(2)
	assert_true(player_light.light.visible, "and lit in fog")


func _make_light() -> PlayerLight:
	var player_light := PlayerLight.new()
	add_child_autofree(player_light)
	return player_light
