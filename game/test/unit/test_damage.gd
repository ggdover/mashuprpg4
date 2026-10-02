extends GutTest
## The damage pipeline: the packet and its crit roll, mitigation by armor and frost
## resistance, Health with its interceptors and shields, the debug damage numbers, and
## hitboxes finding hurtboxes on real physics frames.

## How a hitbox test brings the physics engine to a standstill, if at all.
enum Standstill {
	NONE,
	## Engine.time_scale is 0 from before the hitbox is switched on.
	STOPPED_TIME,
	## The tree is paused right after the hitbox is switched on.
	PAUSE,
	## The tree is paused in a deferred call made right after the hitbox is switched on.
	## From inside a physics tick that is when every node has had its turn in the tick.
	LATE_PAUSE,
}

const TOLERANCE := 0.0001
## One physics tick in seconds, for the tests that run a clock by hand.
const TICK := 1.0 / 60.0
## Physics frames for the engine to find what overlaps and for a hitbox to act on it: one
## tick to find it, one to hit, plus spare.
const HIT_FRAMES := 4
## Physics frames an active hitbox is left overlapping its targets: more than enough for a
## second hit to land, if the hitbox dealt one.
const ACTIVE_FRAMES := 12
## Rolls for the tests that look at what the crit roll can produce.
const ROLLS := 400
## Where a target stands that no hitbox of these tests reaches, in metres from the origin.
const FAR_AWAY := 10.0
## Damage of the hit the hitbox tests deal.
const HIT_DAMAGE := 10.0
## The key of the input events the tests send themselves. No action is bound to it.
const TAP_KEY := KEY_F24

## Whether the last hitbox a test moved and switched on in one go was inside a physics tick
## at that moment.
var _switched_on_in_a_tick := false


func after_each() -> void:
	randomize()
	Engine.time_scale = 1.0
	get_tree().paused = false


# --- DamageInfo ---


func test_total_is_physical_plus_frost() -> void:
	var info := _packet(12.0, 5.5)
	assert_almost_eq(info.total(), 17.5, TOLERANCE)


func test_a_new_packet_is_empty() -> void:
	var info := DamageInfo.new()
	assert_eq(info.total(), 0.0)
	assert_null(info.source)
	assert_false(info.is_crit)
	assert_eq(info.knockback, Vector3.ZERO)
	assert_eq(info.effects.size(), 0)
	assert_eq(info.skill_id, &"")


func test_a_copy_is_a_packet_of_its_own() -> void:
	var slow: StatusEffectData = load("res://data/status/slow.tres")
	var info := _packet(12.0, 5.0)
	info.source = self
	info.is_crit = true
	info.knockback = Vector3(1.0, 0.0, 2.0)
	info.effects.append(slow)
	info.skill_id = &"lunge"

	var copy := info.copy()
	assert_eq(copy.physical, 12.0)
	assert_eq(copy.frost, 5.0)
	assert_eq(copy.source, self)
	assert_true(copy.is_crit)
	assert_eq(copy.knockback, Vector3(1.0, 0.0, 2.0))
	assert_eq(copy.effects, info.effects)
	assert_eq(copy.skill_id, &"lunge")

	copy.physical = 1.0
	copy.effects.clear()
	assert_eq(info.physical, 12.0, "changing the copy leaves the original alone")
	assert_eq(info.effects.size(), 1, "and so does emptying its effects")


func test_a_hit_outlives_the_actor_that_dealt_it() -> void:
	# An arrow can land after the archer has died and been freed.
	var archer := Node.new()
	add_child(archer)
	var info := _packet(30.0, 0.0)
	info.source = archer
	archer.free()

	var copy := info.copy()
	assert_null(copy.source, "a copy names nobody once the attacker is gone")
	assert_eq(copy.physical, 30.0)

	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.take_damage(info)
	assert_almost_eq(health.current, 70.0, TOLERANCE, "the hit still lands")
	var damaged: Array = get_signal_parameters(health, "damaged")
	assert_null((damaged[0] as DamageInfo).source)


func test_from_stats_applies_the_multiplier_and_the_physical_bonus() -> void:
	var stats := _stats({StatBlock.PHYSICAL_BONUS: 0.25, StatBlock.CRIT_MULTIPLIER: 2.0})
	var info := DamageInfo.from_stats(stats, 40.0, 10.0, 1.5)
	assert_almost_eq(info.physical, 40.0 * 1.5 * 1.25, TOLERANCE, "base * multiplier * (1 + physical_bonus)")
	assert_almost_eq(info.frost, 10.0 * 1.5, TOLERANCE, "the physical bonus leaves frost alone")
	assert_false(info.is_crit, "no crit without a crit chance")


func test_from_stats_reads_the_bonus_with_its_modifiers() -> void:
	var stats := _stats({StatBlock.PHYSICAL_BONUS: 0.1})
	stats.add_modifier(&"points", StatBlock.PHYSICAL_BONUS, 0.15, 0.0)
	var info := DamageInfo.from_stats(stats, 100.0, 0.0, 1.0)
	assert_almost_eq(info.physical, 125.0, TOLERANCE)


func test_from_stats_without_stats_is_base_times_multiplier() -> void:
	var info := DamageInfo.from_stats(null, 40.0, 10.0, 2.0)
	assert_almost_eq(info.physical, 80.0, TOLERANCE)
	assert_almost_eq(info.frost, 20.0, TOLERANCE)
	assert_false(info.is_crit)


func test_a_crit_chance_of_zero_never_crits() -> void:
	var stats := _stats({StatBlock.CRIT_CHANCE: 0.0, StatBlock.CRIT_MULTIPLIER: 2.0})
	var crits := 0
	var highest := 0.0
	for i: int in ROLLS:
		var info := DamageInfo.from_stats(stats, 10.0, 0.0, 1.0)
		crits += int(info.is_crit)
		highest = maxf(highest, info.physical)
	assert_eq(crits, 0)
	assert_almost_eq(highest, 10.0, TOLERANCE, "and no roll deals more than the plain hit")


