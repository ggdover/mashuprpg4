extends GutTest
## The J03 test scene as a whole: three dummies that carry the damage pipeline, and the
## keys of the damage tester doing to them what the overlay says. The keys are sent to the
## scene the way the engine sends them, as key events to _unhandled_input, and the hits run
## on real physics frames.

const TEST_SCENE: PackedScene = preload("res://test/test_combat.tscn")
const DUMMY_SCENE: PackedScene = preload("res://test/combat_dummy.tscn")
const TOLERANCE := 0.0001
## Physics frames for a hit key to do its work: a tick for the engine to find the hitbox,
## one for the hit, plus spare. The hitbox is still active after them.
const HIT_FRAMES := 5
## Physics frames after which the hitbox of a hit key is gone: it lives for a dozen.
const HIT_OVER_FRAMES := 20
## Size of the viewport the scene runs in: the size of the project window, so that the
## scene's camera sees what it sees in the game. Headless, the window itself is 64 x 64.
const VIEW_SIZE := Vector2i(1600, 900)
## Where stun stands among the status keys: on the 3.
const STUN_INDEX := 2

var _viewport: SubViewport
var _scene: CombatTestScene
var _plain: CombatDummy
var _armored: CombatDummy
var _neutral: CombatDummy
var _dummies: Array[CombatDummy] = []


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	add_child_autofree(_viewport)
	_scene = TEST_SCENE.instantiate()
	_viewport.add_child(_scene)
	_plain = _scene.get_node("Dummies/Plain")
	_armored = _scene.get_node("Dummies/Armored")
	_neutral = _scene.get_node("Dummies/Neutral")
	_dummies = [_plain, _armored, _neutral]
	await _physics_steps(2)


func test_three_dummies_carry_the_damage_pipeline() -> void:
	assert_eq(_scene.get_node("Dummies").get_child_count(), 3)
	for dummy: CombatDummy in _dummies:
		var body := dummy.get_node("Body") as BoxProp
		assert_not_null(body, "%s is a box prop" % dummy.display_name)
		assert_eq(body.collision_layer, 1 << 2, "on layer 3, enemy_body, so that projectiles do not take it for a wall")
		assert_is(dummy.stats, StatBlock)
		assert_is(dummy.get_node("Health"), Health)
		assert_is(dummy.get_node("Hurtbox"), Hurtbox)
		assert_is(dummy.get_node("StatusEffectManager"), StatusEffectManager)
		assert_is(dummy.get_node("DamageNumbers"), DebugDamageNumbers)
		assert_eq(dummy.health.stats, dummy.stats, "the health reads the dummy's stat block")
		assert_eq(dummy.status.stats, dummy.stats, "and so does the status manager")
		assert_eq(dummy.status.health, dummy.health)
		assert_eq(dummy.hurtbox.health, dummy.health)
		assert_eq(dummy.health.current, 100.0, "%s starts at full health" % dummy.display_name)


func test_the_dummies_differ_where_the_pipeline_does() -> void:
	assert_eq(_plain.stats.get_stat(StatBlock.ARMOR), 0.0)
	assert_eq(_plain.stats.get_stat(StatBlock.FROST_RESISTANCE), 0.0)
	assert_eq(_armored.stats.get_stat(StatBlock.ARMOR), 100.0)
	assert_eq(_neutral.stats.get_stat(StatBlock.FROST_RESISTANCE), 100.0)
	assert_eq(_plain.hurtbox.faction, Factions.Faction.ENEMY)
	assert_eq(_armored.hurtbox.faction, Factions.Faction.ENEMY)
	assert_eq(_neutral.hurtbox.faction, Factions.Faction.NEUTRAL_ANIMAL)

	_plain.faction = Factions.Faction.PLAYER
	assert_eq(_plain.hurtbox.faction, Factions.Faction.PLAYER, "a faction changed later reaches the hurtbox too")
	assert_eq(_plain.hurtbox.collision_layer, 1 << 3, "and moves it to layer 4, player_hurtbox")


