class_name StatBlock
extends Resource
## The numbers of one actor: a base value per stat, plus modifiers that gear, stat points
## and status effects add and take away again by source.
##
## A stat is worth [code](base + sum of flat) * (1 + sum of percent)[/code]. A percent is a
## fraction: 0.3 is +30 %, -0.4 is -40 %.
##
## One block belongs to one actor. A block that sits in a scene or in a .tres is a template:
## the actor calls [method Resource.duplicate] on it when it becomes ready and hands the copy
## to its Health, ResourcePool and StatusEffectManager. The copy has its own base values and
## starts without modifiers.

## A base value or a modifier changed, so any stat may be worth something else now.
signal stats_changed

const MAX_HEALTH := &"max_health"
const MAX_STAMINA := &"max_stamina"
const MAX_MANA := &"max_mana"
const ARMOR := &"armor"
## Share of extra physical damage dealt: 0.25 is +25 %.
const PHYSICAL_BONUS := &"physical_bonus"
const FROST_RESISTANCE := &"frost_resistance"
## Chance of a critical hit, 0 to 1.
const CRIT_CHANCE := &"crit_chance"
## What a critical hit is multiplied by.
const CRIT_MULTIPLIER := &"crit_multiplier"
const MOVE_SPEED := &"move_speed"
const ATTACK_SPEED := &"attack_speed"

## The stats of the gdd, in the order it lists them. A block answers for any key, so a
## misspelt one reads as 0 without a word: take the keys from these constants.
const KEYS: Array[StringName] = [
	MAX_HEALTH, MAX_STAMINA, MAX_MANA, ARMOR, PHYSICAL_BONUS,
	FROST_RESISTANCE, CRIT_CHANCE, CRIT_MULTIPLIER, MOVE_SPEED, ATTACK_SPEED,
]

## Base value per stat: StringName keys from [constant KEYS], float values. A stat that is
## left out is worth 0. Assigning a dictionary takes a copy of it, so two blocks never share
## one; that covers [method Resource.duplicate] too, which hands the copy the original's
## dictionary. Change a single value with [method set_base]: writing into this dictionary
## directly announces nothing.
@export var base: Dictionary = {}:
	set(value):
		base = value.duplicate()
		stats_changed.emit()

## Modifiers by source: StringName source to an Array of { stat, flat, percent }.
var _modifiers: Dictionary = {}


## The base value of [param stat], before modifiers.
func get_base(stat: StringName) -> float:
	return float(base.get(stat, 0.0))


## Sets the base value of [param stat] and announces it.
func set_base(stat: StringName, value: float) -> void:
	base[stat] = value
	stats_changed.emit()


## Adds a modifier to [param stat] under [param source]: [param flat] is added to the base
## value, and [param percent], a fraction, to the multiplier. A source may hold any number of
## modifiers, also several on one stat; they add up. They stay until
## [method remove_source] takes the source away.
func add_modifier(source: StringName, stat: StringName, flat: float, percent: float) -> void:
	if not _modifiers.has(source):
		_modifiers[source] = []
	var entries: Array = _modifiers[source]
	entries.append({&"stat": stat, &"flat": flat, &"percent": percent})
	stats_changed.emit()


## Takes away every modifier that was added under [param source]. A source that holds none
## changes nothing and announces nothing.
func remove_source(source: StringName) -> void:
	if _modifiers.erase(source):
		stats_changed.emit()


## Whether any modifier is held under [param source].
func has_source(source: StringName) -> bool:
	return _modifiers.has(source)


## What [param stat] is worth now: [code](base + sum of flat) * (1 + sum of percent)[/code]
## over every source. The multiplier stops at 0, so percent modifiers that add up to less
## than -100 % leave the stat at 0 and never turn its sign around.
func get_stat(stat: StringName) -> float:
	var flat := 0.0
	var percent := 0.0
	for entries: Array in _modifiers.values():
		for entry: Dictionary in entries:
			if entry[&"stat"] == stat:
				flat += entry[&"flat"]
				percent += entry[&"percent"]
	return (get_base(stat) + flat) * maxf(1.0 + percent, 0.0)
