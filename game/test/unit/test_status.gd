extends GutTest
## Status effects: the seven data files, applying and running out, modifiers under the
## status source, damage ticks through Health, stun and root, the three stack rules, and
## effects that arrive with a hit.
##
## Most tests run the manager's clock by hand, one physics tick at a time, so that four
## seconds of bleeding take no four seconds. The last tests let real physics ticks run it.

const BLEED: StatusEffectData = preload("res://data/status/bleed.tres")
const SLOW: StatusEffectData = preload("res://data/status/slow.tres")
const STUN: StatusEffectData = preload("res://data/status/stun.tres")
const ROOT: StatusEffectData = preload("res://data/status/root.tres")
const ARMOR_BREAK: StatusEffectData = preload("res://data/status/armor_break.tres")
const FROSTBITE: StatusEffectData = preload("res://data/status/frostbite.tres")
const BURN: StatusEffectData = preload("res://data/status/burn.tres")
const ALL: Array[StatusEffectData] = [BLEED, SLOW, STUN, ROOT, ARMOR_BREAK, FROSTBITE, BURN]

const TOLERANCE := 0.0001
## One physics tick in seconds.
const TICK := 1.0 / 60.0
## Physics ticks per second.
const TICKS_PER_SECOND := 60
## Base stats of the actor most tests use: no defences, so a tick costs what the data says.
const PLAIN := {&"max_health": 100.0, &"armor": 0.0, &"move_speed": 6.0}
## Physics frames the tests on real ticks wait for an effect of a tenth of a second.
const REAL_FRAMES := 12


# --- The data ---


func test_the_seven_effects_hold_the_values_of_the_spec() -> void:
	_assert_data(BLEED, &"bleed", 4.0, 0.5, 3.0, 0.0, false, false)
	_assert_data(SLOW, &"slow", 3.0, 0.0, 0.0, 0.0, false, false)
	_assert_data(STUN, &"stun", 1.5, 0.0, 0.0, 0.0, true, false)
	_assert_data(ROOT, &"root", 2.0, 0.0, 0.0, 0.0, false, true)
	_assert_data(ARMOR_BREAK, &"armor_break", 6.0, 0.0, 0.0, 0.0, false, false)
	_assert_data(FROSTBITE, &"frostbite", 4.0, 0.5, 0.0, 2.0, false, false)
	_assert_data(BURN, &"burn", 3.0, 0.5, 4.0, 0.0, false, false)

	_assert_modifier(SLOW, StatBlock.MOVE_SPEED, -0.4)
	_assert_modifier(ARMOR_BREAK, StatBlock.ARMOR, -0.5)
	_assert_modifier(FROSTBITE, StatBlock.MOVE_SPEED, -0.3)
	for effect: StatusEffectData in [BLEED, STUN, ROOT, BURN]:
		assert_eq(effect.modifiers.size(), 0, "%s changes no stat" % effect.id)


func test_the_stack_rules_of_the_seven_effects() -> void:
	assert_eq(BLEED.stack_rule, StatusEffectData.StackRule.INDEPENDENT, "bleeds run side by side")
	assert_eq(BURN.stack_rule, StatusEffectData.StackRule.STACK_DURATION, "a burn burns longer")
	for effect: StatusEffectData in [SLOW, STUN, ROOT, ARMOR_BREAK, FROSTBITE]:
		assert_eq(effect.stack_rule, StatusEffectData.StackRule.REFRESH, "%s starts over" % effect.id)


# --- Applying and running out ---


func test_an_effect_is_applied_and_runs_out() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	assert_false(actor.status.has_effect(&"slow"))

	actor.status.apply(SLOW)
	assert_true(actor.status.has_effect(&"slow"))
	assert_eq(actor.status.get_stacks(&"slow"), 1)
	assert_almost_eq(actor.status.get_time_left(&"slow"), 3.0, TOLERANCE)
	assert_signal_emit_count(actor.status, "effect_applied", 1)
	assert_signal_emitted_with_parameters(actor.status, "effect_applied", [&"slow"])

	_advance(actor, 2.9)
	assert_true(actor.status.has_effect(&"slow"), "still on just before its time")
	assert_signal_emit_count(actor.status, "effect_removed", 0)
	_advance(actor, 0.2)
	assert_false(actor.status.has_effect(&"slow"), "gone after it")
	assert_eq(actor.status.get_stacks(&"slow"), 0)
	assert_eq(actor.status.get_time_left(&"slow"), 0.0)
	assert_signal_emit_count(actor.status, "effect_removed", 1)
	assert_signal_emitted_with_parameters(actor.status, "effect_removed", [&"slow"])