func test_every_dummy_has_a_stat_block_of_its_own() -> void:
	var first: CombatDummy = DUMMY_SCENE.instantiate()
	var second: CombatDummy = DUMMY_SCENE.instantiate()
	add_child_autofree(first)
	add_child_autofree(second)
	assert_ne(first.stats, second.stats, "two instances of the dummy scene do not share the scene's block")
	first.stats.add_modifier(&"test", StatBlock.MAX_HEALTH, 100.0, 0.0)
	assert_eq(first.health.maximum, 200.0)
	assert_eq(second.health.maximum, 100.0, "what changes one leaves the other alone")

	var copy := first.duplicate() as CombatDummy
	add_child_autofree(copy)
	assert_ne(copy.stats, first.stats, "a duplicated dummy takes its own copy too")
	assert_eq(copy.health.maximum, 100.0, "without the modifiers of the original")


func test_the_physical_hit_key_hits_every_dummy_once() -> void:
	_press(CombatTestScene.HIT_PHYSICAL_KEY)
	await _physics_steps(HIT_FRAMES)
	assert_eq(_scene.find_children("*", "Hitbox", true, false).size(), 1, "the hitbox is still there and active")
	await _physics_steps(HIT_OVER_FRAMES)
	assert_almost_eq(_plain.health.current, 80.0, TOLERANCE, "no armor: the full 20")
	assert_almost_eq(_armored.health.current, 90.0, TOLERANCE, "100 armor: 10 of the 20")
	assert_almost_eq(_neutral.health.current, 80.0, TOLERANCE, "frost resistance does nothing against a physical hit")
	assert_eq(_scene.last_hit_count, 3, "three hurtboxes, one hit each, in a dozen ticks of overlap")
	assert_eq(_scene.find_children("*", "Hitbox", true, false).size(), 0, "the hitbox is gone when its time is up")


func test_the_frost_hit_key_is_mitigated_by_frost_resistance() -> void:
	_press(CombatTestScene.HIT_FROST_KEY)
	await _physics_steps(HIT_FRAMES)
	assert_almost_eq(_plain.health.current, 80.0, TOLERANCE)
	assert_almost_eq(_armored.health.current, 80.0, TOLERANCE, "armor does nothing against frost")
	assert_almost_eq(_neutral.health.current, 90.0, TOLERANCE, "100 frost resistance: 10 of the 20")
	var number := _numbers(_neutral).get_child(0) as Label3D
	assert_eq(number.text, "10")
	assert_eq(number.modulate, Palette.role(&"spirit", WorldState.state), "frost numbers take the spirit colour")


func test_the_crit_hit_key_always_crits() -> void:
	_press(CombatTestScene.HIT_CRIT_KEY)
	await _physics_steps(HIT_FRAMES)
	assert_almost_eq(_plain.health.current, 60.0, TOLERANCE, "20 times the tester's crit multiplier of 2")
	assert_almost_eq(_armored.health.current, 80.0, TOLERANCE)
	assert_eq((_numbers(_plain).get_child(0) as Label3D).text, "40!")
	assert_false(_scene.attacker_stats.has_source(CombatTestScene.CRIT_SOURCE), "the certain crit was for this one hit")


func test_the_plain_hit_keys_never_crit() -> void:
	for i: int in 5:
		var hitbox := _scene.spawn_hit(Factions.Faction.PLAYER, 20.0, 0.0, false)
		assert_false(hitbox.damage_info.is_crit)
		assert_eq(hitbox.damage_info.source, _scene)
		hitbox.free()


func test_the_enemy_hit_key_lands_on_nobody() -> void:
	_press(CombatTestScene.HIT_ENEMY_KEY)
	await _physics_steps(HIT_OVER_FRAMES)
	for dummy: CombatDummy in _dummies:
		assert_eq(dummy.health.current, 100.0, "%s is no player" % dummy.display_name)
	assert_eq(_scene.last_hit_count, 0)


func test_every_hit_shows_a_number_above_its_dummy() -> void:
	_press(CombatTestScene.HIT_PHYSICAL_KEY)
	await _physics_steps(HIT_FRAMES)
	var expected: Array[String] = ["20", "10", "20"]
	for index: int in _dummies.size():
		var numbers := _numbers(_dummies[index])
		assert_eq(numbers.get_child_count(), 1, "one number")
		assert_eq((numbers.get_child(0) as Label3D).text, expected[index])
	await _physics_steps(roundi(_numbers(_plain).lifetime * Engine.physics_ticks_per_second) + HIT_FRAMES)
	assert_eq(_numbers(_plain).get_child_count(), 0, "gone after 0.6 s")


