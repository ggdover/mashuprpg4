class_name ResourcePool
extends Node
## A pool that skills spend from: stamina or mana. One node per pool. The maximum is a stat
## of [member stats] and follows it when the stats change; the pool starts full.
##
## The defaults are the gdd's stamina: 20 a second, once nothing has been spent for 1 s. A
## mana pool sets [member stat_key] to max_mana, [member regen_rate] to 4 and
## [member regen_delay] to 0, which is "slowly, always".

## The amount or its maximum changed.
signal changed(current: float, maximum: float)

## The actor's stat block, the same one its [Health] has.
@export var stats: StatBlock:
	set(value):
		if stats != null and stats.stats_changed.is_connected(_on_stats_changed):
			stats.stats_changed.disconnect(_on_stats_changed)
		stats = value
		if stats != null:
			stats.stats_changed.connect(_on_stats_changed)
		_on_stats_changed()
## The stat that holds the maximum: max_stamina or max_mana.
@export var stat_key: StringName = StatBlock.MAX_STAMINA:
	set(value):
		stat_key = value
		_on_stats_changed()
## What comes back per second while the pool regenerates.
@export var regen_rate: float = 20.0
## Seconds after a spend before the pool regenerates again. 0 regenerates always.
@export var regen_delay: float = 1.0

## What is in the pool now, from 0 to [member maximum]. Read-only: [method try_spend] takes
## from it and time gives back.
var current: float:
	get:
		return _current
	set(_value):
		push_error("ResourcePool.current is read-only.")
## The value of the [member stat_key] stat. Read-only.
var maximum: float:
	get:
		return _maximum
	set(_value):
		push_error("ResourcePool.maximum is read-only.")

var _current := 0.0
var _maximum := 0.0
## Seconds until the pool regenerates again.
var _wait_left := 0.0


func _physics_process(delta: float) -> void:
	advance(delta)


## Takes [param amount] out of the pool if that much is in it, and holds the regeneration
## back for [member regen_delay]. Returns whether it was spent; when it was not, nothing
## changes. Spending nothing always succeeds and holds nothing back.
func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if amount > _current:
		return false
	_current -= amount
	_wait_left = regen_delay
	changed.emit(_current, _maximum)
	return true


## Runs the pool on by [param delta] seconds: the wait after a spend first, regeneration
## with whatever time is left. The physics tick calls this; a test may call it itself.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var regen_time := maxf(delta - _wait_left, 0.0)
	_wait_left = maxf(_wait_left - delta, 0.0)
	if regen_time <= 0.0 or _current >= _maximum:
		return
	_current = minf(_current + regen_rate * regen_time, _maximum)
	changed.emit(_current, _maximum)


## Follows the stat: the pool keeps the share of the maximum it had.
func _on_stats_changed() -> void:
	var new_maximum := 0.0
	if stats != null:
		new_maximum = maxf(stats.get_stat(stat_key), 0.0)
	if is_equal_approx(new_maximum, _maximum):
		return
	var fraction := _current / _maximum if _maximum > 0.0 else 1.0
	_maximum = new_maximum
	_current = new_maximum * fraction
	changed.emit(_current, _maximum)