func test_an_effect_ends_on_the_tick_its_time_is_up() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(STUN)
	var ticks := roundi(STUN.duration * TICKS_PER_SECOND)
	for i: int in ticks - 1:
		actor.status.advance(TICK)
	assert_true(actor.status.has_effect(&"stun"), "on for 89 of its 90 ticks")
	actor.status.advance(TICK)
	assert_false(actor.status.has_effect(&"stun"), "gone on the 90th")


func test_effects_are_listed_in_the_order_they_arrived() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(ROOT)
	actor.status.apply(SLOW)
	var expected: Array[StringName] = [&"root", &"slow"]
	assert_eq(actor.status.get_effect_ids(), expected)


func test_an_effect_without_an_id_or_a_duration_is_not_applied() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	actor.status.apply(null)
	actor.status.apply(_effect(&"", 3.0, StatusEffectData.StackRule.REFRESH))
	actor.status.apply(_effect(&"nothing", 0.0, StatusEffectData.StackRule.REFRESH))
	assert_eq(actor.status.get_effect_ids().size(), 0)
	assert_signal_emit_count(actor.status, "effect_applied", 0)


func test_remove_ends_one_effect_and_clear_ends_all() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(SLOW)
	actor.status.apply(STUN)
	actor.status.apply(BLEED)
	actor.status.apply(BLEED)
	watch_signals(actor.status)

	actor.status.remove(&"bleed")
	assert_false(actor.status.has_effect(&"bleed"), "both copies are gone")
	assert_signal_emit_count(actor.status, "effect_removed", 1)
	actor.status.remove(&"bleed")
	assert_signal_emit_count(actor.status, "effect_removed", 1, "removing what is not there announces nothing")

	actor.status.clear()
	assert_eq(actor.status.get_effect_ids().size(), 0)
	assert_signal_emit_count(actor.status, "effect_removed", 3)
	assert_true(actor.status.can_act, "the stun went with the rest")
	assert_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0, "and the slow took its modifier along")


# --- Modifiers ---


func test_modifiers_go_in_under_the_status_source_and_come_out_again() -> void:
	var actor := _actor({&"max_health": 100.0, &"armor": 100.0, &"move_speed": 6.0})
	actor.status.apply(SLOW)
	assert_true(actor.stats.has_source(&"status:slow"))
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 3.6, TOLERANCE, "slow: move speed -40 %")
	_advance(actor, SLOW.duration)
	assert_false(actor.stats.has_source(&"status:slow"))
	assert_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0, "back to the base value, exactly")

	actor.status.apply(ARMOR_BREAK)
	assert_almost_eq(actor.stats.get_stat(StatBlock.ARMOR), 50.0, TOLERANCE, "armor break: armor -50 %")
	_advance(actor, ARMOR_BREAK.duration)
	assert_eq(actor.stats.get_stat(StatBlock.ARMOR), 100.0)

	actor.status.apply(FROSTBITE)
	assert_true(actor.stats.has_source(&"status:frostbite"))
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 4.2, TOLERANCE, "frostbite: move speed -30 %")
	_advance(actor, FROSTBITE.duration)
	assert_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0)


func test_slow_and_frostbite_slow_together() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(SLOW)
	actor.status.apply(FROSTBITE)
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0 * 0.3, TOLERANCE, "-40 % and -30 % add up to -70 %")
	_advance(actor, SLOW.duration)
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0 * 0.7, TOLERANCE, "the slow ran out, the frostbite is still on")


func test_armor_break_lets_more_of_a_hit_through() -> void:
	var actor := _actor({&"max_health": 100.0, &"armor": 100.0})
	actor.health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(actor.health.current, 85.0, TOLERANCE, "100 armor: 15 of 30")
	actor.status.apply(ARMOR_BREAK)
	actor.health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(actor.health.current, 65.0, TOLERANCE, "50 armor: 20 of 30")