func test_the_number_keys_put_the_seven_effects_on_every_dummy() -> void:
	var ids: Array[StringName] = [&"bleed", &"slow", &"stun", &"root", &"armor_break", &"frostbite", &"burn"]
	for index: int in ids.size():
		_press_status(index)
		for dummy: CombatDummy in _dummies:
			assert_true(dummy.status.has_effect(ids[index]), "key %d puts %s on %s" % [index + 1, ids[index], dummy.display_name])
	assert_eq(_plain.status.get_effect_ids(), ids)
	assert_false(_plain.status.can_act, "stunned")
	assert_almost_eq(_armored.stats.get_stat(StatBlock.ARMOR), 50.0, TOLERANCE, "armor broken")
	assert_almost_eq(_plain.stats.get_stat(StatBlock.MOVE_SPEED), 4.0 * 0.3, TOLERANCE, "slowed by slow and frostbite")

	await _physics_steps(40)
	assert_lt(_plain.health.current, 100.0, "bleed, frostbite and burn have ticked within the first half second")
	assert_gt(_numbers(_plain).get_child_count(), 0, "and their ticks show as numbers")


func test_the_heal_key_heals_and_revives() -> void:
	_plain.health.take_damage(_packet(40.0))
	_armored.health.take_damage(_packet(1000.0))
	assert_true(_armored.health.is_dead)
	_press(CombatTestScene.HEAL_KEY)
	assert_almost_eq(_plain.health.current, 85.0, TOLERANCE, "healed by 25")
	assert_false(_armored.health.is_dead, "the dead dummy is back")
	assert_eq(_armored.health.current, 100.0, "at full health")
	assert_eq(_neutral.health.current, 100.0, "a full one stays full")


func test_the_invulnerable_key_toggles() -> void:
	_press(CombatTestScene.INVULNERABLE_KEY)
	for dummy: CombatDummy in _dummies:
		assert_true(dummy.health.invulnerable)
	_press(CombatTestScene.HIT_PHYSICAL_KEY)
	await _physics_steps(HIT_OVER_FRAMES)
	for dummy: CombatDummy in _dummies:
		assert_eq(dummy.health.current, 100.0, "%s took nothing" % dummy.display_name)
	assert_string_contains(_plain.describe(), "invulnerable")

	_press(CombatTestScene.INVULNERABLE_KEY)
	for dummy: CombatDummy in _dummies:
		assert_false(dummy.health.invulnerable)
	_press(CombatTestScene.HIT_PHYSICAL_KEY)
	await _physics_steps(HIT_FRAMES)
	assert_almost_eq(_plain.health.current, 80.0, TOLERANCE, "vulnerable again")


func test_the_shield_key_puts_up_a_shield_that_absorbs_first() -> void:
	_press(CombatTestScene.SHIELD_KEY)
	for dummy: CombatDummy in _dummies:
		assert_eq(dummy.health.shield, _scene.shield_amount)
	_press(CombatTestScene.HIT_PHYSICAL_KEY)
	await _physics_steps(HIT_FRAMES)
	assert_eq(_plain.health.current, 100.0, "the shield took the hit")
	assert_almost_eq(_plain.health.shield, 10.0, TOLERANCE)
	assert_almost_eq(_armored.health.shield, 20.0, TOLERANCE, "armor first, then the shield")
	assert_string_contains(_plain.describe(), "shield 10")


func test_the_spend_keys_take_from_the_tester_pools() -> void:
	var stamina: ResourcePool = _scene.get_node("Stamina")
	var mana: ResourcePool = _scene.get_node("Mana")
	assert_eq(stamina.maximum, 100.0)
	assert_eq(mana.maximum, 50.0)
	assert_eq(mana.regen_rate, 4.0, "mana: 4 a second")
	assert_eq(mana.regen_delay, 0.0, "always")
	_press(CombatTestScene.SPEND_STAMINA_KEY)
	_press(CombatTestScene.SPEND_MANA_KEY)
	assert_almost_eq(stamina.current, 70.0, TOLERANCE)
	assert_almost_eq(mana.current, 40.0, TOLERANCE)
	await wait_process_frames(2)
	assert_string_contains(_overlay().text, "stamina 70 / 100")
	await _physics_steps(30)
	assert_almost_eq(stamina.current, 70.0, TOLERANCE, "half a second on, stamina still waits")
	assert_gt(mana.current, 41.0, "while mana has been coming back all along")