func test_a_crit_chance_of_one_always_crits_by_the_multiplier() -> void:
	var stats := _stats({StatBlock.CRIT_CHANCE: 1.0, StatBlock.CRIT_MULTIPLIER: 2.5})
	var crits := 0
	var lowest := INF
	for i: int in ROLLS:
		var info := DamageInfo.from_stats(stats, 10.0, 4.0, 1.0)
		crits += int(info.is_crit)
		lowest = minf(lowest, info.physical)
		assert_almost_eq(info.frost, 10.0, TOLERANCE, "the crit multiplies frost too")
	assert_eq(crits, ROLLS)
	assert_almost_eq(lowest, 25.0, TOLERANCE, "every roll deals the plain hit times the crit multiplier")


func test_a_crit_roll_lands_on_the_plain_hit_or_on_the_multiplied_one() -> void:
	seed(20261002)
	var stats := _stats({StatBlock.CRIT_CHANCE: 0.5, StatBlock.CRIT_MULTIPLIER: 2.0})
	var crits := 0
	var strays := 0
	for i: int in ROLLS:
		var info := DamageInfo.from_stats(stats, 10.0, 0.0, 1.0)
		var expected := 20.0 if info.is_crit else 10.0
		if not is_equal_approx(info.physical, expected):
			strays += 1
		crits += int(info.is_crit)
	assert_eq(strays, 0, "a hit is worth 10, or 20 when it is flagged as a crit, and nothing else")
	assert_between(crits, int(ROLLS * 0.35), int(ROLLS * 0.65), "about half of the rolls crit at a chance of 0.5")


func test_a_crit_multiplier_below_one_counts_as_one() -> void:
	# A block without a crit_multiplier reads 0 for it. A crit must not wipe the hit out.
	var stats := _stats({StatBlock.CRIT_CHANCE: 1.0})
	var info := DamageInfo.from_stats(stats, 10.0, 0.0, 1.0)
	assert_true(info.is_crit)
	assert_almost_eq(info.physical, 10.0, TOLERANCE, "a crit never deals less than the plain hit")


# --- Mitigation ---


func test_the_armor_formula_at_0_and_at_100_armor() -> void:
	assert_almost_eq(Health.mitigate(40.0, 0.0), 40.0, TOLERANCE, "no armor, no reduction")
	assert_almost_eq(Health.mitigate(40.0, 100.0), 20.0, TOLERANCE, "100 armor halves: 40 * 100 / 200")
	assert_almost_eq(Health.mitigate(40.0, 300.0), 10.0, TOLERANCE, "300 armor quarters: 40 * 100 / 400")
	assert_almost_eq(Health.mitigate(40.0, 50.0), 40.0 * 100.0 / 150.0, TOLERANCE)


func test_mitigation_never_turns_a_hit_into_healing_and_never_divides_by_zero() -> void:
	assert_almost_eq(Health.mitigate(40.0, -100.0), 40.0, TOLERANCE, "armor below zero counts as none")
	assert_almost_eq(Health.mitigate(40.0, -250.0), 40.0, TOLERANCE)
	assert_eq(Health.mitigate(-40.0, 0.0), 0.0, "an amount below zero counts as none")


func test_armor_reduces_physical_damage_taken() -> void:
	var unarmored := _health({StatBlock.MAX_HEALTH: 100.0})
	var armored := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	unarmored.take_damage(_packet(40.0, 0.0))
	armored.take_damage(_packet(40.0, 0.0))
	assert_almost_eq(unarmored.current, 60.0, TOLERANCE, "0 armor takes the full 40")
	assert_almost_eq(armored.current, 80.0, TOLERANCE, "100 armor takes 20")


func test_each_defence_reduces_its_own_damage_type_only() -> void:
	var armored := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	var resistant := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.FROST_RESISTANCE: 100.0})
	armored.take_damage(_packet(0.0, 40.0))
	resistant.take_damage(_packet(40.0, 0.0))
	assert_almost_eq(armored.current, 60.0, TOLERANCE, "armor does nothing against frost")
	assert_almost_eq(resistant.current, 60.0, TOLERANCE, "frost resistance does nothing against physical damage")

	resistant.take_damage(_packet(0.0, 40.0))
	assert_almost_eq(resistant.current, 40.0, TOLERANCE, "100 frost resistance halves frost")


func test_a_mixed_hit_is_mitigated_part_by_part() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0, StatBlock.FROST_RESISTANCE: 300.0})
	watch_signals(health)
	health.take_damage(_packet(40.0, 40.0))
	assert_almost_eq(health.current, 70.0, TOLERANCE, "40 physical becomes 20, 40 frost becomes 10")
	var parameters: Array = get_signal_parameters(health, "damaged")
	assert_almost_eq(parameters[1] as float, 30.0, TOLERANCE, "the final amount is the sum after mitigation")


func test_mitigation_reads_the_armor_with_its_modifiers() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	health.stats.add_modifier(&"status:armor_break", StatBlock.ARMOR, 0.0, -0.5)
	health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(health.current, 80.0, TOLERANCE, "50 armor left: 30 * 100 / 150")


# --- Health ---


func test_health_starts_full_at_the_max_health_of_its_stats() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 120.0})
	assert_eq(health.maximum, 120.0)
	assert_eq(health.current, 120.0)
	assert_false(health.is_dead)
	assert_eq(health.shield, 0.0)


func test_a_hit_is_applied_and_announced() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	var info := _packet(30.0, 0.0)
	health.take_damage(info)
	assert_almost_eq(health.current, 70.0, TOLERANCE)
	assert_signal_emit_count(health, "damaged", 1)
	assert_signal_emit_count(health, "health_changed", 1)
	assert_signal_emit_count(health, "died", 0)
	var damaged: Array = get_signal_parameters(health, "damaged")
	assert_almost_eq((damaged[0] as DamageInfo).physical, 30.0, TOLERANCE, "damaged carries the packet")
	assert_almost_eq(damaged[1] as float, 30.0, TOLERANCE, "and the final amount")
	assert_signal_emitted_with_parameters(health, "health_changed", [health.current, 100.0])