func test_modifiers_move_along_when_the_actor_gets_another_stat_block() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(SLOW)
	var first := actor.stats
	var second := StatBlock.new()
	second.base = {&"move_speed": 10.0}
	actor.status.stats = second
	assert_false(first.has_source(&"status:slow"), "the old block is left clean")
	assert_almost_eq(second.get_stat(StatBlock.MOVE_SPEED), 6.0, TOLERANCE, "the new one is slowed")
	_advance(actor, SLOW.duration)
	assert_eq(second.get_stat(StatBlock.MOVE_SPEED), 10.0)


# --- Damage over time ---


func test_bleed_ticks_every_half_second_through_health() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.health)
	actor.status.apply(BLEED)
	_advance_ticks(actor, 29)
	assert_eq(actor.health.current, 100.0, "no tick before the first half second is over")
	_advance_ticks(actor, 1)
	assert_almost_eq(actor.health.current, 97.0, TOLERANCE, "the first tick: 3 physical")
	_advance(actor, 0.5)
	assert_almost_eq(actor.health.current, 94.0, TOLERANCE, "the second")

	_advance(actor, 3.0)
	assert_false(actor.status.has_effect(&"bleed"), "after 4 s the bleed is over")
	assert_almost_eq(actor.health.current, 76.0, TOLERANCE, "eight ticks in all, the last one as it ends")
	assert_signal_emit_count(actor.health, "damaged", 8)
	_advance(actor, 2.0)
	assert_almost_eq(actor.health.current, 76.0, TOLERANCE, "and nothing after that")


func test_frostbite_ticks_frost_and_burn_ticks_physical() -> void:
	var frozen := _actor(PLAIN)
	frozen.status.apply(FROSTBITE)
	_advance(frozen, FROSTBITE.duration)
	assert_almost_eq(frozen.health.current, 100.0 - 8 * 2.0, TOLERANCE, "frostbite: 2 frost per 0.5 s for 4 s")

	var burning := _actor(PLAIN)
	burning.status.apply(BURN)
	_advance(burning, BURN.duration)
	assert_almost_eq(burning.health.current, 100.0 - 6 * 4.0, TOLERANCE, "burn: 4 physical per 0.5 s for 3 s")


func test_ticks_are_mitigated_by_the_matching_defence() -> void:
	var armored := _actor({&"max_health": 100.0, &"armor": 100.0})
	armored.status.apply(BLEED)
	armored.status.apply(FROSTBITE)
	_advance(armored, 4.0)
	assert_almost_eq(armored.health.current, 100.0 - 8 * 1.5 - 8 * 2.0, TOLERANCE, "armor halves the bleed and leaves the frostbite whole")

	var resistant := _actor({&"max_health": 100.0, &"frost_resistance": 100.0})
	resistant.status.apply(BLEED)
	resistant.status.apply(FROSTBITE)
	_advance(resistant, 4.0)
	assert_almost_eq(resistant.health.current, 100.0 - 8 * 3.0 - 8 * 1.0, TOLERANCE, "frost resistance halves the frostbite and leaves the bleed whole")


func test_a_tick_names_its_effect_and_the_actor_that_caused_it() -> void:
	var actor := _actor(PLAIN)
	var attacker := Node.new()
	add_child_autofree(attacker)
	watch_signals(actor.health)
	actor.status.apply(BLEED, attacker)
	_advance(actor, 0.5)
	var damaged: Array = get_signal_parameters(actor.health, "damaged")
	var info := damaged[0] as DamageInfo
	assert_eq(info.skill_id, &"status:bleed")
	assert_eq(info.source, attacker)
	assert_true(StatusEffectManager.is_tick(info), "a tick can be told from a hit")
	var hit := _packet(5.0, 0.0)
	hit.skill_id = &"lunge"
	assert_false(StatusEffectManager.is_tick(hit))
	assert_false(StatusEffectManager.is_tick(_packet(5.0, 0.0)))


func test_a_tick_survives_the_actor_that_caused_it() -> void:
	var actor := _actor(PLAIN)
	var attacker := Node.new()
	add_child(attacker)
	actor.status.apply(BLEED, attacker)
	attacker.free()
	watch_signals(actor.health)
	_advance(actor, 0.5)
	assert_almost_eq(actor.health.current, 97.0, TOLERANCE, "the bleed goes on")
	var damaged: Array = get_signal_parameters(actor.health, "damaged")
	assert_null((damaged[0] as DamageInfo).source, "with nobody left to name")


