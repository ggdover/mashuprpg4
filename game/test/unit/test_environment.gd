extends GutTest
## The environment presets and the controller that shows them. The presets carry the palette
## roles the job names (a guard against the palette and the resources drifting apart), the
## fog hides a box at the distances the job names, and the day and the fog preset agree on
## everything a transition does not blend. The EnvironmentController shows the preset of the
## state, tweens to the other one when the state changes, keeps to the cave preset in a
## dungeon and leaves the preset resources as they are.

const ENV_DAY: Environment = preload("res://world/environment/env_day.tres")
const ENV_FOG: Environment = preload("res://world/environment/env_fog.tres")
const ENV_CAVE: Environment = preload("res://world/environment/env_cave.tres")
const LIGHT_DAY: LightPreset = preload("res://world/environment/light_day.tres")
const LIGHT_FOG: LightPreset = preload("res://world/environment/light_fog.tres")
const CAMERA_RIG: PackedScene = preload("res://player/camera_rig.tscn")
## The day horizon. It is no palette role of its own: design/palette.md names it in the sky row.
const DAY_HORIZON := Color("#B5D2EE")
## The distances the job gives for the fog: a box is barely visible at the first and
## invisible at the second, in metres from the camera.
const BARELY_VISIBLE_AT := 35.0
const INVISIBLE_AT := 50.0
## How far past the player the cave lets the eye reach, in metres.
const CAVE_VISIBILITY := 20.0
## The share of a box the fog covers from which it counts as barely visible, and as gone.
const BARELY_VISIBLE := 0.85
const INVISIBLE := 0.99
## The most fog that may lie on the player at the default zoom for the fight to stay readable.
const READABLE := 0.5
## Seconds the transition tests give the controller instead of its 2.5.
const SHORT_TRANSITION := 0.4
## Seconds for a transition that a test looks at part of the way through.
const LONG_TRANSITION := 1.0
const TOLERANCE := 0.0001

var _camera_distance := 0.0


func before_all() -> void:
	var rig: CameraRig = CAMERA_RIG.instantiate()
	_camera_distance = rig.distance
	rig.free()


func before_each() -> void:
	WorldState.state = WorldState.State.DAY


func after_each() -> void:
	WorldState.state = WorldState.State.DAY


