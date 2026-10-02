class_name StatusEffectData
extends Resource
## What one status effect does, as data: how long it lasts, which stats it changes, what
## damage it deals over time and whether it stuns or roots. The seven effects of act 1 are
## the .tres files under res://data/status/. A [StatusEffectManager] runs them.

## What happens when the effect is applied to an actor that already has it.
enum StackRule {
	## The time left starts over at [member duration].
	REFRESH,
	## [member duration] is added to the time left.
	STACK_DURATION,
	## A second copy runs next to the first, with its own clock, ticks and modifiers.
	INDEPENDENT,
}

## Name of the effect, and its identity: two resources with one id are one effect. The
## modifiers go into the StatBlock under the source "status:" followed by this id.
@export var id: StringName = &""
## Seconds the effect lasts.
@export var duration: float = 0.0
## Seconds between two ticks of damage. 0 for an effect that deals none.
@export var tick_interval: float = 0.0
## Stat modifiers for as long as the effect lasts: one Dictionary per modifier with the keys
## stat (a StatBlock key), flat and percent (a fraction: -0.4 is -40 %). A key that is left
## out counts as 0.
@export var modifiers: Array[Dictionary] = []
## Physical damage per tick, before the target's armor.
@export var dot_physical: float = 0.0
## Frost damage per tick, before the target's frost resistance.
@export var dot_frost: float = 0.0
## The actor can neither move nor act while the effect lasts.
@export var stun: bool = false
## The actor cannot move while the effect lasts, but can still act.
@export var root: bool = false
## What applying the effect again does.
@export var stack_rule: StackRule = StackRule.REFRESH