func test_ticks_stop_while_the_actor_is_invulnerable() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(BLEED)
	actor.health.invulnerable = true
	_advance(actor, 1.0)
	assert_eq(actor.health.current, 100.0, "two ticks fell into the invulnerable second and did nothing")
	actor.health.invulnerable = false
	_advance(actor, 3.0)
	assert_almost_eq(actor.health.current, 82.0, TOLERANCE, "the other six landed")


func test_a_tick_that_kills_ends_every_effect() -> void:
	var actor := _actor({&"max_health": 5.0, &"move_speed": 6.0})
	actor.status.apply(SLOW)
	actor.status.apply(BLEED)
	actor.status.apply(STUN)
	watch_signals(actor.status)
	watch_signals(actor.health)
	_advance(actor, 1.0)
	assert_true(actor.health.is_dead, "the second tick of the bleed kills at 5 health")
	assert_signal_emit_count(actor.health, "died", 1)
	assert_eq(actor.status.get_effect_ids().size(), 0, "death ends the bleed and everything else")
	assert_signal_emit_count(actor.status, "effect_removed", 3)
	assert_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0, "modifiers included")
	assert_true(actor.status.can_act)
	_advance(actor, 5.0)
	assert_signal_emit_count(actor.health, "damaged", 2, "and no tick comes after it")


func test_the_dead_take_no_effects() -> void:
	var actor := _actor(PLAIN)
	actor.health.take_damage(_packet(100.0, 0.0))
	watch_signals(actor.status)
	actor.status.apply(SLOW)
	assert_false(actor.status.has_effect(&"slow"))
	assert_signal_emit_count(actor.status, "effect_applied", 0)

	actor.health.revive()
	actor.status.apply(SLOW)
	assert_true(actor.status.has_effect(&"slow"), "revived, it does again")


# --- Stun and root ---


func test_stun_blocks_acting_and_moving() -> void:
	var actor := _actor(PLAIN)
	assert_true(actor.status.can_act)
	assert_true(actor.status.can_move)
	actor.status.apply(STUN)
	assert_false(actor.status.can_act, "a stunned actor cannot act")
	assert_false(actor.status.can_move, "nor move")
	_advance(actor, STUN.duration)
	assert_true(actor.status.can_act, "after 1.5 s it can again")
	assert_true(actor.status.can_move)


func test_root_blocks_moving_only() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(ROOT)
	assert_false(actor.status.can_move, "a rooted actor cannot move")
	assert_true(actor.status.can_act, "but can still act")
	_advance(actor, ROOT.duration)
	assert_true(actor.status.can_move)


func test_the_other_effects_block_nothing() -> void:
	var actor := _actor(PLAIN)
	for effect: StatusEffectData in [BLEED, SLOW, ARMOR_BREAK, FROSTBITE, BURN]:
		actor.status.apply(effect)
	assert_true(actor.status.can_move)
	assert_true(actor.status.can_act)


func test_a_root_outlasts_a_stun() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(STUN)
	actor.status.apply(ROOT)
	_advance(actor, 1.75)
	assert_true(actor.status.can_act, "the stun is over after 1.5 s")
	assert_false(actor.status.can_move, "the root holds for 2 s")


# --- Stack rules ---


func test_refresh_starts_the_time_over() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	actor.status.apply(SLOW)
	_advance(actor, 2.0)
	actor.status.apply(SLOW)
	assert_eq(actor.status.get_stacks(&"slow"), 1, "still one copy")
	assert_almost_eq(actor.status.get_time_left(&"slow"), 3.0, TOLERANCE, "3 s again: not the 1 s that was left, not 4")
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 3.6, TOLERANCE, "the modifier is in once, not twice")
	assert_signal_emit_count(actor.status, "effect_applied", 2, "every application is announced")

	_advance(actor, 2.9)
	assert_true(actor.status.has_effect(&"slow"))
	_advance(actor, 0.2)
	assert_false(actor.status.has_effect(&"slow"))
	assert_signal_emit_count(actor.status, "effect_removed", 1)
	assert_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 6.0)