func test_health_stops_at_zero_and_dies_once() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.take_damage(_packet(60.0, 0.0))
	assert_signal_emit_count(health, "died", 0, "still alive at 40")
	health.take_damage(_packet(500.0, 0.0))
	assert_eq(health.current, 0.0, "overkill stops at zero")
	assert_true(health.is_dead)
	assert_signal_emit_count(health, "died", 1)

	health.take_damage(_packet(10.0, 0.0))
	health.take_damage(_packet(10.0, 0.0))
	assert_signal_emit_count(health, "died", 1, "the dead do not die again")
	assert_signal_emit_count(health, "damaged", 2, "and take no further hits")


func test_a_hit_that_takes_exactly_the_rest_kills() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.take_damage(_packet(100.0, 0.0))
	assert_true(health.is_dead)
	assert_signal_emit_count(health, "died", 1)


func test_the_health_is_already_dead_when_the_last_hit_is_announced() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	var seen: Array[bool] = []
	health.damaged.connect(func(_info: DamageInfo, _amount: float) -> void: seen.append(health.is_dead))
	health.take_damage(_packet(30.0, 0.0))
	health.take_damage(_packet(100.0, 0.0))
	var expected: Array[bool] = [false, true]
	assert_eq(seen, expected, "a listener of damaged can tell a wound from the killing blow")


func test_a_listener_that_revives_on_the_killing_blow_keeps_the_actor_alive() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	var cheat_death := func(_info: DamageInfo, _amount: float) -> void:
		if health.is_dead:
			health.revive()
	health.damaged.connect(cheat_death)
	health.take_damage(_packet(500.0, 0.0))
	assert_false(health.is_dead)
	assert_eq(health.current, 100.0)
	assert_signal_emit_count(health, "died", 0, "nobody is told of a death that was undone")


func test_an_invulnerable_health_takes_nothing() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.invulnerable = true
	health.take_damage(_packet(30.0, 30.0))
	assert_eq(health.current, 100.0)
	assert_signal_emit_count(health, "damaged", 0)
	assert_signal_emit_count(health, "health_changed", 0)

	health.invulnerable = false
	health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(health.current, 70.0, TOLERANCE, "vulnerable again, it takes the hit")


func test_an_interceptor_can_cancel_a_hit() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	var seen: Array[DamageInfo] = []
	var parry := func(info: DamageInfo) -> bool:
		seen.append(info)
		return true
	health.interceptors.append(parry)
	health.take_damage(_packet(30.0, 0.0))
	assert_eq(seen.size(), 1, "the interceptor was asked")
	assert_eq(health.current, 100.0, "and its yes cancelled the hit")
	assert_signal_emit_count(health, "damaged", 0)
	assert_signal_emit_count(health, "health_changed", 0)

	health.interceptors.erase(parry)
	health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(health.current, 70.0, TOLERANCE, "without it the next hit lands")


func test_an_interceptor_can_change_a_hit_before_mitigation() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	watch_signals(health)
	var bulwark := func(info: DamageInfo) -> bool:
		info.physical *= 0.5
		return false
	health.interceptors.append(bulwark)
	var hit := _packet(40.0, 0.0)
	health.take_damage(hit)
	assert_almost_eq(health.current, 90.0, TOLERANCE, "40 halved to 20, then halved again by 100 armor")
	assert_eq(hit.physical, 40.0, "the packet the attacker holds is left as it was")
	var damaged: Array = get_signal_parameters(health, "damaged")
	assert_almost_eq((damaged[0] as DamageInfo).physical, 20.0, TOLERANCE, "damaged carries the packet as the interceptors left it")
	assert_almost_eq(damaged[1] as float, 10.0, TOLERANCE)


func test_interceptors_run_in_order_and_a_cancel_ends_the_run() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	var order: Array[String] = []
	health.interceptors.append(func(_info: DamageInfo) -> bool:
		order.append("first")
		return false)
	health.interceptors.append(func(_info: DamageInfo) -> bool:
		order.append("second")
		return true)
	health.interceptors.append(func(_info: DamageInfo) -> bool:
		order.append("third")
		return false)
	health.take_damage(_packet(30.0, 0.0))
	var expected: Array[String] = ["first", "second"]
	assert_eq(order, expected, "the third is never asked")
	assert_eq(health.current, 100.0)


func test_an_interceptor_may_take_itself_away_while_it_runs() -> void:
	# The shape of Parry: cancel the next hit, then be gone.
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	var parry := OneShotParry.new()
	parry.health = health
	health.interceptors.append(parry.intercept)
	var counter := func(_info: DamageInfo) -> bool:
		parry.later_calls += 1
		return false
	health.interceptors.append(counter)

	health.take_damage(_packet(30.0, 0.0))
	assert_eq(health.current, 100.0, "the first hit is cancelled")
	assert_eq(health.interceptors.size(), 1, "and the parry took itself off the list")
	health.take_damage(_packet(30.0, 0.0))
	assert_almost_eq(health.current, 70.0, TOLERANCE, "the second hit lands")
	assert_eq(parry.later_calls, 1, "and reaches the interceptor behind it")


func test_healing_stops_at_the_maximum() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.take_damage(_packet(60.0, 0.0))
	watch_signals(health)
	health.heal(25.0)
	assert_almost_eq(health.current, 65.0, TOLERANCE)
	assert_signal_emitted_with_parameters(health, "health_changed", [health.current, 100.0])
	health.heal(500.0)
	assert_eq(health.current, 100.0)


func test_the_dead_are_not_healed_but_can_be_revived() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.take_damage(_packet(100.0, 0.0))
	watch_signals(health)
	health.heal(50.0)
	assert_eq(health.current, 0.0, "healing does not raise the dead")
	assert_true(health.is_dead)

	health.revive()
	assert_false(health.is_dead)
	assert_eq(health.current, 100.0, "revived at full health")
	assert_signal_emitted_with_parameters(health, "health_changed", [100.0, 100.0])

	health.take_damage(_packet(100.0, 0.0))
	assert_signal_emit_count(health, "died", 1, "and it can die again")


