extends Node
## Story progress every system reads: the act phase, the story flags and the current zone.
## SaveSystem (J19) writes and restores it.

## Story phase, 1 to 3 in act 1. Raised by quest turn-ins (J17).
var phase: int = 1
## Story flags that have been set: StringName keys, [code]true[/code] values.
var flags: Dictionary = {}
## Id of the zone the player is in. Set by the zone manager (J12).
var current_zone: StringName = &""


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