func test_a_key_that_is_held_or_released_does_nothing_more() -> void:
	var echo := _key(CombatTestScene.SPEND_STAMINA_KEY)
	echo.echo = true
	_scene._unhandled_input(echo)
	var release := _key(CombatTestScene.SPEND_STAMINA_KEY)
	release.pressed = false
	_scene._unhandled_input(release)
	var stamina: ResourcePool = _scene.get_node("Stamina")
	assert_eq(stamina.current, 100.0)


func test_the_overlay_lists_the_keys() -> void:
	await wait_process_frames(2)
	var text := _overlay().text
	for expected: String in ["F physical hit", "G frost hit", "C critical hit", "E enemy hit", "1 bleed", "7 burn", "H heal", "I invulnerable", "B shield", "X spend stamina", "M spend mana", "stamina 100 / 100", "mana 50 / 50"]:
		assert_string_contains(text, expected)


func test_the_dummy_labels_spell_their_state_out() -> void:
	_press_status(STUN_INDEX)
	_plain.health.take_damage(_packet(26.5))
	await wait_process_frames(2)
	var label := _plain.get_node("Label") as Label3D
	for expected: String in ["Plain (ENEMY)", "hp 73.5 / 100", "armor 0, frost res 0", "speed 4", "stun 1.", "cannot move", "cannot act"]:
		assert_string_contains(label.text, expected)
	assert_string_contains((_neutral.get_node("Label") as Label3D).text, "Neutral (NEUTRAL_ANIMAL)")

	_plain.health.take_damage(_packet(500.0))
	await wait_process_frames(2)
	assert_string_contains(label.text, "dead")
	assert_does_not_have(label.text.split("\n"), "cannot act", "death ended the stun")


func test_the_health_bar_is_a_box_scaled_to_the_health_left() -> void:
	var bar := _bar(_plain)
	assert_is(bar.mesh, BoxMesh)
	assert_almost_eq(bar.scale.x, 1.0, TOLERANCE, "full")
	assert_eq((bar.material_override as StandardMaterial3D).albedo_color, Palette.role(&"health", WorldState.state), "in the health colour of the palette")
	_plain.health.take_damage(_packet(25.0))
	assert_almost_eq(bar.scale.x, 0.75, TOLERANCE)
	_plain.health.heal(10.0)
	assert_almost_eq(bar.scale.x, 0.85, TOLERANCE)
	_plain.health.take_damage(_packet(500.0))
	assert_false(bar.visible, "nothing left to show")
	_plain.health.revive()
	assert_true(bar.visible)
	assert_almost_eq(bar.scale.x, 1.0, TOLERANCE)


func test_the_labels_stand_above_the_dummies_and_clear_of_each_other() -> void:
	# Nobody can look at the scene from the command line, so the layout is measured. Every
	# status effect and a shield make the labels as tall and as wide as they get.
	for index: int in CombatTestScene.STATUS_KEYS.size():
		_press_status(index)
	_press(CombatTestScene.SHIELD_KEY)
	_press(CombatTestScene.INVULNERABLE_KEY)
	for dummy: CombatDummy in _dummies:
		# A billboard reports a box that holds the text at any angle. Facing forward, as the
		# fixed camera sees it, the box is the text itself.
		(dummy.get_node("Label") as Label3D).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	await wait_process_frames(3)

	var spacing := _armored.position.x - _plain.position.x
	for dummy: CombatDummy in _dummies:
		var label := dummy.get_node("Label") as Label3D
		var body := dummy.get_node("Body") as BoxProp
		var bar := _bar(dummy)
		var box := label.get_aabb()
		assert_gt(label.text.split("\n").size(), 12, "%s shows every effect on a line of its own" % dummy.display_name)
		assert_gt(bar.position.y, body.size.y, "the bar hangs above the box")
		assert_gt(label.position.y + box.position.y, bar.position.y, "the text starts above the bar and grows upward")
		assert_lt(box.size.x, spacing, "and it is narrower than the gap to the next dummy")
		for corner: Vector3 in [Vector3(box.position.x, box.end.y, 0.0), Vector3(box.end.x, box.end.y, 0.0)]:
			assert_true(_is_in_picture(label.global_position + corner), "the top of the tallest label of %s is in the picture" % dummy.display_name)