func test_stack_duration_adds_the_time() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(BURN)
	_advance(actor, 2.0)
	actor.status.apply(BURN)
	assert_eq(actor.status.get_stacks(&"burn"), 1, "still one copy")
	assert_almost_eq(actor.status.get_time_left(&"burn"), 4.0, TOLERANCE, "the 1 s that was left plus 3 s more")
	_advance(actor, 3.9)
	assert_true(actor.status.has_effect(&"burn"))
	_advance(actor, 0.2)
	assert_false(actor.status.has_effect(&"burn"))
	assert_almost_eq(actor.health.current, 100.0 - 12 * 4.0, TOLERANCE, "6 s of burning: twelve ticks at one rate")


func test_independent_copies_run_side_by_side() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	actor.status.apply(BLEED)
	_advance(actor, 1.0)
	assert_almost_eq(actor.health.current, 94.0, TOLERANCE, "one bleed: two ticks in the first second")

	actor.status.apply(BLEED)
	assert_eq(actor.status.get_stacks(&"bleed"), 2)
	assert_almost_eq(actor.status.get_time_left(&"bleed"), 4.0, TOLERANCE, "counted from the copy that lasts longest")
	_advance(actor, 1.0)
	assert_almost_eq(actor.health.current, 82.0, TOLERANCE, "two bleeds: four ticks in the second second")

	_advance(actor, 2.0)
	assert_eq(actor.status.get_stacks(&"bleed"), 1, "the first copy ran out after its own 4 s")
	assert_signal_emit_count(actor.status, "effect_removed", 0, "the effect is still on")
	assert_almost_eq(actor.health.current, 58.0, TOLERANCE, "eight more ticks while both ran")

	_advance(actor, 1.0)
	assert_false(actor.status.has_effect(&"bleed"), "the second copy ran out a second later")
	assert_signal_emit_count(actor.status, "effect_removed", 1)
	assert_almost_eq(actor.health.current, 52.0, TOLERANCE, "sixteen ticks in all, eight per copy")


func test_independent_copies_stack_their_modifiers_and_take_them_out_one_by_one() -> void:
	var weaken := _effect(&"weaken", 2.0, StatusEffectData.StackRule.INDEPENDENT)
	weaken.modifiers = [{"stat": StatBlock.ARMOR, "flat": -10.0, "percent": 0.0}]
	var actor := _actor({&"max_health": 100.0, &"armor": 50.0})
	actor.status.apply(weaken)
	_advance(actor, 1.0)
	actor.status.apply(weaken)
	assert_almost_eq(actor.stats.get_stat(StatBlock.ARMOR), 30.0, TOLERANCE, "two copies, two modifiers")
	_advance(actor, 1.0)
	assert_almost_eq(actor.stats.get_stat(StatBlock.ARMOR), 40.0, TOLERANCE, "the first copy took its own out")
	_advance(actor, 1.0)
	assert_eq(actor.stats.get_stat(StatBlock.ARMOR), 50.0)
	assert_false(actor.stats.has_source(&"status:weaken"))


func test_refreshing_a_ticking_effect_does_not_hold_its_ticks_back() -> void:
	# Reapplied faster than it ticks, an effect whose ticks started over with its time
	# would never deal any damage.
	var poison := _effect(&"poison", 2.0, StatusEffectData.StackRule.REFRESH)
	poison.tick_interval = 0.5
	poison.dot_physical = 1.0
	var actor := _actor(PLAIN)
	for i: int in 5:
		actor.status.apply(poison)
		_advance(actor, 0.4)
	assert_almost_eq(actor.health.current, 96.0, TOLERANCE, "2 s have passed: four ticks, on the half seconds")
	_advance(actor, 1.6)
	assert_false(actor.status.has_effect(&"poison"), "2 s after the last application it is over")
	assert_almost_eq(actor.health.current, 93.0, TOLERANCE, "with ticks at 2.5, 3 and 3.5 s")


func test_a_modifier_entry_may_leave_out_what_it_does_not_change() -> void:
	var chill := _effect(&"chill", 2.0, StatusEffectData.StackRule.REFRESH)
	chill.modifiers = [{"stat": StatBlock.MOVE_SPEED, "percent": -0.5}, {"stat": StatBlock.ARMOR, "flat": 5.0}]
	var actor := _actor(PLAIN)
	actor.status.apply(chill)
	assert_almost_eq(actor.stats.get_stat(StatBlock.MOVE_SPEED), 3.0, TOLERANCE)
	assert_almost_eq(actor.stats.get_stat(StatBlock.ARMOR), 5.0, TOLERANCE)


