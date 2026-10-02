class_name StatusEffectManager
extends Node
## Runs the status effects on one actor: puts their modifiers into the actor's [StatBlock],
## deals their damage over time through the actor's [Health], and says whether the actor can
## move and act. The player, the enemies and the test dummies carry it unchanged.
##
## Effects arrive in two ways. A script calls [method apply]. Or a hit carries them: the
## manager listens to [signal Health.damaged] and applies [member DamageInfo.effects] of
## every hit that landed, so a hit that was dodged or parried leaves no effect behind.
## When the actor dies, every effect ends.

## [method apply] put the effect on the actor, started it over or made it last longer. Sent
## for every application, also while the effect is already there.
signal effect_applied(id: StringName)
## The effect is gone: its last copy ran out or was removed.
signal effect_removed(id: StringName)

## What the id of an effect is prefixed with to name its modifiers in the StatBlock, and its
## damage ticks in [member DamageInfo.skill_id].
const SOURCE_PREFIX := "status:"
## Slack in seconds when a clock is compared with a duration or a tick time, so that an
## effect ends, and deals its last tick, on the physics tick its time is up and not one
## later through rounding.
const TIME_EPSILON := 0.0001

## The actor's stat block, the same one its [Health] has. The modifiers of the running
## effects move along when another block is assigned.
@export var stats: StatBlock:
	set(value):
		if value == stats:
			return
		for id: StringName in _effects:
			_drop_modifiers(id)
		stats = value
		for id: StringName in _effects:
			_sync_modifiers(id)
## Path to the actor's [Health] node.
@export var health_path: NodePath

## The node damage ticks go through and hits come from: the one at [member health_path],
## unless a script set it.
var health: Health:
	set(value):
		if is_instance_valid(health):
			health.damaged.disconnect(_on_health_damaged)
			health.died.disconnect(clear)
		health = value
		if health != null:
			health.damaged.connect(_on_health_damaged)
			health.died.connect(clear)

## False while a stun or a root is on the actor. Read-only.
var can_move: bool:
	get:
		return not (_is_stunned() or _is_rooted())
	set(_value):
		push_error("StatusEffectManager.can_move is read-only.")
## False while a stun is on the actor. Read-only.
var can_act: bool:
	get:
		return not _is_stunned()
	set(_value):
		push_error("StatusEffectManager.can_act is read-only.")

## The running effects: id to an Array of [Instance], oldest first. An effect that is not
## running has no entry.
var _effects: Dictionary = {}


func _ready() -> void:
	if health == null and not health_path.is_empty():
		health = get_node_or_null(health_path) as Health


func _physics_process(delta: float) -> void:
	advance(delta)


## Puts [param effect] on the actor. If the actor already has it, [member
## StatusEffectData.stack_rule] decides: the time left starts over, grows by the duration,
## or a second copy starts next to the first. [param source] is the actor that caused it;
## the damage ticks name it as their source. The dead take no effects, and an effect
## without an id or a duration is not applied.
func apply(effect: StatusEffectData, source: Node = null) -> void:
	if effect == null or effect.id.is_empty() or effect.duration <= 0.0:
		return
	if health != null and health.is_dead:
		return
	var instances: Array = _effects.get(effect.id, [])
	if instances.is_empty() or effect.stack_rule == StatusEffectData.StackRule.INDEPENDENT:
		var instance := Instance.new()
		instance.data = effect
		instance.duration = effect.duration
		instance.source = source
		instances.append(instance)
		_effects[effect.id] = instances
		_add_modifiers(effect)
	else:
		var running: Instance = instances[0]
		if effect.stack_rule == StatusEffectData.StackRule.REFRESH:
			running.duration = running.elapsed + effect.duration
		else:
			running.duration += effect.duration
		if source != null:
			running.source = source
	effect_applied.emit(effect.id)


## Ends the effect with [param id] now, every copy of it, and takes its modifiers away.
func remove(id: StringName) -> void:
	if not _effects.has(id):
		return
	for instance: Instance in _effects[id]:
		instance.ended = true
	_drop_modifiers(id)
	_effects.erase(id)
	effect_removed.emit(id)


## Ends every effect now.
func clear() -> void:
	for id: StringName in _effects.keys():
		remove(id)


## Whether the effect with [param id] is on the actor.
func has_effect(id: StringName) -> bool:
	return _effects.has(id)


## The ids of the effects on the actor, in the order they arrived.
func get_effect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_effects.keys())
	return ids


## How many copies of the effect with [param id] run: 0 without it, 1 with it, more only
## under [constant StatusEffectData.INDEPENDENT].
func get_stacks(id: StringName) -> int:
	var instances: Array = _effects.get(id, [])
	return instances.size()


