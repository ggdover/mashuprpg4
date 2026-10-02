class_name Health
extends Node
## The health of one actor, and the one place damage is applied. The player, the enemies and
## the test dummies all carry this node unchanged.
##
## A hit goes through [method take_damage] in this order: nothing happens while the actor is
## [member invulnerable] or dead; the [member interceptors] may cancel or change the hit;
## armor is taken off the physical part and frost resistance off the frost part; a shield
## absorbs what it can; the rest comes off the health.
##
## The maximum is the max_health of [member stats] and follows it when the stats change.

## A hit landed. [param info] is the packet as the interceptors left it, before armor and
## frost resistance; [param final_amount] is what the hit came to after them, whether it
## came off a shield or off the health.
signal damaged(info: DamageInfo, final_amount: float)
## The health or its maximum changed. Also sent after every hit that landed, including one a
## shield absorbed whole.
signal health_changed(current: float, maximum: float)
## The health reached zero. Sent once; [method revive] makes it possible again.
signal died

## The 100 in the gdd's mitigation formula: incoming * 100 / (100 + armor).
const MITIGATION_SCALE := 100.0
## Slack in seconds when a shield's time is checked, so that a shield ends on the tick its
## time is up and not one tick later through rounding.
const TIME_EPSILON := 0.0001

## The actor's stat block. max_health, armor and frost_resistance are read from it. The
## actor hands every one of its components the same block, its own copy.
@export var stats: StatBlock:
	set(value):
		if stats != null and stats.stats_changed.is_connected(_on_stats_changed):
			stats.stats_changed.disconnect(_on_stats_changed)
		stats = value
		if stats != null:
			stats.stats_changed.connect(_on_stats_changed)
		_on_stats_changed()
## While true, [method take_damage] does nothing. The dodge sets it for the length of the dash.
@export var invulnerable: bool = false

## Called with the packet before mitigation, in order, each as
## [code]func(info: DamageInfo) -> bool[/code]. An interceptor may change the amounts of the
## packet it is handed. Returning true cancels the hit: nothing is applied and nothing is
## sent. Parry cancels, Bulwark halves. Add one with [code]interceptors.append(callable)[/code]
## and take it away with [code]interceptors.erase(callable)[/code]; an interceptor may take
## itself away while it runs.
var interceptors: Array[Callable] = []

## The health now, from 0 to [member maximum]. Read-only: change it with
## [method take_damage], [method heal] and [method revive].
var current: float:
	get:
		return _current
	set(_value):
		push_error("Health.current is read-only.")
## The max_health of [member stats]. Read-only.
var maximum: float:
	get:
		return _maximum
	set(_value):
		push_error("Health.maximum is read-only.")
## What the shields can still absorb, all of them together. Read-only.
var shield: float:
	get:
		var total := 0.0
		for entry: ShieldPool in _shields:
			total += entry.amount
		return total
	set(_value):
		push_error("Health.shield is read-only.")
## True from the hit that took the health to zero until [method revive]. Read-only.
var is_dead: bool:
	get:
		return _is_dead
	set(_value):
		push_error("Health.is_dead is read-only.")

var _current := 0.0
var _maximum := 0.0
var _is_dead := false
## The shields that are up, in the order they were added.
var _shields: Array[ShieldPool] = []


func _ready() -> void:
	set_physics_process(not _shields.is_empty())


func _physics_process(delta: float) -> void:
	advance(delta)


## Applies a hit. See the class description for the order of things. The packet itself is
## left as it is: the interceptors and [signal damaged] get a copy, so one packet can be
## handed to any number of targets.
func take_damage(info: DamageInfo) -> void:
	if invulnerable or _is_dead or info == null:
		return
	var packet := info.copy()
	for interceptor: Callable in interceptors.duplicate():
		if interceptor.is_valid() and interceptor.call(packet) == true:
			return
	var armor := 0.0
	var frost_resistance := 0.0
	if stats != null:
		armor = stats.get_stat(StatBlock.ARMOR)
		frost_resistance = stats.get_stat(StatBlock.FROST_RESISTANCE)
	var amount := mitigate(packet.physical, armor) + mitigate(packet.frost, frost_resistance)
	_current = maxf(_current - (amount - _absorb(amount)), 0.0)
	_is_dead = _current <= 0.0
	damaged.emit(packet, amount)
	health_changed.emit(_current, _maximum)
	# A listener of the two signals above may have revived the actor: then it did not die.
	if _is_dead:
		died.emit()


## Gives [param amount] of health back, up to the maximum. The dead are not healed.
func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	_current = minf(_current + amount, _maximum)
	health_changed.emit(_current, _maximum)


## Puts up a shield that absorbs [param amount] of damage, after mitigation and before the
## health, and is gone after [param duration] seconds whatever is left of it. Several
## shields stand side by side; the one that ends first is used up first.
func add_shield(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	var entry := ShieldPool.new()
	entry.amount = amount
	entry.time_left = duration
	_shields.append(entry)
	set_physics_process(true)


## Brings the actor back at full health, without shields. [signal died] can be sent again
## after this. For respawns and for test dummies.
func revive() -> void:
	_is_dead = false
	_shields.clear()
	_current = _maximum
	health_changed.emit(_current, _maximum)


## Runs the shield timers on by [param delta] seconds. The physics tick calls this; a test
## may call it itself.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for entry: ShieldPool in _shields:
		entry.time_left -= delta
	_drop_spent_shields()
	if _shields.is_empty():
		set_physics_process(false)


## The gdd's mitigation: [param amount] * 100 / (100 + [param defence]), where the defence
## is armor against physical damage and frost resistance against frost. An amount or a
## defence below zero counts as zero, so a hit never heals and the division never fails.
static func mitigate(amount: float, defence: float) -> float:
	return maxf(amount, 0.0) * MITIGATION_SCALE / (MITIGATION_SCALE + maxf(defence, 0.0))


## Takes up to [param amount] out of the shields, the one that ends first before the
## others. Returns how much they took.
func _absorb(amount: float) -> float:
	var left := amount
	var by_time_left: Array[ShieldPool] = _shields.duplicate()
	by_time_left.sort_custom(_ends_before)
	for entry: ShieldPool in by_time_left:
		var taken := minf(left, entry.amount)
		entry.amount -= taken
		left -= taken
	_drop_spent_shields()
	return amount - left


func _ends_before(a: ShieldPool, b: ShieldPool) -> bool:
	return a.time_left < b.time_left


## Forgets the shields that are used up or whose time is over.
func _drop_spent_shields() -> void:
	for index: int in range(_shields.size() - 1, -1, -1):
		var entry := _shields[index]
		if entry.amount <= 0.0 or entry.time_left <= TIME_EPSILON:
			_shields.remove_at(index)


## Follows the max_health of the stats: the health keeps the share of the maximum it had,
## so the same fraction is missing before and after.
func _on_stats_changed() -> void:
	var new_maximum := 0.0
	if stats != null:
		new_maximum = maxf(stats.get_stat(StatBlock.MAX_HEALTH), 0.0)
	if is_equal_approx(new_maximum, _maximum):
		return
	var fraction := 1.0
	if _is_dead:
		fraction = 0.0
	elif _maximum > 0.0:
		fraction = _current / _maximum
	_maximum = new_maximum
	_current = new_maximum * fraction
	health_changed.emit(_current, _maximum)


## One absorb pool with its own clock.
class ShieldPool:
	extends RefCounted

	## What it can still absorb.
	var amount := 0.0
	## Seconds until it is gone.
	var time_left := 0.0