func test_a_shield_absorbs_before_the_health() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.add_shield(30.0, 5.0)
	assert_eq(health.shield, 30.0)

	health.take_damage(_packet(20.0, 0.0))
	assert_eq(health.current, 100.0, "the shield took all of it")
	assert_almost_eq(health.shield, 10.0, TOLERANCE)
	assert_signal_emit_count(health, "damaged", 1, "a hit a shield absorbs still landed")
	assert_signal_emit_count(health, "health_changed", 1)
	var damaged: Array = get_signal_parameters(health, "damaged")
	assert_almost_eq(damaged[1] as float, 20.0, TOLERANCE, "and came to its full amount")

	health.take_damage(_packet(25.0, 0.0))
	assert_eq(health.shield, 0.0, "the shield is used up")
	assert_almost_eq(health.current, 85.0, TOLERANCE, "and the rest of the hit comes off the health")


func test_a_shield_absorbs_what_is_left_after_mitigation() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	health.add_shield(30.0, 5.0)
	health.take_damage(_packet(40.0, 0.0))
	assert_almost_eq(health.shield, 10.0, TOLERANCE, "armor first: only 20 of the 40 reach the shield")
	assert_eq(health.current, 100.0)


func test_a_shield_expires() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.add_shield(30.0, 3.0)
	_advance(health, 2.9)
	assert_eq(health.shield, 30.0, "still up just before its time")
	_advance(health, 0.2)
	assert_eq(health.shield, 0.0, "gone after it")
	health.take_damage(_packet(20.0, 0.0))
	assert_almost_eq(health.current, 80.0, TOLERANCE, "and the next hit comes off the health")


func test_a_shield_ends_on_the_tick_its_time_is_up() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.add_shield(30.0, 3.0)
	for i: int in 179:
		health.advance(TICK)
	assert_eq(health.shield, 30.0, "up for 179 of its 180 ticks")
	health.advance(TICK)
	assert_eq(health.shield, 0.0, "gone on the 180th")


func test_shields_stand_side_by_side_and_the_one_that_ends_first_is_used_first() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.add_shield(10.0, 5.0)
	health.add_shield(10.0, 1.0)
	assert_eq(health.shield, 20.0, "two shields add up")
	health.take_damage(_packet(10.0, 0.0))
	assert_almost_eq(health.shield, 10.0, TOLERANCE)
	_advance(health, 1.5)
	assert_almost_eq(health.shield, 10.0, TOLERANCE, "the hit used up the short shield, so the long one is whole when the short one's time is over")
	_advance(health, 4.0)
	assert_eq(health.shield, 0.0)


func test_a_shield_without_an_amount_or_a_duration_is_none() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.add_shield(0.0, 5.0)
	health.add_shield(30.0, 0.0)
	health.add_shield(-5.0, -1.0)
	assert_eq(health.shield, 0.0)


func test_a_shield_runs_out_on_real_physics_ticks() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.add_shield(30.0, 0.1)
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(health.shield, 0.0, "a tenth of a second is six ticks")


func test_health_keeps_its_missing_fraction_when_the_maximum_changes() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	health.take_damage(_packet(25.0, 0.0))
	watch_signals(health)

	health.stats.add_modifier(&"equip:chest", StatBlock.MAX_HEALTH, 100.0, 0.0)
	assert_eq(health.maximum, 200.0)
	assert_almost_eq(health.current, 150.0, TOLERANCE, "a quarter was missing and a quarter still is")
	assert_signal_emitted_with_parameters(health, "health_changed", [health.current, 200.0])

	health.stats.remove_source(&"equip:chest")
	assert_eq(health.maximum, 100.0)
	assert_almost_eq(health.current, 75.0, TOLERANCE, "and back")

	health.stats.set_base(StatBlock.MAX_HEALTH, 40.0)
	assert_almost_eq(health.current, 30.0, TOLERANCE, "a base value that changes is followed too")


func test_a_stat_change_that_leaves_max_health_alone_announces_nothing() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	watch_signals(health)
	health.stats.add_modifier(&"status:slow", StatBlock.MOVE_SPEED, 0.0, -0.4)
	assert_signal_emit_count(health, "health_changed", 0)


func test_health_follows_a_stat_block_it_is_handed_later() -> void:
	# The order an actor sets itself up in: the Health node is ready first, the actor hands
	# it the block afterwards.
	var health := Health.new()
	add_child_autofree(health)
	assert_eq(health.maximum, 0.0)
	health.stats = _stats({StatBlock.MAX_HEALTH: 80.0})
	assert_eq(health.maximum, 80.0)
	assert_eq(health.current, 80.0, "it starts full")

	var other := _stats({StatBlock.MAX_HEALTH: 200.0})
	var first := health.stats
	health.take_damage(_packet(20.0, 0.0))
	health.stats = other
	assert_almost_eq(health.current, 150.0, TOLERANCE, "another block keeps the fraction too")
	first.set_base(StatBlock.MAX_HEALTH, 1.0)
	assert_eq(health.maximum, 200.0, "and the block it had before is no longer listened to")


# --- Debug damage numbers ---


func test_a_hit_shows_a_number_that_drifts_up_and_disappears() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	var numbers := DebugDamageNumbers.new()
	numbers.health = health
	numbers.lifetime = 0.1
	add_child_autofree(numbers)

	health.take_damage(_packet(25.0, 0.0))
	assert_eq(numbers.get_child_count(), 1, "one number per hit")
	var label := numbers.get_child(0) as Label3D
	assert_eq(label.text, "12.5", "the amount after mitigation")
	assert_eq(label.modulate, Palette.role(&"text", WorldState.state), "physical damage takes the text colour")
	assert_eq(label.position.y, 0.0, "it starts at the node")

	await _physics_steps(3)
	assert_gt(label.position.y, 0.0, "it drifts up")
	assert_lt(label.position.y, numbers.rise, "over its lifetime, not at once")
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(numbers.get_child_count(), 0, "and is gone when its time is up")


