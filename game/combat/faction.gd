class_name Factions
extends RefCounted
## Who an actor fights for, and what follows from it for hit detection: the physics layer
## its hurtbox sits on, the layer its hitboxes sit on and look at, and whom its hits land on.
##
## The class is called Factions because the enum keeps the name Faction: a class cannot
## usefully hold an enum of its own name. Write [code]Factions.Faction.ENEMY[/code].

## PLAYER is the player. ENEMY is everything possessed. NEUTRAL_ANIMAL is an animal that
## leaves the player alone until it is hit: the player's hits land on it, enemy hits do not.
enum Faction { PLAYER, ENEMY, NEUTRAL_ANIMAL }

## The physics layers of the damage pipeline, as project.godot names them.
const LAYER_PLAYER_HURTBOX := 4
const LAYER_ENEMY_HURTBOX := 5
const LAYER_PLAYER_HITBOX := 6
const LAYER_ENEMY_HITBOX := 7


## Whether a hit made by [param attacker] lands on a hurtbox of [param target]: the player
## and everything else are hostile to each other, and nothing else is. So enemies and
## neutral animals never hurt one another, and nobody hurts their own side.
static func is_hostile(attacker: Faction, target: Faction) -> bool:
	return (attacker == Faction.PLAYER) != (target == Faction.PLAYER)


## The layer number a hurtbox of [param faction] sits on. Neutral animals share the enemy
## layer, which is how the player's hitboxes find them.
static func hurtbox_layer(faction: Faction) -> int:
	return LAYER_PLAYER_HURTBOX if faction == Faction.PLAYER else LAYER_ENEMY_HURTBOX


## The layer number a hitbox of [param faction] sits on.
static func hitbox_layer(faction: Faction) -> int:
	return LAYER_PLAYER_HITBOX if faction == Faction.PLAYER else LAYER_ENEMY_HITBOX


## The hurtbox layer number a hitbox of [param faction] looks at: the other side's.
static func target_layer(faction: Faction) -> int:
	return LAYER_ENEMY_HURTBOX if faction == Faction.PLAYER else LAYER_PLAYER_HURTBOX


## The value [member CollisionObject3D.collision_layer] and
## [member CollisionObject3D.collision_mask] take for layer number [param layer] alone.
static func layer_bit(layer: int) -> int:
	return 1 << (layer - 1)
