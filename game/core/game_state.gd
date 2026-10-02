extends Node
## Story progress every system reads: the act phase, the story flags and the current zone.
## SaveSystem (J19) writes and restores it.

## Story phase, 1 to 3 in act 1. Raised by quest turn-ins (J17).
var phase: int = 1
## Story flags that have been set: StringName keys, [code]true[/code] values.
var flags: Dictionary = {}
## Id of the zone the player is in. Set by the zone manager (J12).
var current_zone: StringName = &""
## What a zone remembers while its scene is not loaded: zone id to a Dictionary of lists of
## ids, such as [code]cairns_lit[/code]. Written with [method add_zone_state] and read with
## [method has_zone_state]; J19 saves it.
var zone_state: Dictionary = {}


## Sets [param flag] and announces it on [signal EventBus.flag_set].
## A flag that is already set is left alone and not announced a second time.
func set_flag(flag: StringName) -> void:
	if flags.has(flag):
		return
	flags[flag] = true
	EventBus.flag_set.emit(flag)


## Whether [param flag] has been set.
func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


## Remembers [param entry] in the list [param key] of zone [param zone_id], for instance the
## id of a cairn under [code]&"cairns_lit"[/code]. An entry that is there already is not
## added twice.
func add_zone_state(zone_id: StringName, key: StringName, entry: StringName) -> void:
	var lists: Dictionary = zone_state.get_or_add(zone_id, {})
	var list: Array = lists.get_or_add(key, [])
	if not list.has(entry):
		list.append(entry)


## Whether [param entry] is in the list [param key] of zone [param zone_id].
func has_zone_state(zone_id: StringName, key: StringName, entry: StringName) -> bool:
	var lists: Dictionary = zone_state.get(zone_id, {})
	var list: Array = lists.get(key, [])
	return list.has(entry)