func test_numbers_are_tinted_by_damage_type_and_mark_crits() -> void:
	var health := _health({StatBlock.MAX_HEALTH: 100.0})
	var numbers := DebugDamageNumbers.new()
	numbers.health = health
	add_child_autofree(numbers)

	health.take_damage(_packet(0.0, 20.0))
	var frost := numbers.get_child(0) as Label3D
	assert_eq(frost.text, "20", "a whole number is written without decimals")
	assert_eq(frost.modulate, Palette.role(&"spirit", WorldState.state), "frost damage takes the spirit colour")

	var crit := _packet(15.0, 2.0)
	crit.is_crit = true
	health.take_damage(crit)
	var marked := numbers.get_child(1) as Label3D
	assert_eq(marked.text, "17!", "a crit is marked")
	assert_eq(marked.modulate, Palette.role(&"text", WorldState.state), "a mixed hit takes the colour of its larger part")
	assert_ne(Palette.role(&"text", WorldState.state), Palette.role(&"spirit", WorldState.state), "the two tints differ")


func test_numbers_find_the_health_at_their_path() -> void:
	var actor := Node3D.new()
	var health := Health.new()
	health.name = "Health"
	health.stats = _stats({StatBlock.MAX_HEALTH: 100.0})
	actor.add_child(health)
	var numbers := DebugDamageNumbers.new()
	numbers.health_path = NodePath("../Health")
	actor.add_child(numbers)
	add_child_autofree(actor)
	health.take_damage(_packet(5.0, 0.0))
	assert_eq(numbers.get_child_count(), 1)


# --- Factions, Hurtbox, Hitbox ---


func test_the_player_and_everything_else_are_hostile_to_each_other() -> void:
	var player := Factions.Faction.PLAYER
	var enemy := Factions.Faction.ENEMY
	var neutral := Factions.Faction.NEUTRAL_ANIMAL
	assert_true(Factions.is_hostile(player, enemy), "the player hits enemies")
	assert_true(Factions.is_hostile(player, neutral), "and neutral animals")
	assert_true(Factions.is_hostile(enemy, player), "enemies hit the player")
	assert_true(Factions.is_hostile(neutral, player), "and so does a neutral animal that fights back")
	assert_false(Factions.is_hostile(enemy, neutral), "enemies leave neutral animals alone")
	assert_false(Factions.is_hostile(neutral, enemy))
	assert_false(Factions.is_hostile(player, player), "nobody hits their own side")
	assert_false(Factions.is_hostile(enemy, enemy))
	assert_false(Factions.is_hostile(neutral, neutral))


func test_a_hurtbox_sits_on_the_layer_of_its_faction() -> void:
	var player := _target(Vector3.ZERO, Factions.Faction.PLAYER)
	var enemy := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var neutral := _target(Vector3.ZERO, Factions.Faction.NEUTRAL_ANIMAL)
	assert_eq(player.hurtbox.collision_layer, _bit(4), "layer 4, player_hurtbox")
	assert_eq(enemy.hurtbox.collision_layer, _bit(5), "layer 5, enemy_hurtbox")
	assert_eq(neutral.hurtbox.collision_layer, _bit(5), "neutral animals share the enemy layer")
	for target: HitTarget in [player, enemy, neutral]:
		assert_eq(target.hurtbox.collision_mask, 0, "a hurtbox looks for nothing")
		assert_false(target.hurtbox.monitoring)
		assert_true(target.hurtbox.monitorable)


func test_a_hurtbox_without_a_faction_set_is_an_enemy_hurtbox() -> void:
	var hurtbox := Hurtbox.new()
	add_child_autofree(hurtbox)
	assert_eq(hurtbox.faction, Factions.Faction.ENEMY)
	assert_eq(hurtbox.collision_layer, _bit(5), "the layer is set although nothing assigned the faction")


func test_a_hitbox_sits_on_the_layer_of_its_faction_and_looks_at_the_other_side() -> void:
	var player := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	var enemy := _hitbox(Vector3.ZERO, Factions.Faction.ENEMY)
	var neutral := _hitbox(Vector3.ZERO, Factions.Faction.NEUTRAL_ANIMAL)
	assert_eq(player.collision_layer, _bit(6), "layer 6, player_hitbox")
	assert_eq(player.collision_mask, _bit(5), "looking at enemy hurtboxes")
	assert_eq(enemy.collision_layer, _bit(7), "layer 7, enemy_hitbox")
	assert_eq(enemy.collision_mask, _bit(4), "looking at player hurtboxes")
	assert_eq(neutral.collision_layer, _bit(7))
	assert_eq(neutral.collision_mask, _bit(4))
	assert_false(player.monitorable, "nothing needs to find a hitbox")
	assert_false(player.active, "a hitbox starts switched off")
	assert_true(player.hits_once_per_activation)


func test_the_layer_names_of_the_project_match() -> void:
	for layer: int in [4, 5, 6, 7]:
		var expected: String = ["player_hurtbox", "enemy_hurtbox", "player_hitbox", "enemy_hitbox"][layer - 4]
		assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer), expected)
	assert_eq(Factions.hurtbox_layer(Factions.Faction.PLAYER), 4)
	assert_eq(Factions.hurtbox_layer(Factions.Faction.ENEMY), 5)
	assert_eq(Factions.hitbox_layer(Factions.Faction.PLAYER), 6)
	assert_eq(Factions.hitbox_layer(Factions.Faction.ENEMY), 7)
	assert_eq(Factions.target_layer(Factions.Faction.PLAYER), 5)
	assert_eq(Factions.target_layer(Factions.Faction.NEUTRAL_ANIMAL), 4)