# --- Effects that arrive with a hit ---


func test_a_hit_that_lands_applies_the_effects_it_carries() -> void:
	var actor := _actor(PLAIN)
	var attacker := Node.new()
	add_child_autofree(attacker)
	var hit := _packet(10.0, 0.0)
	hit.source = attacker
	hit.effects.append(SLOW)
	hit.effects.append(BLEED)
	actor.health.take_damage(hit)
	assert_true(actor.status.has_effect(&"slow"))
	assert_true(actor.status.has_effect(&"bleed"))

	watch_signals(actor.health)
	_advance(actor, 0.5)
	var damaged: Array = get_signal_parameters(actor.health, "damaged")
	assert_eq((damaged[0] as DamageInfo).source, attacker, "the bleed is put down to the attacker of the hit")


func test_a_hit_that_does_not_land_leaves_no_effect() -> void:
	var actor := _actor(PLAIN)
	var hit := _packet(10.0, 0.0)
	hit.effects.append(STUN)

	actor.health.invulnerable = true
	actor.health.take_damage(hit)
	assert_true(actor.status.can_act, "dodged: no stun")

	actor.health.invulnerable = false
	var parry := func(_info: DamageInfo) -> bool: return true
	actor.health.interceptors.append(parry)
	actor.health.take_damage(hit)
	assert_true(actor.status.can_act, "parried: no stun")

	actor.health.interceptors.erase(parry)
	actor.health.take_damage(hit)
	assert_false(actor.status.can_act, "landed: stunned")


func test_a_hit_a_shield_absorbs_still_applies_its_effects() -> void:
	var actor := _actor(PLAIN)
	actor.health.add_shield(50.0, 5.0)
	var hit := _packet(10.0, 0.0)
	hit.effects.append(SLOW)
	actor.health.take_damage(hit)
	assert_eq(actor.health.current, 100.0)
	assert_true(actor.status.has_effect(&"slow"))


func test_a_killing_blow_applies_nothing() -> void:
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	var hit := _packet(500.0, 0.0)
	hit.effects.append(SLOW)
	hit.effects.append(BLEED)
	actor.health.take_damage(hit)
	assert_true(actor.health.is_dead)
	assert_eq(actor.status.get_effect_ids().size(), 0)
	assert_signal_emit_count(actor.status, "effect_applied", 0)


# --- All seven, and real ticks ---


func test_all_seven_effects_apply_tick_expire_and_remove_their_modifiers() -> void:
	for effect: StatusEffectData in ALL:
		var actor := _actor(PLAIN)
		var before: Dictionary = {}
		for stat: StringName in StatBlock.KEYS:
			before[stat] = actor.stats.get_stat(stat)
		watch_signals(actor.status)

		actor.status.apply(effect)
		assert_true(actor.status.has_effect(effect.id), "%s is applied" % effect.id)
		assert_eq(actor.stats.has_source(StatusEffectManager.source_key(effect.id)), not effect.modifiers.is_empty(), "%s has its modifiers in" % effect.id)
		assert_eq(actor.status.can_act, not effect.stun, "%s and acting" % effect.id)
		assert_eq(actor.status.can_move, not (effect.stun or effect.root), "%s and moving" % effect.id)

		_advance(actor, effect.duration)
		assert_false(actor.status.has_effect(effect.id), "%s has run out" % effect.id)
		assert_signal_emit_count(actor.status, "effect_removed", 1, "%s was announced as removed" % effect.id)
		var ticks := 0
		if effect.tick_interval > 0.0:
			ticks = roundi(effect.duration / effect.tick_interval)
		var dealt := ticks * (effect.dot_physical + effect.dot_frost)
		assert_almost_eq(actor.health.current, 100.0 - dealt, TOLERANCE, "%s dealt its ticks" % effect.id)
		assert_false(actor.stats.has_source(StatusEffectManager.source_key(effect.id)), "%s took its modifiers out" % effect.id)
		for stat: StringName in StatBlock.KEYS:
			assert_eq(actor.stats.get_stat(stat), before[stat], "%s left %s as it was" % [effect.id, stat])
		assert_true(actor.status.can_act)
		assert_true(actor.status.can_move)


