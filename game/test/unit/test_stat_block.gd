extends GutTest
## The stat block: a stat is (base + flat) * (1 + percent) over every source, a source is
## removed as a whole, every change is announced, and a copy shares nothing with its original.

const TOLERANCE := 0.0001


func test_a_stat_without_modifiers_is_its_base_value() -> void:
	var stats := _make({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 25.0})
	assert_eq(stats.get_stat(StatBlock.MAX_HEALTH), 100.0)
	assert_eq(stats.get_stat(StatBlock.ARMOR), 25.0)
	assert_eq(stats.get_base(StatBlock.ARMOR), 25.0)


func test_a_stat_that_is_left_out_is_worth_zero() -> void:
	var stats := _make({StatBlock.MAX_HEALTH: 100.0})
	assert_eq(stats.get_stat(StatBlock.FROST_RESISTANCE), 0.0)
	stats.add_modifier(&"gear", StatBlock.FROST_RESISTANCE, 60.0, 0.0)
	assert_eq(stats.get_stat(StatBlock.FROST_RESISTANCE), 60.0, "a flat modifier still counts")


func test_base_values_may_be_whole_numbers_and_string_keys() -> void:
	var stats := _make({"max_health": 100, "armor": 20})
	assert_eq(stats.get_stat(StatBlock.MAX_HEALTH), 100.0, "an int under a String key reads as the float under the StringName")
	assert_eq(stats.get_stat(StatBlock.ARMOR), 20.0)


func test_the_block_knows_the_ten_stats_of_the_gdd() -> void:
	var expected: Array[StringName] = [
		&"max_health", &"max_stamina", &"max_mana", &"armor", &"physical_bonus",
		&"frost_resistance", &"crit_chance", &"crit_multiplier", &"move_speed", &"attack_speed",
	]
	assert_eq(StatBlock.KEYS, expected)


func test_flat_is_added_before_percent_multiplies() -> void:
	var stats := _make({StatBlock.MAX_HEALTH: 100.0})
	stats.add_modifier(&"gear", StatBlock.MAX_HEALTH, 20.0, 0.0)
	assert_almost_eq(stats.get_stat(StatBlock.MAX_HEALTH), 120.0, TOLERANCE, "base + flat")
	stats.add_modifier(&"points", StatBlock.MAX_HEALTH, 0.0, 0.5)
	assert_almost_eq(stats.get_stat(StatBlock.MAX_HEALTH), 180.0, TOLERANCE, "(100 + 20) * (1 + 0.5)")


func test_modifiers_of_every_source_add_up() -> void:
	var stats := _make({StatBlock.MAX_HEALTH: 100.0})
	stats.add_modifier(&"equip:chest", StatBlock.MAX_HEALTH, 20.0, 0.0)
	stats.add_modifier(&"equip:ring", StatBlock.MAX_HEALTH, 10.0, 0.1)
	stats.add_modifier(&"points", StatBlock.MAX_HEALTH, 15.0, 0.0)
	stats.add_modifier(&"status:weak", StatBlock.MAX_HEALTH, 0.0, -0.3)
	stats.add_modifier(&"status:blessed", StatBlock.MAX_HEALTH, 0.0, 0.5)
	# (100 + 20 + 10 + 15) * (1 + 0.1 - 0.3 + 0.5)
	assert_almost_eq(stats.get_stat(StatBlock.MAX_HEALTH), 145.0 * 1.3, TOLERANCE)


func test_one_source_may_hold_several_modifiers_on_one_stat() -> void:
	# An item's implicit armor and its armor affix both go in under the item's slot.
	var stats := _make({StatBlock.ARMOR: 10.0})
	stats.add_modifier(&"equip:chest", StatBlock.ARMOR, 12.0, 0.0)
	stats.add_modifier(&"equip:chest", StatBlock.ARMOR, 8.0, 0.25)
	assert_almost_eq(stats.get_stat(StatBlock.ARMOR), 30.0 * 1.25, TOLERANCE, "the second does not replace the first")


func test_a_modifier_changes_its_own_stat_only() -> void:
	var stats := _make({StatBlock.MOVE_SPEED: 6.0, StatBlock.ATTACK_SPEED: 1.0})
	stats.add_modifier(&"status:slow", StatBlock.MOVE_SPEED, 0.0, -0.4)
	assert_almost_eq(stats.get_stat(StatBlock.MOVE_SPEED), 3.6, TOLERANCE, "6 * (1 - 0.4)")
	assert_eq(stats.get_stat(StatBlock.ATTACK_SPEED), 1.0)


func test_a_negative_flat_modifier_may_take_a_stat_below_zero() -> void:
	var stats := _make({})
	stats.add_modifier(&"status:weakened", StatBlock.PHYSICAL_BONUS, -0.2, 0.0)
	assert_almost_eq(stats.get_stat(StatBlock.PHYSICAL_BONUS), -0.2, TOLERANCE, "a damage penalty is a negative bonus")