func test_a_hurtbox_hands_a_hit_to_the_health_at_its_path() -> void:
	var actor := Node3D.new()
	var health := Health.new()
	health.name = "Health"
	health.stats = _stats({StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	actor.add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.health_path = NodePath("../Health")
	actor.add_child(hurtbox)
	add_child_autofree(actor)
	assert_eq(hurtbox.health, health)
	hurtbox.receive(_packet(40.0, 0.0))
	assert_almost_eq(health.current, 80.0, TOLERANCE, "the hit went through the health's mitigation")


func test_a_hitbox_hits_each_hurtbox_once_per_activation() -> void:
	var targets: Array[HitTarget] = [
		_target(Vector3(-1.5, 0.0, 0.0), Factions.Faction.ENEMY),
		_target(Vector3.ZERO, Factions.Faction.ENEMY),
		_target(Vector3(1.5, 0.0, 0.0), Factions.Faction.NEUTRAL_ANIMAL),
	]
	var outside := _target(Vector3(FAR_AWAY, 0.0, 0.0), Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER, Vector3(5.0, 1.0, 1.0))
	watch_signals(hitbox)
	await _physics_steps(HIT_FRAMES)
	for target: HitTarget in targets:
		assert_eq(target.hits, 0, "switched off, the hitbox hits nothing")

	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	for target: HitTarget in targets:
		assert_eq(target.hits, 1, "one hit each, however many ticks the hitbox stays on")
		assert_almost_eq(target.health.current, 100.0 - HIT_DAMAGE, TOLERANCE)
	assert_eq(outside.hits, 0, "a hurtbox the hitbox does not reach is not hit")
	assert_signal_emit_count(hitbox, "hurtbox_hit", 3)

	hitbox.active = false
	await _physics_steps(HIT_FRAMES)
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	for target: HitTarget in targets:
		assert_eq(target.hits, 2, "a new activation hits each of them once more")
	assert_signal_emit_count(hitbox, "hurtbox_hit", 6)


func test_setting_active_again_while_it_is_on_starts_no_new_activation() -> void:
	var target := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	hitbox.active = true
	await _physics_steps(HIT_FRAMES)
	hitbox.active = true
	await _physics_steps(HIT_FRAMES)
	assert_eq(target.hits, 1)


func test_a_player_hitbox_hits_enemies_and_neutral_animals_only() -> void:
	var enemy := _target(Vector3(-1.5, 0.0, 0.0), Factions.Faction.ENEMY)
	var neutral := _target(Vector3.ZERO, Factions.Faction.NEUTRAL_ANIMAL)
	var player := _target(Vector3(1.5, 0.0, 0.0), Factions.Faction.PLAYER)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER, Vector3(5.0, 1.0, 1.0))
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(enemy.hits, 1)
	assert_eq(neutral.hits, 1, "a neutral animal takes the player's hits")
	assert_eq(player.hits, 0, "the player's own hurtbox does not")


func test_an_enemy_hitbox_hits_the_player_only() -> void:
	var enemy := _target(Vector3(-1.5, 0.0, 0.0), Factions.Faction.ENEMY)
	var neutral := _target(Vector3.ZERO, Factions.Faction.NEUTRAL_ANIMAL)
	var player := _target(Vector3(1.5, 0.0, 0.0), Factions.Faction.PLAYER)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.ENEMY, Vector3(5.0, 1.0, 1.0))
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(player.hits, 1)
	assert_eq(enemy.hits, 0, "enemies do not hurt each other")
	assert_eq(neutral.hits, 0, "and an enemy hitbox ignores neutral animals")


func test_a_neutral_animal_that_fights_back_hits_the_player_only() -> void:
	var enemy := _target(Vector3(-1.5, 0.0, 0.0), Factions.Faction.ENEMY)
	var player := _target(Vector3(1.5, 0.0, 0.0), Factions.Faction.PLAYER)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.NEUTRAL_ANIMAL, Vector3(5.0, 1.0, 1.0))
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(player.hits, 1)
	assert_eq(enemy.hits, 0)


func test_the_faction_decides_even_when_the_layers_would_let_a_hit_through() -> void:
	# A hitbox whose mask someone widened by hand overlaps hurtboxes of its own side. The
	# faction check must still turn them down.
	var enemy := _target(Vector3(-1.5, 0.0, 0.0), Factions.Faction.ENEMY)
	var neutral := _target(Vector3(1.5, 0.0, 0.0), Factions.Faction.NEUTRAL_ANIMAL)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.ENEMY, Vector3(5.0, 1.0, 1.0))
	hitbox.collision_mask = _bit(4) | _bit(5)
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(hitbox.get_overlapping_areas().size(), 2, "the hitbox does overlap both")
	assert_eq(enemy.hits, 0)
	assert_eq(neutral.hits, 0)


func test_a_hitbox_without_a_packet_hits_nothing() -> void:
	var target := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	hitbox.damage_info = null
	watch_signals(hitbox)
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(target.hits, 0)
	assert_signal_emit_count(hitbox, "hurtbox_hit", 0)


func test_one_packet_serves_every_target() -> void:
	var armored := _target(Vector3(-1.0, 0.0, 0.0), Factions.Faction.ENEMY, {StatBlock.MAX_HEALTH: 100.0, StatBlock.ARMOR: 100.0})
	var plain := _target(Vector3(1.0, 0.0, 0.0), Factions.Faction.ENEMY)
	armored.health.interceptors.append(func(info: DamageInfo) -> bool:
		info.physical *= 0.5
		return false)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER, Vector3(5.0, 1.0, 1.0))
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_almost_eq(armored.health.current, 100.0 - HIT_DAMAGE * 0.25, TOLERANCE, "halved by its interceptor and again by its armor")
	assert_almost_eq(plain.health.current, 100.0 - HIT_DAMAGE, TOLERANCE, "the other target takes the hit as the attacker built it")
	assert_eq(hitbox.damage_info.physical, HIT_DAMAGE, "and the template is unchanged")


func test_a_hurtbox_that_comes_back_in_is_hit_again_only_without_once_per_activation() -> void:
	var returning := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var repeating := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	repeating.hits_once_per_activation = false
	repeating.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(returning.hits, 1, "while it stays inside it is hit once")

	returning.root.position.x = FAR_AWAY
	await _physics_steps(HIT_FRAMES)
	returning.root.position.x = 0.0
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(returning.hits, 2, "back inside, it is hit again")

	repeating.active = false
	var once := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	once.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(returning.hits, 3, "the second hitbox hits it once")
	returning.root.position.x = FAR_AWAY
	await _physics_steps(HIT_FRAMES)
	returning.root.position.x = 0.0
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(returning.hits, 3, "and not again when it comes back within the same activation")


