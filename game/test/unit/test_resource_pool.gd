extends GutTest
## The resource pool: spending, the gdd's two regeneration rules (stamina 20 a second after
## 1 s without spending, mana 4 a second always), and a maximum that follows the stats.
##
## Most tests run the pool's clock by hand, one physics tick at a time; the last one lets
## real physics ticks run it.

const TOLERANCE := 0.0001
## One physics tick in seconds.
const TICK := 1.0 / 60.0
const TICKS_PER_SECOND := 60
const BASE := {&"max_stamina": 100.0, &"max_mana": 50.0}


func test_a_pool_starts_full_at_its_stat() -> void:
	var stamina := _stamina()
	assert_eq(stamina.maximum, 100.0)
	assert_eq(stamina.current, 100.0)
	var mana := _mana()
	assert_eq(mana.maximum, 50.0)
	assert_eq(mana.current, 50.0)


func test_the_defaults_are_the_stamina_of_the_gdd() -> void:
	var pool := ResourcePool.new()
	autofree(pool)
	assert_eq(pool.stat_key, StatBlock.MAX_STAMINA)
	assert_eq(pool.regen_rate, 20.0, "20 a second")
	assert_eq(pool.regen_delay, 1.0, "after 1 s without spending")


func test_spending_takes_from_the_pool() -> void:
	var stamina := _stamina()
	watch_signals(stamina)
	assert_true(stamina.try_spend(30.0))
	assert_almost_eq(stamina.current, 70.0, TOLERANCE)
	assert_signal_emit_count(stamina, "changed", 1)
	assert_signal_emitted_with_parameters(stamina, "changed", [stamina.current, 100.0])


func test_spending_more_than_there_is_fails_and_changes_nothing() -> void:
	var stamina := _stamina()
	assert_true(stamina.try_spend(80.0))
	watch_signals(stamina)
	assert_false(stamina.try_spend(30.0), "only 20 left")
	assert_almost_eq(stamina.current, 20.0, TOLERANCE)
	assert_signal_emit_count(stamina, "changed", 0)
	assert_true(stamina.try_spend(20.0), "all of what is left can be spent")
	assert_almost_eq(stamina.current, 0.0, TOLERANCE)


func test_stamina_regeneration_pauses_for_a_second_after_spending() -> void:
	var stamina := _stamina()
	stamina.try_spend(30.0)
	_advance_ticks(stamina, TICKS_PER_SECOND - 1)
	assert_almost_eq(stamina.current, 70.0, TOLERANCE, "nothing comes back in the first 59 ticks")
	_advance_ticks(stamina, 1)
	assert_almost_eq(stamina.current, 70.0, TOLERANCE, "the wait is over as the 60th ends")
	_advance_ticks(stamina, 1)
	assert_almost_eq(stamina.current, 70.0 + 20.0 * TICK, TOLERANCE, "from the 61st on it regenerates")

	_advance_ticks(stamina, TICKS_PER_SECOND - 1)
	assert_almost_eq(stamina.current, 90.0, TOLERANCE, "20 a second: 20 back two seconds after the spend")


func test_spending_again_starts_the_wait_over() -> void:
	var stamina := _stamina()
	stamina.try_spend(30.0)
	_advance(stamina, 0.8)
	stamina.try_spend(10.0)
	_advance(stamina, 0.8)
	assert_almost_eq(stamina.current, 60.0, TOLERANCE, "1.6 s after the first spend, but only 0.8 s after the second: still waiting")
	_advance(stamina, 0.7)
	assert_almost_eq(stamina.current, 60.0 + 20.0 * 0.5, TOLERANCE, "1.5 s after the second spend: half a second of regeneration")


func test_spending_while_regenerating_pauses_it_again() -> void:
	var stamina := _stamina()
	stamina.try_spend(50.0)
	_advance(stamina, 1.5)
	assert_almost_eq(stamina.current, 60.0, TOLERANCE, "half a second of regeneration")
	stamina.try_spend(10.0)
	_advance(stamina, 0.9)
	assert_almost_eq(stamina.current, 50.0, TOLERANCE, "and none in the second after the new spend")


func test_spending_nothing_succeeds_and_holds_nothing_back() -> void:
	var stamina := _stamina()
	stamina.try_spend(50.0)
	_advance(stamina, 1.5)
	watch_signals(stamina)
	assert_true(stamina.try_spend(0.0), "a skill without a cost can always be paid for")
	assert_signal_emit_count(stamina, "changed", 0)
	_advance(stamina, 0.5)
	assert_almost_eq(stamina.current, 70.0, TOLERANCE, "and the regeneration ran on")