func test_damage_numbers_rise_above_the_dummy_and_stay_under_its_label() -> void:
	var camera := _scene.get_node("Camera") as Camera3D
	for dummy: CombatDummy in _dummies:
		dummy.health.take_damage(_packet(20.0))
		(_numbers(dummy).get_child(0) as Label3D).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	await wait_process_frames(3)
	for dummy: CombatDummy in _dummies:
		var body := dummy.get_node("Body") as BoxProp
		var label := dummy.get_node("Label") as Label3D
		var numbers := _numbers(dummy)
		var number := numbers.get_child(0) as Label3D
		assert_gt(numbers.position.y, body.size.y, "a number starts above the box")
		# The upper edge of the number where its drift ends, against the lower edge of the
		# label. On screen y grows downward.
		var highest := numbers.global_position + Vector3.UP * (numbers.rise + number.get_aabb().end.y)
		assert_gt(camera.unproject_position(highest).y, camera.unproject_position(label.global_position).y, "and at the top of its drift it is still under the label of %s on screen" % dummy.display_name)


func test_the_camera_shows_the_dummies_the_marker_and_the_reach_of_a_hit() -> void:
	var camera := _scene.get_node("Camera") as Camera3D
	assert_eq(_viewport.get_camera_3d(), camera, "the scene's own camera draws it")
	for dummy: CombatDummy in _dummies:
		var body := dummy.get_node("Body") as BoxProp
		var half := body.size * 0.5
		for corner: Vector3 in [Vector3(-half.x, 0.0, half.z), Vector3(half.x, 0.0, half.z), Vector3(-half.x, body.size.y, -half.z), Vector3(half.x, body.size.y, -half.z)]:
			assert_true(_is_in_picture(dummy.global_position + corner), "%s is in the picture" % dummy.display_name)
		var numbers := _numbers(dummy)
		assert_true(_is_in_picture(numbers.global_position + Vector3.UP * numbers.rise), "and so is a damage number at the top of its drift")

	var marker := _scene.get_node("HitMarker") as Marker3D
	assert_true(_is_in_picture(marker.global_position), "the hit marker is in the picture")
	var tester := marker.get_node("Tester") as BoxActor
	assert_eq(tester.global_position, marker.global_position, "a box stands on the marker")
	var to_dummies := (_armored.global_position - marker.global_position).normalized()
	assert_almost_eq((-tester.global_basis.z).dot(to_dummies), 1.0, TOLERANCE, "with its nose toward the dummies: in front of the marker is where they stand")
	var reach := _scene.hit_size * 0.5
	for side: float in [-1.0, 1.0]:
		for depth: float in [-1.0, 1.0]:
			var corner := Vector3(side * reach.x, 0.0, -_scene.hit_distance + depth * reach.z)
			assert_true(_is_in_picture(marker.global_transform * corner), "the reach of a hit is in the picture")
	for dummy: CombatDummy in _dummies:
		var offset := marker.global_transform.affine_inverse() * dummy.global_position
		assert_lt(absf(offset.x) + 0.5, reach.x, "%s stands inside the reach of a hit" % dummy.display_name)
		assert_lt(absf(offset.z + _scene.hit_distance) + 0.5, reach.z)


func _press(keycode: Key) -> void:
	_scene._unhandled_input(_key(keycode))


## Presses the number key of the status effect at [param index] of CombatTestScene.STATUSES.
func _press_status(index: int) -> void:
	_press(CombatTestScene.STATUS_KEYS[index])


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _packet(physical: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.physical = physical
	return info


func _numbers(dummy: CombatDummy) -> DebugDamageNumbers:
	return dummy.get_node("DamageNumbers")


func _overlay() -> Label:
	return _scene.get_node("Overlay/Label")


func _bar(dummy: CombatDummy) -> MeshInstance3D:
	return dummy.get_node("HealthBar")


## Whether the scene's camera shows the world position [param point].
func _is_in_picture(point: Vector3) -> bool:
	return (_scene.get_node("Camera") as Camera3D).is_position_in_frustum(point)


func _physics_steps(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