func test_day_preset_carries_the_day_palette() -> void:
	var sky := ENV_DAY.sky.sky_material as ProceduralSkyMaterial
	assert_eq(ENV_DAY.background_mode, Environment.BG_SKY)
	_assert_color(sky.sky_top_color, Palette.DAY["sky"], "sky top is the sky role")
	_assert_color(sky.sky_horizon_color, DAY_HORIZON, "sky horizon is the day horizon")
	assert_eq(ENV_DAY.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	_assert_color(ENV_DAY.ambient_light_color, Palette.DAY["light"], "ambient is ramp light")
	assert_almost_eq(ENV_DAY.ambient_light_energy, 0.5, TOLERANCE)
	assert_false(ENV_DAY.fog_enabled, "no fog by day")
	assert_false(ENV_DAY.volumetric_fog_enabled, "volumetric fog is off by default")


func test_fog_preset_carries_the_fog_palette() -> void:
	assert_true(ENV_FOG.fog_enabled)
	_assert_color(ENV_FOG.fog_light_color, Palette.FOG["light"], "fog colour is ramp light")
	assert_eq(ENV_FOG.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	_assert_color(ENV_FOG.ambient_light_color, Palette.FOG["mid"], "ambient is ramp mid")
	assert_almost_eq(ENV_FOG.fog_sky_affect, 1.0, TOLERANCE, "the fog covers the sky")
	assert_false(ENV_FOG.volumetric_fog_enabled, "volumetric fog is off by default")
	_assert_color(ENV_FOG.volumetric_fog_albedo, Palette.FOG["light"], "and has the fog's colour when switched on")


func test_fog_hides_a_box_at_the_distances_the_job_names() -> void:
	assert_between(_fog_amount(ENV_FOG, BARELY_VISIBLE_AT), BARELY_VISIBLE, INVISIBLE, "barely visible at 35 m")
	assert_gte(_fog_amount(ENV_FOG, INVISIBLE_AT), INVISIBLE, "invisible at 50 m")
	assert_lt(_fog_amount(ENV_FOG, _camera_distance), READABLE, "and what stands around the player stays readable")
	assert_gt(_fog_amount(ENV_FOG, _camera_distance), 0.0, "though the fog reaches it")


func test_cave_preset_is_dark_and_closes_in_twenty_metres_past_the_player() -> void:
	assert_eq(ENV_CAVE.background_mode, Environment.BG_COLOR, "no sky")
	_assert_color(ENV_CAVE.background_color, Palette.FOG["deepest"], "black behind everything")
	assert_eq(ENV_CAVE.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	_assert_color(ENV_CAVE.ambient_light_color, Palette.FOG["deepest"], "ambient is ramp deepest")
	assert_almost_eq(ENV_CAVE.ambient_light_energy, 0.2, TOLERANCE)
	assert_true(ENV_CAVE.fog_enabled)
	_assert_color(ENV_CAVE.fog_light_color, Palette.FOG["shadow"], "fog colour is ramp shadow")
	assert_almost_eq(_fog_amount(ENV_CAVE, _camera_distance), 0.0, TOLERANCE, "no fog on the player")
	assert_gte(_fog_amount(ENV_CAVE, _camera_distance + CAVE_VISIBILITY), INVISIBLE, "nothing to see 20 m further")
	assert_false(ENV_CAVE.volumetric_fog_enabled, "volumetric fog is off by default")


func test_light_presets_carry_the_palette() -> void:
	_assert_color(LIGHT_DAY.color, Palette.DAY["sun"], "the day light is the sun role")
	assert_almost_eq(LIGHT_DAY.energy, 1.2, TOLERANCE)
	assert_almost_eq(LIGHT_DAY.shadow_softness, 0.0, TOLERANCE, "hard shadows by day")
	_assert_color(LIGHT_FOG.color, Palette.FOG["spirit"], "the fog light is the spirit role")
	assert_almost_eq(LIGHT_FOG.energy, 0.35, TOLERANCE)
	assert_gt(LIGHT_FOG.shadow_softness, 0.0, "soft shadows in fog")


func test_day_and_fog_presets_agree_on_what_a_transition_does_not_blend() -> void:
	# Whatever differs here would jump when the state changes instead of fading.
	var blended: Array[StringName] = [&"sky"]
	blended.append_array(EnvironmentController.AMBIENT)
	var fog_prefixes: Array[String] = ["fog_", "volumetric_fog_"]
	var sky_material: Array[StringName] = [&"sky_material"]
	var no_names: Array[StringName] = []
	var no_prefixes: Array[String] = []
	_assert_same_but(ENV_DAY, ENV_FOG, blended, fog_prefixes)
	_assert_same_but(ENV_DAY.sky, ENV_FOG.sky, sky_material, no_prefixes)
	_assert_same_but(ENV_DAY.sky.sky_material, ENV_FOG.sky.sky_material, no_names, no_prefixes)


## How much of a surface the fog of [param environment] covers at [param distance] metres
## from the camera: 0 is none of it, 1 all of it. These are the engine's formulas for its
## two fog modes.
func _fog_amount(environment: Environment, distance: float) -> float:
	if not environment.fog_enabled:
		return 0.0
	if environment.fog_mode == Environment.FOG_MODE_DEPTH:
		var reach := smoothstep(environment.fog_depth_begin, environment.fog_depth_end, distance)
		return pow(reach, environment.fog_depth_curve) * environment.fog_density
	return 1.0 - exp(-distance * environment.fog_density)


func _assert_color(actual: Color, expected: Color, text: String) -> void:
	assert_true(actual.is_equal_approx(expected), "%s: #%s, expected #%s" % [text, actual.to_html(false), expected.to_html(false)])


## Asserts that two resources store the same value in every property, apart from the
## properties named in [param skipped] and those whose name starts with one of
## [param skipped_prefixes].
func _assert_same_but(a: Resource, b: Resource, skipped: Array[StringName], skipped_prefixes: Array[String]) -> void:
	var compared := 0
	for property: Dictionary in a.get_property_list():
		var property_name: String = property["name"]
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_STORAGE == 0 or property_name.begins_with("resource_") or property_name == "script":
			continue
		if skipped.has(StringName(property_name)) or _has_prefix(property_name, skipped_prefixes):
			continue
		compared += 1
		if a.get(property_name) != b.get(property_name):
			fail_test("%s differs: %s and %s" % [property_name, a.get(property_name), b.get(property_name)])
	assert_gt(compared, 0, "%s: %d properties compared" % [a.get_class(), compared])


func _has_prefix(text: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if text.begins_with(prefix):
			return true
	return false


func test_controller_makes_its_own_environment_and_sun() -> void:
	var controller := _make_controller()
	assert_eq(controller.world_environment.get_parent(), controller, "a WorldEnvironment of its own")
	assert_eq(controller.sun.get_parent(), controller, "and a sun of its own")
	assert_true(controller.sun.shadow_enabled, "that casts shadows")
	var down := -controller.sun.global_basis.z
	assert_almost_eq(rad_to_deg(asin(-down.y)), 45.0, 0.01, "from 45 degrees above the horizon")


func test_controller_takes_over_the_environment_and_sun_it_is_given() -> void:
	var world_environment := WorldEnvironment.new()
	add_child_autofree(world_environment)
	var sun := DirectionalLight3D.new()
	add_child_autofree(sun)
	var controller := EnvironmentController.new()
	controller.world_environment = world_environment
	controller.sun = sun
	add_child_autofree(controller)
	assert_eq(controller.get_child_count(), 0, "it makes none of its own")
	assert_not_null(world_environment.environment, "the given WorldEnvironment shows the look")
	_assert_color(sun.light_color, LIGHT_DAY.color, "and the given sun shines in it")
	_assert_shows(controller, ENV_DAY, LIGHT_DAY, "by day")


func test_a_zone_starts_in_the_look_of_its_state() -> void:
	_assert_shows(_make_controller(), ENV_DAY, LIGHT_DAY, "ready by day")
	WorldState.state = WorldState.State.FOG
	_assert_shows(_make_controller(), ENV_FOG, LIGHT_FOG, "ready in fog, with nothing to tween from")


func test_a_change_of_state_takes_two_and_a_half_seconds_by_default() -> void:
	var controller := EnvironmentController.new()
	assert_eq(controller.transition_seconds, 2.5)
	controller.free()


func test_a_change_of_state_tweens_to_the_other_look() -> void:
	var controller := _make_controller()
	controller.transition_seconds = LONG_TRANSITION
	WorldState.state = WorldState.State.FOG
	var shown := controller.world_environment.environment
	assert_true(shown.fog_enabled, "the fog is switched on at once")
	assert_almost_eq(_fog_amount(shown, BARELY_VISIBLE_AT), 0.0, TOLERANCE, "but there is none of it yet")
	assert_almost_eq(shown.fog_sky_affect, 0.0, TOLERANCE, "nor over the sky")
	assert_almost_eq(shown.ambient_light_energy, ENV_DAY.ambient_light_energy, TOLERANCE, "the ambient light is still the day's")
	assert_almost_eq(controller.sun.light_energy, LIGHT_DAY.energy, TOLERANCE, "and so is the sun")

	await wait_seconds(LONG_TRANSITION * 0.3)
	var fog_on_the_way := _fog_amount(shown, BARELY_VISIBLE_AT)
	assert_between(fog_on_the_way, 0.01, _fog_amount(ENV_FOG, BARELY_VISIBLE_AT) - 0.01, "on the way the fog is part of the way in")
	assert_between(shown.ambient_light_energy, ENV_DAY.ambient_light_energy + 0.01, ENV_FOG.ambient_light_energy - 0.01, "the ambient light part of the way up")
	assert_between(controller.sun.light_energy, LIGHT_FOG.energy + 0.01, LIGHT_DAY.energy - 0.01, "and the sun part of the way down")
	assert_false(controller.sun.light_color.is_equal_approx(LIGHT_DAY.color), "its colour has left the day's")
	assert_false(controller.sun.light_color.is_equal_approx(LIGHT_FOG.color), "and not yet reached the fog's")

	await wait_seconds(LONG_TRANSITION)
	_assert_shows(controller, ENV_FOG, LIGHT_FOG, "after the transition")


func test_a_transition_back_to_day_fades_the_fog_out_and_switches_it_off() -> void:
	WorldState.state = WorldState.State.FOG
	var controller := _make_controller()
	WorldState.state = WorldState.State.DAY
	var shown := controller.world_environment.environment
	assert_true(shown.fog_enabled, "the fog stays on while it fades")
	assert_almost_eq(_fog_amount(shown, BARELY_VISIBLE_AT), _fog_amount(ENV_FOG, BARELY_VISIBLE_AT), TOLERANCE, "and starts from all of it, in the same shape")
	_assert_color(shown.fog_light_color, ENV_FOG.fog_light_color, "and in the fog's colour")
	await wait_seconds(SHORT_TRANSITION + 0.2)
	_assert_shows(controller, ENV_DAY, LIGHT_DAY, "after the transition")


func test_a_transition_that_is_interrupted_goes_on_from_where_it_stands() -> void:
	var controller := _make_controller()
	controller.transition_seconds = LONG_TRANSITION
	WorldState.state = WorldState.State.FOG
	await wait_seconds(LONG_TRANSITION * 0.3)
	var fog_before := _fog_amount(controller.world_environment.environment, BARELY_VISIBLE_AT)
	var sun_before := controller.sun.light_energy
	controller.transition_seconds = SHORT_TRANSITION
	WorldState.state = WorldState.State.DAY
	var shown := controller.world_environment.environment
	assert_almost_eq(_fog_amount(shown, BARELY_VISIBLE_AT), fog_before, TOLERANCE, "the fog does not jump when the state turns back")
	assert_almost_eq(controller.sun.light_energy, sun_before, TOLERANCE, "nor does the sun")
	await wait_seconds(SHORT_TRANSITION + 0.2)
	_assert_shows(controller, ENV_DAY, LIGHT_DAY, "after the way back")


func test_force_cave_shows_the_cave_in_both_states() -> void:
	var controller := EnvironmentController.new()
	controller.force_cave = true
	controller.transition_seconds = SHORT_TRANSITION
	add_child_autofree(controller)
	_assert_shows(controller, ENV_CAVE, null, "a dungeon by day")
	WorldState.state = WorldState.State.FOG
	_assert_shows(controller, ENV_CAVE, null, "and at once in fog: nothing tweens")


func test_leaving_the_cave_brings_the_look_of_the_state_back() -> void:
	var controller := _make_controller()
	controller.force_cave = true
	await wait_seconds(SHORT_TRANSITION + 0.2)
	_assert_shows(controller, ENV_CAVE, null, "in the cave")
	controller.force_cave = false
	await wait_seconds(SHORT_TRANSITION + 0.2)
	_assert_shows(controller, ENV_DAY, LIGHT_DAY, "out of it")


func test_the_presets_are_left_as_they_are() -> void:
	var day_ambient := ENV_DAY.ambient_light_color
	var fog_density := ENV_FOG.fog_density
	var controller := _make_controller()
	WorldState.state = WorldState.State.FOG
	await wait_seconds(SHORT_TRANSITION * 0.5)
	WorldState.state = WorldState.State.DAY
	await wait_seconds(SHORT_TRANSITION + 0.2)
	assert_ne(controller.world_environment.environment, ENV_DAY, "the controller shows a copy")
	assert_false(ENV_DAY.fog_enabled, "the day preset still has no fog")
	_assert_color(ENV_DAY.ambient_light_color, day_ambient, "and its own ambient light")
	assert_true(ENV_FOG.fog_enabled, "the fog preset still has its fog")
	assert_almost_eq(ENV_FOG.fog_density, fog_density, TOLERANCE, "all of it")


func test_volumetric_fog_is_off_until_it_is_asked_for() -> void:
	var controller := _make_controller()
	controller.transition_seconds = 0.0
	assert_false(controller.volumetric_fog, "off by default")
	WorldState.state = WorldState.State.FOG
	assert_false(controller.world_environment.environment.volumetric_fog_enabled, "so the fog look has none")
	controller.volumetric_fog = true
	assert_true(controller.world_environment.environment.volumetric_fog_enabled, "the toggle adds it to the fog look")
	WorldState.state = WorldState.State.DAY
	assert_false(controller.world_environment.environment.volumetric_fog_enabled, "and the day stays clear")
	WorldState.state = WorldState.State.FOG
	assert_true(controller.world_environment.environment.volumetric_fog_enabled, "it comes back with the fog")


func _make_controller() -> EnvironmentController:
	var controller := EnvironmentController.new()
	controller.transition_seconds = SHORT_TRANSITION
	add_child_autofree(controller)
	return controller


## Asserts that [param controller] shows the look of [param environment] and of
## [param light]; no light stands for no sun, as in a cave.
func _assert_shows(controller: EnvironmentController, environment: Environment, light: LightPreset, text: String) -> void:
	var shown := controller.world_environment.environment
	assert_eq(shown.background_mode, environment.background_mode, text + ": background")
	_assert_color(shown.ambient_light_color, environment.ambient_light_color, text + ": ambient colour")
	assert_almost_eq(shown.ambient_light_energy, environment.ambient_light_energy, TOLERANCE, text + ": ambient energy")
	assert_eq(shown.fog_enabled, environment.fog_enabled, text + ": fog on or off")
	if environment.fog_enabled:
		_assert_color(shown.fog_light_color, environment.fog_light_color, text + ": fog colour")
		assert_almost_eq(shown.fog_sky_affect, environment.fog_sky_affect, TOLERANCE, text + ": fog over the sky")
		for distance: float in [10.0, _camera_distance, BARELY_VISIBLE_AT, INVISIBLE_AT]:
			assert_almost_eq(_fog_amount(shown, distance), _fog_amount(environment, distance), TOLERANCE, "%s: fog at %.0f m" % [text, distance])
	if light == null:
		assert_false(controller.sun.visible, text + ": no sun")
		return
	assert_true(controller.sun.visible, text + ": the sun shines")
	_assert_color(controller.sun.light_color, light.color, text + ": sun colour")
	assert_almost_eq(controller.sun.light_energy, light.energy, TOLERANCE, text + ": sun energy")
	assert_almost_eq(controller.sun.light_angular_distance, light.shadow_softness, TOLERANCE, text + ": shadow softness")


func test_the_default_transition_is_under_way_after_two_seconds_and_done_after_three() -> void:
	var controller := EnvironmentController.new()
	add_child_autofree(controller)
	WorldState.state = WorldState.State.FOG
	await wait_seconds(2.0)
	var full := _fog_amount(ENV_FOG, BARELY_VISIBLE_AT)
	var shown := controller.world_environment.environment
	assert_between(_fog_amount(shown, BARELY_VISIBLE_AT), 0.6 * full, 0.95 * full, "2 s into the 2.5: most of the fog is in, not all of it")
	await wait_seconds(1.0)
	_assert_shows(controller, ENV_FOG, LIGHT_FOG, "after 3 s")


func test_show_state_waits_for_the_controller_to_be_ready() -> void:
	var controller := EnvironmentController.new()
	controller.show_state(0.0)
	assert_null(controller.world_environment, "nothing is made or shown before the node is in the tree")
	add_child_autofree(controller)
	_assert_shows(controller, ENV_DAY, LIGHT_DAY, "once it is ready")


func test_volumetric_fog_fades_in_with_the_fog() -> void:
	var controller := _make_controller()
	controller.volumetric_fog = true
	assert_false(controller.world_environment.environment.volumetric_fog_enabled, "none by day")
	WorldState.state = WorldState.State.FOG
	var shown := controller.world_environment.environment
	assert_true(shown.volumetric_fog_enabled, "it is switched on as the fog starts")
	assert_almost_eq(shown.volumetric_fog_density, 0.0, TOLERANCE, "with none of it there yet")
	await wait_seconds(SHORT_TRANSITION + 0.2)
	assert_almost_eq(shown.volumetric_fog_density, ENV_FOG.volumetric_fog_density, TOLERANCE, "and ends at the preset's density")