func test_a_hitbox_moved_and_activated_in_a_physics_tick_does_not_hit_what_stood_at_its_old_place() -> void:
	# The engine finds overlaps in its step at the end of a tick. Right after a move the
	# hitbox still knows what overlapped it at the old place.
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().physics_frame, true)


func test_a_hitbox_moved_and_activated_between_two_ticks_does_not_hit_what_stood_at_its_old_place() -> void:
	# A coroutine that process_frame resumes runs where every _process does: after the
	# frame's physics ticks. The last step is over by then, and it saw the hitbox at its old
	# place.
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().process_frame, false)


func test_a_hitbox_moved_and_activated_in_an_input_event_does_not_hit_what_stood_at_its_old_place() -> void:
	# Where a skill fires: a key press or a click reaches a script between two ticks as well.
	await _assert_a_moved_hitbox_spares_its_old_place(_tap_input_events(), false)


func test_a_hitbox_moved_and_activated_at_the_very_end_of_a_tick_does_not_hit_what_stood_at_its_old_place() -> void:
	# A deferred call that a physics timer makes runs when the nodes, timers and tweens of
	# the tick are done: inside the tick still, but too late for its step to see the move.
	var old_place := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var new_place := _target(Vector3(FAR_AWAY, 0.0, 0.0), Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	await _physics_steps(HIT_FRAMES)
	assert_eq(hitbox.get_overlapping_areas().size(), 1, "the engine knows the hitbox overlaps the first target")

	_switched_on_in_a_tick = false
	var timer := get_tree().create_timer(TICK, true, true)
	timer.timeout.connect(_move_and_switch_on.bind(hitbox), CONNECT_DEFERRED)
	await _physics_steps(ACTIVE_FRAMES)
	assert_true(_switched_on_in_a_tick, "the move came inside a physics tick")
	assert_eq(old_place.hits, 0, "the target at the old place is spared")
	assert_eq(new_place.hits, 1, "the one at the new place is hit")


func test_a_hitbox_moved_and_activated_in_a_tick_of_no_length_waits_until_time_runs_again() -> void:
	# Engine.time_scale 0 hands out ticks of no length, and the step of such a tick finds
	# nothing: the hitbox goes on knowing what overlapped it at the old place.
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().physics_frame, true, Standstill.STOPPED_TIME)


func test_a_hitbox_moved_and_activated_between_two_ticks_of_no_length_waits_until_time_runs_again() -> void:
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().process_frame, false, Standstill.STOPPED_TIME)


func test_a_hitbox_moved_and_activated_as_the_tree_is_paused_waits_for_a_step_after_the_pause() -> void:
	# A click and the pause key that arrive in one frame. The engine takes no step while
	# the tree is paused, so after the pause the hitbox still knows what overlapped it at
	# the old place.
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().process_frame, false, Standstill.PAUSE)


func test_a_hitbox_moved_and_activated_in_a_tick_that_a_pause_cuts_short_waits_for_a_step_after_the_pause() -> void:
	# A pause that begins inside a physics tick takes the step from that tick. This one
	# begins when every node has had its turn in the tick: the hitbox has sat the tick out
	# by then, and for nothing.
	await _assert_a_moved_hitbox_spares_its_old_place(get_tree().physics_frame, true, Standstill.LATE_PAUSE)


func test_the_first_hits_land_one_or_two_ticks_after_the_activation() -> void:
	# What "keep a hitbox active for three ticks or longer" rests on: a hitbox sits out the
	# first tick it runs in after it is switched on.
	var in_a_tick := get_tree().physics_frame
	var between_two_ticks := get_tree().process_frame
	assert_eq(await _ticks_to_the_first_hit(in_a_tick), 1, "switched on ahead of its turn in a physics tick, a hitbox hits on the next tick")
	assert_eq(await _ticks_to_the_first_hit(in_a_tick, false, true), 2, "switched on when it has had its turn in the tick, it sits out the next one")
	assert_eq(await _ticks_to_the_first_hit(between_two_ticks), 2, "switched on between two ticks, it sits out the coming one")
	assert_eq(await _ticks_to_the_first_hit(in_a_tick, true), 1, "a hitbox that enters the tree as it is switched on is no slower inside a tick")
	assert_eq(await _ticks_to_the_first_hit(between_two_ticks, true), 2, "and no slower between two ticks")


func test_a_listener_that_switches_the_hitbox_off_ends_the_hits_of_that_tick() -> void:
	# The shape of a projectile that is spent after its first hit.
	var first := _target(Vector3(-1.0, 0.0, 0.0), Factions.Faction.ENEMY)
	var second := _target(Vector3(1.0, 0.0, 0.0), Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER, Vector3(5.0, 1.0, 1.0))
	hitbox.hurtbox_hit.connect(func(_hurtbox: Hurtbox) -> void: hitbox.active = false)
	hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	assert_eq(first.hits + second.hits, 1, "one target is hit, the other one is not")