func test_the_manager_finds_the_health_at_its_path() -> void:
	var root := Node.new()
	var health := Health.new()
	health.name = "Health"
	root.add_child(health)
	var status := StatusEffectManager.new()
	status.health_path = NodePath("../Health")
	root.add_child(status)
	add_child_autofree(root)
	assert_eq(status.health, health)


func test_effects_run_on_real_physics_ticks() -> void:
	var sting := _effect(&"sting", 0.1, StatusEffectData.StackRule.REFRESH)
	sting.tick_interval = 0.05
	sting.dot_physical = 1.0
	sting.stun = true
	var actor := _actor(PLAIN)
	watch_signals(actor.status)
	actor.status.apply(sting)
	assert_false(actor.status.can_act)
	for i: int in REAL_FRAMES:
		await get_tree().physics_frame
	assert_false(actor.status.has_effect(&"sting"), "a tenth of a second is six ticks")
	assert_signal_emit_count(actor.status, "effect_removed", 1)
	assert_almost_eq(actor.health.current, 98.0, TOLERANCE, "with two ticks of damage in them")
	assert_true(actor.status.can_act)


func test_nothing_runs_while_time_stands_still() -> void:
	var actor := _actor(PLAIN)
	actor.status.apply(BLEED)
	actor.status.advance(0.0)
	assert_almost_eq(actor.status.get_time_left(&"bleed"), 4.0, TOLERANCE, "a tick of no length, as Engine.time_scale 0 hands out, moves no clock")
	assert_eq(actor.health.current, 100.0)


func _assert_data(effect: StatusEffectData, id: StringName, duration: float, tick_interval: float, dot_physical: float, dot_frost: float, stun: bool, root: bool) -> void:
	assert_eq(effect.id, id)
	assert_eq(effect.duration, duration, "%s duration" % id)
	assert_eq(effect.tick_interval, tick_interval, "%s tick interval" % id)
	assert_eq(effect.dot_physical, dot_physical, "%s physical per tick" % id)
	assert_eq(effect.dot_frost, dot_frost, "%s frost per tick" % id)
	assert_eq(effect.stun, stun, "%s stuns" % id)
	assert_eq(effect.root, root, "%s roots" % id)


## Asserts that [param effect] has exactly one modifier: [param percent] on [param stat].
func _assert_modifier(effect: StatusEffectData, stat: StringName, percent: float) -> void:
	assert_eq(effect.modifiers.size(), 1, "%s has one modifier" % effect.id)
	var modifier: Dictionary = effect.modifiers[0]
	assert_eq(modifier.get("stat"), stat, "%s changes %s" % [effect.id, stat])
	assert_eq(modifier.get("flat"), 0.0, "%s adds nothing flat" % effect.id)
	assert_eq(modifier.get("percent"), percent, "%s percent" % effect.id)


func _effect(id: StringName, duration: float, rule: StatusEffectData.StackRule) -> StatusEffectData:
	var effect := StatusEffectData.new()
	effect.id = id
	effect.duration = duration
	effect.stack_rule = rule
	return effect


func _packet(physical: float, frost: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.physical = physical
	info.frost = frost
	return info


## An actor reduced to what status effects need, in the tree: a stat block, a health and a
## manager that are wired the way an actor wires them.
func _actor(base: Dictionary) -> StatusActor:
	var actor := StatusActor.new()
	actor.stats = StatBlock.new()
	actor.stats.base = base
	var root := Node.new()
	actor.health = Health.new()
	actor.health.stats = actor.stats
	root.add_child(actor.health)
	actor.status = StatusEffectManager.new()
	actor.status.stats = actor.stats
	actor.status.health = actor.health
	root.add_child(actor.status)
	add_child_autofree(root)
	return actor


## Runs the manager of [param actor] on by [param seconds], one physics tick at a time.
func _advance(actor: StatusActor, seconds: float) -> void:
	_advance_ticks(actor, roundi(seconds * TICKS_PER_SECOND))


func _advance_ticks(actor: StatusActor, ticks: int) -> void:
	for i: int in ticks:
		actor.status.advance(TICK)


class StatusActor:
	extends RefCounted

	var stats: StatBlock
	var health: Health
	var status: StatusEffectManager