func test_regeneration_stops_at_the_maximum() -> void:
	var stamina := _stamina()
	stamina.try_spend(10.0)
	_advance(stamina, 3.0)
	assert_eq(stamina.current, 100.0)
	watch_signals(stamina)
	_advance(stamina, 1.0)
	assert_eq(stamina.current, 100.0)
	assert_signal_emit_count(stamina, "changed", 0, "a full pool announces nothing")


func test_mana_regenerates_slowly_and_always() -> void:
	var mana := _mana()
	mana.try_spend(30.0)
	_advance_ticks(mana, 1)
	assert_almost_eq(mana.current, 20.0 + 4.0 * TICK, TOLERANCE, "it regenerates from the first tick after the spend")
	_advance_ticks(mana, TICKS_PER_SECOND - 1)
	assert_almost_eq(mana.current, 24.0, TOLERANCE, "4 a second")
	mana.try_spend(10.0)
	_advance(mana, 1.0)
	assert_almost_eq(mana.current, 18.0, TOLERANCE, "and a second spend does not hold it back either")


func test_the_pool_keeps_its_share_when_the_maximum_changes() -> void:
	var stamina := _stamina()
	stamina.try_spend(25.0)
	watch_signals(stamina)
	stamina.stats.add_modifier(&"equip:ring", StatBlock.MAX_STAMINA, 100.0, 0.0)
	assert_eq(stamina.maximum, 200.0)
	assert_almost_eq(stamina.current, 150.0, TOLERANCE, "three quarters before, three quarters after")
	assert_signal_emitted_with_parameters(stamina, "changed", [stamina.current, 200.0])
	stamina.stats.remove_source(&"equip:ring")
	assert_almost_eq(stamina.current, 75.0, TOLERANCE)


func test_a_pool_reads_the_stat_its_key_names() -> void:
	var pool := ResourcePool.new()
	add_child_autofree(pool)
	assert_eq(pool.maximum, 0.0, "no stats, no pool")
	assert_false(pool.try_spend(1.0))
	var stats := StatBlock.new()
	stats.base = BASE
	pool.stats = stats
	assert_eq(pool.maximum, 100.0, "max_stamina by default")
	pool.stat_key = StatBlock.MAX_MANA
	assert_eq(pool.maximum, 50.0)
	assert_eq(pool.current, 50.0, "still full")


func test_nothing_regenerates_while_time_stands_still() -> void:
	var mana := _mana()
	mana.try_spend(30.0)
	mana.advance(0.0)
	assert_almost_eq(mana.current, 20.0, TOLERANCE, "a tick of no length, as Engine.time_scale 0 hands out, gives nothing back")


func test_stamina_waits_and_regenerates_on_real_physics_ticks() -> void:
	var stamina := _stamina()
	stamina.try_spend(30.0)
	for i: int in 50:
		await get_tree().physics_frame
	assert_almost_eq(stamina.current, 70.0, TOLERANCE, "50 ticks after the spend it is still waiting")
	for i: int in 25:
		await get_tree().physics_frame
	assert_gt(stamina.current, 70.0, "75 ticks after it, it regenerates")
	assert_lt(stamina.current, 76.0, "at 20 a second: under a third of a second so far")


func _stamina() -> ResourcePool:
	return _pool(StatBlock.MAX_STAMINA, 20.0, 1.0)


func _mana() -> ResourcePool:
	return _pool(StatBlock.MAX_MANA, 4.0, 0.0)


func _pool(stat_key: StringName, regen_rate: float, regen_delay: float) -> ResourcePool:
	var pool := ResourcePool.new()
	pool.stat_key = stat_key
	pool.regen_rate = regen_rate
	pool.regen_delay = regen_delay
	var stats := StatBlock.new()
	stats.base = BASE
	pool.stats = stats
	add_child_autofree(pool)
	return pool


## Runs the clock of [param pool] on by [param seconds], one physics tick at a time.
func _advance(pool: ResourcePool, seconds: float) -> void:
	_advance_ticks(pool, roundi(seconds * TICKS_PER_SECOND))


func _advance_ticks(pool: ResourcePool, ticks: int) -> void:
	for i: int in ticks:
		pool.advance(TICK)
