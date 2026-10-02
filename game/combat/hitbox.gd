class_name Hitbox
extends Area3D
## The part of an attack that hits: an area with a collision shape under it, on the hitbox
## layer of its faction (6 for the player, 7 for enemies and neutral animals), looking at
## the hurtbox layer of the other side. While [member active], every [Hurtbox] it overlaps
## whose faction it is hostile to is handed [member damage_info].
##
## A hitbox hits what the physics engine has found overlapping, and the engine finds that
## in its step at the end of a physics tick. So a hitbox sits out the first physics tick it
## runs in after it is switched on. The step that ends that tick sees the hitbox where it
## stands now, and a hitbox that was moved and activated in one go does not hit what stood
## at its old place. The first hits land on the tick after that: one tick after an
## activation that comes before the hitbox's own turn in a physics tick, two ticks after one
## that comes later in a tick or between two ticks, where an input handler and
## [method Node._process] run. Keep a hitbox active for three ticks (0.05 s) or longer.
##
## A tick of no length, which [member Engine.time_scale] 0 hands out, does not count: its
## step finds nothing. Neither does a tick the hitbox does not run in, as while the tree is
## paused, when the engine takes no step at all, nor a tick that a pause cuts short of its
## step. The hits wait until time runs again.
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
			_sits_out = true
		active = value
## True: a hurtbox is hit once between one activation and the next, however long it stays
## inside or how often it comes back. False: it is hit again every time it comes back in.
@export var hits_once_per_activation: bool = true

## The hit every hurtbox is handed. A template: [Health] works on a copy, so the same
## packet serves every target.
var damage_info: DamageInfo

## Instance ids of the hurtboxes that have had their hit.
var _already_hit: Dictionary = {}
## Whether the hitbox has yet to sit out a physics tick since it was switched on.
var _sits_out := false
## The physics tick the hitbox sat out last. A pause that begins inside it takes its step.
var _sat_out_tick := -1


func _ready() -> void:
	monitorable = false
	_apply_faction()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PAUSED or not Engine.is_in_physics_frame():
		return
	if Engine.get_physics_frames() == _sat_out_tick:
		# The pause begins inside the tick the hitbox sat out. That tick ends without a
		# step, so the hitbox sits out one more.
		_sits_out = true


func _physics_process(delta: float) -> void:
	# A tick of no length has a step that finds nothing. It is neither sat out nor hit in.
	if not active or delta <= 0.0:
		return
	if _sits_out:
		# The step that ends this tick sees the hitbox as it was switched on.
		_sits_out = false
		_sat_out_tick = Engine.get_physics_frames()
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