## Seconds until the effect with [param id] is gone, counted from its longest-lived copy.
## 0 without it.
func get_time_left(id: StringName) -> float:
	var longest := 0.0
	for instance: Instance in _effects.get(id, []):
		longest = maxf(longest, instance.duration - instance.elapsed)
	return longest


## Runs every effect on by [param delta] seconds: deals the damage ticks that have come due
## and ends what has run out. The physics tick calls this; a test may call it itself.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for id: StringName in _effects.keys():
		# A tick that kills the actor ends every effect, the ones still waiting in this
		# loop included, so each is looked up again and asked whether it has ended.
		var instances: Array = _effects.get(id, [])
		for instance: Instance in instances.duplicate():
			if instance.ended:
				continue
			instance.elapsed += delta
			_deal_due_ticks(instance)
			if not instance.ended and instance.elapsed >= instance.duration - TIME_EPSILON:
				_end(instance)


## The name the modifiers of the effect with [param id] go under in a StatBlock, and its
## damage ticks in [member DamageInfo.skill_id]: "status:" and the id.
static func source_key(id: StringName) -> StringName:
	return StringName(SOURCE_PREFIX + String(id))


## Whether [param info] is a damage tick of a status effect and not a hit. An interceptor
## that should only answer hits, a parry for one, asks this.
static func is_tick(info: DamageInfo) -> bool:
	return String(info.skill_id).begins_with(SOURCE_PREFIX)


## Deals the damage ticks of [param instance] that have come due. Ticks fall on whole
## multiples of the interval, counted from the moment the effect was applied, up to and
## including the moment it ends; refreshing or lengthening the effect does not shift them.
func _deal_due_ticks(instance: Instance) -> void:
	var data := instance.data
	if health == null or data.tick_interval <= 0.0:
		return
	if data.dot_physical <= 0.0 and data.dot_frost <= 0.0:
		return
	var ticking_time := minf(instance.elapsed, instance.duration) + TIME_EPSILON
	var ticks_due := floori(ticking_time / data.tick_interval)
	while instance.ticks_done < ticks_due and not instance.ended:
		instance.ticks_done += 1
		var info := DamageInfo.new()
		info.physical = data.dot_physical
		info.frost = data.dot_frost
		info.skill_id = source_key(data.id)
		if is_instance_valid(instance.source):
			info.source = instance.source
		health.take_damage(info)


## Ends one copy of an effect whose time is up.
func _end(instance: Instance) -> void:
	instance.ended = true
	var id := instance.data.id
	var instances: Array = _effects[id]
	instances.erase(instance)
	_sync_modifiers(id)
	if instances.is_empty():
		_effects.erase(id)
		effect_removed.emit(id)


## Adds the modifiers of one copy of [param effect] to the stats.
func _add_modifiers(effect: StatusEffectData) -> void:
	if stats == null:
		return
	var source := source_key(effect.id)
	for modifier: Dictionary in effect.modifiers:
		var stat: StringName = modifier.get("stat", &"")
		stats.add_modifier(source, stat, float(modifier.get("flat", 0.0)), float(modifier.get("percent", 0.0)))


## Takes the modifiers of the effect with [param id] out of the stats.
func _drop_modifiers(id: StringName) -> void:
	if stats != null:
		stats.remove_source(source_key(id))


## Makes the modifiers in the stats match the copies of the effect that still run.
func _sync_modifiers(id: StringName) -> void:
	_drop_modifiers(id)
	for instance: Instance in _effects.get(id, []):
		_add_modifiers(instance.data)


func _is_stunned() -> bool:
	for instances: Array in _effects.values():
		for instance: Instance in instances:
			if instance.data.stun:
				return true
	return false


func _is_rooted() -> bool:
	for instances: Array in _effects.values():
		for instance: Instance in instances:
			if instance.data.root:
				return true
	return false


## Applies the effects a hit carries, once the hit has landed.
func _on_health_damaged(info: DamageInfo, _final_amount: float) -> void:
	for effect: StatusEffectData in info.effects:
		apply(effect, info.source)


## One running copy of an effect.
class Instance:
	extends RefCounted

	var data: StatusEffectData
	## The actor that caused the effect. May have been freed since.
	var source: Node
	## Seconds since this copy was applied.
	var elapsed := 0.0
	## Seconds this copy lasts in all; grows when the effect is refreshed or lengthened.
	var duration := 0.0
	var ticks_done := 0
	## Set once the copy has run out or was removed.
	var ended := false
