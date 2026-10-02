class_name Hitbox
extends Area3D
## The part of an attack that hits: an area with a collision shape under it, on the hitbox
## layer of its faction (6 for the player, 7 for enemies and neutral animals), looking at
## the hurtbox layer of the other side. While [member active], every [Hurtbox] it overlaps
## whose faction it is hostile to is handed [member damage_info].
##
## A hitbox hits what the physics engine has found overlapping, and the engine finds that
## in its step at the end of a physics tick. So the first hits land on the physics tick
## after the activation, never in the same tick: by then the engine has seen the hitbox
## where it stands now, and a hitbox that was moved and activated in one go cannot hit what
## stood at its old place. A hitbox that is added to the tree and activated between two
## ticks takes one tick more. Keep a hitbox active for three ticks (0.05 s) or longer.
##
## The faction sets the layer and the mask whenever it is assigned and when the node
## becomes ready. A script that wants another mask sets it after that.

## A hurtbox was handed the hit.
signal hurtbox_hit(hurtbox: Hurtbox)

## Whose attack this is. Decides the layer, the mask, and which hurtboxes are hit.
@export var faction: Factions.Faction = Factions.Faction.PLAYER:
	set(value):
		faction = value
		_apply_faction()
## Whether the hitbox hits. Switching it on starts a new activation: the hurtboxes hit so
## far are forgotten.
@export var active: bool = false:
	set(value):
		if value and not active:
			_already_hit.clear()
			_activated_tick = Engine.get_physics_frames()
		active = value
## True: a hurtbox is hit once between one activation and the next, however long it stays
## inside or how often it comes back. False: it is hit again every time it comes back in.
@export var hits_once_per_activation: bool = true

## The hit every hurtbox is handed. A template: [Health] works on a copy, so the same
## packet serves every target.
var damage_info: DamageInfo

## Instance ids of the hurtboxes that have had their hit.
var _already_hit: Dictionary = {}
## The physics tick [member active] was switched on in.
var _activated_tick := -1


func _ready() -> void:
	monitorable = false
	_apply_faction()


func _physics_process(_delta: float) -> void:
	if not active or Engine.get_physics_frames() <= _activated_tick:
		return
	var overlapping: Dictionary = {}
	for area: Area3D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null:
			continue
		var id := hurtbox.get_instance_id()
		overlapping[id] = true
		if _already_hit.has(id) or not _can_hit(hurtbox):
			continue
		_already_hit[id] = true
		hurtbox.receive(damage_info)
		hurtbox_hit.emit(hurtbox)
		if not active:
			# A listener switched the hitbox off: a projectile that is spent, say.
			break
	if not hits_once_per_activation:
		for id: int in _already_hit.keys():
			if not overlapping.has(id):
				_already_hit.erase(id)


## Whether [param hurtbox] takes this hitbox's hit. A script that extends Hitbox to narrow
## it down further, to an arc in front of the attacker for one, overrides this and asks the
## base first.
func _can_hit(hurtbox: Hurtbox) -> bool:
	return damage_info != null and Factions.is_hostile(faction, hurtbox.faction)


## Puts the area on the hitbox layer of its faction and has it look at the hurtbox layer of
## the other side.
func _apply_faction() -> void:
	collision_layer = Factions.layer_bit(Factions.hitbox_layer(faction))
	collision_mask = Factions.layer_bit(Factions.target_layer(faction))