func test_percent_below_minus_one_hundred_leaves_the_stat_at_zero() -> void:
	var stats := _make({StatBlock.MOVE_SPEED: 6.0})
	stats.add_modifier(&"status:slow", StatBlock.MOVE_SPEED, 0.0, -0.4)
	stats.add_modifier(&"status:frostbite", StatBlock.MOVE_SPEED, 0.0, -0.3)
	stats.add_modifier(&"status:bulwark", StatBlock.MOVE_SPEED, 0.0, -0.4)
	assert_eq(stats.get_stat(StatBlock.MOVE_SPEED), 0.0, "-110 % stops the actor; it does not walk it backwards")


func test_removing_a_source_takes_all_of_its_modifiers_and_no_others() -> void:
	var stats := _make({StatBlock.ARMOR: 10.0, StatBlock.MAX_HEALTH: 100.0})
	stats.add_modifier(&"equip:chest", StatBlock.ARMOR, 12.0, 0.0)
	stats.add_modifier(&"equip:chest", StatBlock.MAX_HEALTH, 0.0, 0.1)
	stats.add_modifier(&"equip:head", StatBlock.ARMOR, 5.0, 0.0)
	assert_true(stats.has_source(&"equip:chest"))

	stats.remove_source(&"equip:chest")
	assert_false(stats.has_source(&"equip:chest"))
	assert_true(stats.has_source(&"equip:head"), "the other source stays")
	assert_almost_eq(stats.get_stat(StatBlock.ARMOR), 15.0, TOLERANCE, "only the helmet is left on the armor")
	assert_almost_eq(stats.get_stat(StatBlock.MAX_HEALTH), 100.0, TOLERANCE, "and nothing on the health")

	stats.remove_source(&"equip:head")
	assert_eq(stats.get_stat(StatBlock.ARMOR), 10.0, "back to the base value, exactly")


func test_adding_and_removing_leaves_the_block_as_it_was() -> void:
	var stats := _make({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 10.0, StatBlock.MOVE_SPEED: 6.0})
	var before: Dictionary = {}
	for stat: StringName in StatBlock.KEYS:
		before[stat] = stats.get_stat(stat)
	stats.add_modifier(&"equip:chest", StatBlock.MAX_HEALTH, 30.0, 0.1)
	stats.add_modifier(&"equip:chest", StatBlock.ARMOR, 40.0, 0.0)
	stats.add_modifier(&"equip:chest", StatBlock.MOVE_SPEED, 0.0, -0.05)
	stats.remove_source(&"equip:chest")
	for stat: StringName in StatBlock.KEYS:
		assert_eq(stats.get_stat(stat), before[stat], "%s is what it was" % stat)


func test_every_change_is_announced() -> void:
	var stats := _make({StatBlock.ARMOR: 10.0})
	watch_signals(stats)
	stats.add_modifier(&"gear", StatBlock.ARMOR, 5.0, 0.0)
	assert_signal_emit_count(stats, "stats_changed", 1, "a modifier was added")
	stats.remove_source(&"gear")
	assert_signal_emit_count(stats, "stats_changed", 2, "a source was removed")
	stats.remove_source(&"gear")
	assert_signal_emit_count(stats, "stats_changed", 2, "removing a source that holds nothing changes nothing")
	stats.set_base(StatBlock.ARMOR, 20.0)
	assert_signal_emit_count(stats, "stats_changed", 3, "a base value was set")
	assert_eq(stats.get_stat(StatBlock.ARMOR), 20.0)
	stats.base = {StatBlock.ARMOR: 30.0}
	assert_signal_emit_count(stats, "stats_changed", 4, "the base values were replaced")
	assert_eq(stats.get_stat(StatBlock.ARMOR), 30.0)


func test_assigning_base_takes_a_copy_of_the_dictionary() -> void:
	# An enemy's block is filled from the base_stats of its EnemyData, which every enemy of
	# that kind reads.
	var shared := {StatBlock.MAX_HEALTH: 100.0}
	var first := _make(shared)
	var second := _make(shared)
	first.set_base(StatBlock.MAX_HEALTH, 250.0)
	assert_eq(second.get_stat(StatBlock.MAX_HEALTH), 100.0, "the other block keeps its value")
	assert_eq(shared[StatBlock.MAX_HEALTH], 100.0, "and so does the dictionary both were filled from")


func test_a_duplicate_shares_nothing_with_its_original() -> void:
	var template := _make({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 10.0})
	template.add_modifier(&"equip:chest", StatBlock.ARMOR, 5.0, 0.0)
	var copy := template.duplicate() as StatBlock
	assert_eq(copy.get_stat(StatBlock.MAX_HEALTH), 100.0, "the copy starts with the base values")
	assert_eq(copy.get_stat(StatBlock.ARMOR), 10.0, "and without the modifiers of the original")

	watch_signals(template)
	copy.set_base(StatBlock.MAX_HEALTH, 40.0)
	copy.add_modifier(&"status:armor_break", StatBlock.ARMOR, 0.0, -0.5)
	assert_eq(template.get_stat(StatBlock.MAX_HEALTH), 100.0, "a base value set on the copy stays on the copy")
	assert_eq(template.get_stat(StatBlock.ARMOR), 15.0, "and so does a modifier")
	assert_signal_emit_count(template, "stats_changed", 0, "the original announces nothing")


func _make(base: Dictionary) -> StatBlock:
	var stats := StatBlock.new()
	stats.base = base
	return stats
