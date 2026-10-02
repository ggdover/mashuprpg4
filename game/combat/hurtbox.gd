class_name Hurtbox
extends Area3D
## The part of an actor that can be hit: an area with a collision shape under it, on the
## hurtbox layer of its faction (4 for the player, 5 for enemies and neutral animals). It
## looks for nothing itself. A [Hitbox] that overlaps it and is hostile to its faction calls
## [method receive], and the hit goes on to the actor's [Health].

## Whose side the actor is on. Decides the layer, and which hitboxes hit it.
@export var faction: Factions.Faction = Factions.Faction.ENEMY:
	set(value):
		faction = value
		_apply_faction()
## Path to the actor's [Health] node.
@export var health_path: NodePath

## The node hits are handed to: the one at [member health_path], unless a script set it.
var health: Health


func _ready() -> void:
	monitoring = false
	_apply_faction()
	if health == null and not health_path.is_empty():
		health = get_node_or_null(health_path) as Health


## Takes a hit: hands [param info] to the actor's [Health], which decides what comes of it.
func receive(info: DamageInfo) -> void:
	if is_instance_valid(health):
		health.take_damage(info)


## Puts the area on the hurtbox layer of its faction and off every other one.
func _apply_faction() -> void:
	collision_layer = Factions.layer_bit(Factions.hurtbox_layer(faction))
	collision_mask = 0