func _packet(physical: float, frost: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.physical = physical
	info.frost = frost
	return info


func _stats(base: Dictionary) -> StatBlock:
	var stats := StatBlock.new()
	stats.base = base
	return stats


func _health(base: Dictionary) -> Health:
	var health := Health.new()
	health.stats = _stats(base)
	add_child_autofree(health)
	return health


## Runs the clock of [param health] on by [param seconds], one physics tick at a time.
func _advance(health: Health, seconds: float) -> void:
	for i: int in roundi(seconds / TICK):
		health.advance(TICK)


func _physics_steps(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _bit(layer: int) -> int:
	return 1 << (layer - 1)


## A unit-box hurtbox with a health of its own at [param at], in the tree.
func _target(at: Vector3, faction: Factions.Faction, base: Dictionary = {StatBlock.MAX_HEALTH: 100.0}) -> HitTarget:
	var target := HitTarget.new()
	target.root = Node3D.new()
	target.root.position = at
	target.health = Health.new()
	target.health.stats = _stats(base)
	target.root.add_child(target.health)
	target.hurtbox = Hurtbox.new()
	target.hurtbox.faction = faction
	target.hurtbox.health = target.health
	target.hurtbox.add_child(_box_shape(Vector3.ONE))
	target.root.add_child(target.hurtbox)
	target.health.damaged.connect(target.count_hit)
	add_child_autofree(target.root)
	return target


## A hitbox of [param size] at [param at], in the tree, switched off, with a physical hit
## of [constant HIT_DAMAGE] as its packet.
func _hitbox(at: Vector3, faction: Factions.Faction, size: Vector3 = Vector3.ONE) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.faction = faction
	hitbox.damage_info = _packet(HIT_DAMAGE, 0.0)
	hitbox.position = at
	hitbox.add_child(_box_shape(size))
	add_child_autofree(hitbox)
	return hitbox


func _box_shape(size: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	return shape


## A signal that fires once every rendered frame from inside the handling of an input event.
func _tap_input_events() -> Signal:
	var tap := InputTap.new()
	add_child_autofree(tap)
	return tap.arrived


## Stops time. The frame under way keeps the time scale it began with. Its ticks are over
## once it reaches its process step, and every tick after that has no length.
func _stop_time() -> void:
	Engine.time_scale = 0.0
	await get_tree().process_frame


## Moves [param hitbox] to where the far target of a test stands and switches it on. Notes
## whether that came inside a physics tick.
func _move_and_switch_on(hitbox: Hitbox) -> void:
	_switched_on_in_a_tick = Engine.is_in_physics_frame()
	hitbox.position.x = FAR_AWAY
	hitbox.active = true


## Lets a hitbox overlap one target, then moves it onto another and switches it on in one
## go as soon as [param resumed_by] fires. Asserts that this is inside a physics tick or
## between two, as [param in_a_tick] says, and that only the target at the new place is hit.
## With a [param standstill] the physics engine stands still around that moment and for a
## dozen ticks after it: no hit may land before time runs again.
func _assert_a_moved_hitbox_spares_its_old_place(
		resumed_by: Signal, in_a_tick: bool, standstill: Standstill = Standstill.NONE
) -> void:
	var old_place := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var new_place := _target(Vector3(FAR_AWAY, 0.0, 0.0), Factions.Faction.ENEMY)
	var hitbox := _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	await _physics_steps(HIT_FRAMES)
	assert_eq(hitbox.get_overlapping_areas().size(), 1, "the engine knows the hitbox overlaps the first target")
	if standstill == Standstill.STOPPED_TIME:
		await _stop_time()

	await resumed_by
	_move_and_switch_on(hitbox)
	if in_a_tick:
		assert_true(_switched_on_in_a_tick, "the move came inside a physics tick")
	else:
		assert_false(_switched_on_in_a_tick, "the move came between two physics ticks")
	if standstill == Standstill.PAUSE:
		get_tree().paused = true
	elif standstill == Standstill.LATE_PAUSE:
		get_tree().set_deferred(&"paused", true)
	await _physics_steps(ACTIVE_FRAMES)
	if standstill != Standstill.NONE:
		assert_eq(old_place.hits + new_place.hits, 0, "at a standstill nothing is hit")
		Engine.time_scale = 1.0
		# A pause ends where the player ends it: in an input handler, between two ticks.
		await get_tree().process_frame
		get_tree().paused = false
		await _physics_steps(ACTIVE_FRAMES)
	assert_eq(old_place.hits, 0, "the target at the old place is spared")
	assert_eq(new_place.hits, 1, "the one at the new place is hit")


## Switches a hitbox on over a target as soon as [param resumed_by] fires. Returns how many
## physics ticks lie between the tick the engine counted last at that moment and the tick
## of the hit. With [param spawned] the hitbox enters the tree at that moment as well;
## without it, it has stood there for a while. With [param deferred] it is switched on in a
## deferred call: inside a physics tick that is after every _physics_process of the tick.
func _ticks_to_the_first_hit(
		resumed_by: Signal, spawned: bool = false, deferred: bool = false
) -> int:
	var target := _target(Vector3.ZERO, Factions.Faction.ENEMY)
	var hitbox: Hitbox = null
	if not spawned:
		hitbox = _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	await _physics_steps(HIT_FRAMES)
	await resumed_by
	if spawned:
		hitbox = _hitbox(Vector3.ZERO, Factions.Faction.PLAYER)
	var switched_on := Engine.get_physics_frames()
	if deferred:
		hitbox.set_deferred(&"active", true)
	else:
		hitbox.active = true
	await _physics_steps(ACTIVE_FRAMES)
	# Off again: the target of the next run stands in the same place.
	hitbox.active = false
	return target.hit_tick - switched_on


## An actor reduced to what a hit needs: a hurtbox, its health and a count of the hits.
class HitTarget:
	extends RefCounted

	var root: Node3D
	var health: Health
	var hurtbox: Hurtbox
	var hits := 0
	## The physics tick the last hit landed in.
	var hit_tick := -1

	func count_hit(_info: DamageInfo, _amount: float) -> void:
		hits += 1
		hit_tick = Engine.get_physics_frames()


## Sends itself an input event every rendered frame and emits [signal arrived] from inside
## the handling of each: the place in a frame where a key press or a click reaches a script.
class InputTap:
	extends Node

	signal arrived

	func _process(_delta: float) -> void:
		var event := InputEventKey.new()
		event.physical_keycode = TAP_KEY
		Input.parse_input_event(event)

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.physical_keycode == TAP_KEY:
			arrived.emit()


## An interceptor in the shape of Parry: cancels one hit and takes itself off the list.
class OneShotParry:
	extends RefCounted

	var health: Health
	## How often an interceptor behind this one was reached.
	var later_calls := 0

	func intercept(_info: DamageInfo) -> bool:
		health.interceptors.erase(intercept)
		return true
