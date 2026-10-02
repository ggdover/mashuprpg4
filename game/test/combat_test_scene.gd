class_name CombatTestScene
extends Node3D
## J03's test scene: three dummies in the arena and a damage tester on the keyboard. The
## hit keys spawn a [Hitbox] in front of the HitMarker that covers all three dummies for a
## moment; the other keys work on every dummy at once. The overlay lists the keys. The
## small box with the nose stands on the HitMarker and shows which way its front is.
##
## The dummies differ where the pipeline does: Plain has no defences, Armored has 100 armor
## (physical damage halves), Neutral is a neutral animal with 100 frost resistance (frost
## damage halves). Enemy hits land on none of them.

## The status effects on the keys 1 to 7, in that order.
const STATUSES: Array[StatusEffectData] = [
	preload("res://data/status/bleed.tres"),
	preload("res://data/status/slow.tres"),
	preload("res://data/status/stun.tres"),
	preload("res://data/status/root.tres"),
	preload("res://data/status/armor_break.tres"),
	preload("res://data/status/frostbite.tres"),
	preload("res://data/status/burn.tres"),
]
const STATUS_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const HIT_PHYSICAL_KEY := KEY_F
const HIT_FROST_KEY := KEY_G
const HIT_CRIT_KEY := KEY_C
const HIT_ENEMY_KEY := KEY_E
const HEAL_KEY := KEY_H
const INVULNERABLE_KEY := KEY_I
const SHIELD_KEY := KEY_B
const SPEND_STAMINA_KEY := KEY_X
const SPEND_MANA_KEY := KEY_M
## Source of the modifier that makes the crit key's hit a certain crit.
const CRIT_SOURCE := &"test:crit"
## The crit chance that modifier adds: every roll crits.
const CERTAIN_CHANCE := 1.0
## The tester's hits come from no skill, so nothing multiplies them.
const SKILL_MULTIPLIER := 1.0
## What the tester's hits carry in [member DamageInfo.skill_id].
const HIT_SKILL_ID := &"test_hit"
## Thickness in metres of the slab that shows where a hit reaches.
const HIT_MARK_THICKNESS := 0.05

@export_group("Hit")
## Damage of one hit before the tester's stats and the dummy's defences.
@export var hit_damage: float = 20.0
## Width, height and depth of the hitbox in metres. Wide enough for all three dummies.
@export var hit_size: Vector3 = Vector3(9.0, 2.0, 2.0)
## How far in front of the HitMarker the middle of the hitbox lies, in metres.
@export var hit_distance: float = 2.0
## Seconds a hitbox stays active before it is freed: a dozen physics ticks, in which every
## dummy must take the hit once and no more.
@export var hit_duration: float = 0.2

@export_group("Other keys")
@export var heal_amount: float = 25.0
@export var shield_amount: float = 30.0
@export var shield_duration: float = 3.0
@export var stamina_cost: float = 30.0
@export var mana_cost: float = 10.0

@export_group("Tester")
## The stats the tester's hits are built from and its two pools draw their maximum from.
@export var attacker_stats: StatBlock

## How many hurtboxes the hitbox of the last hit key handed its hit to. A hurtbox counts
## whether or not its Health then took the hit: an invulnerable dummy is reached too.
var last_hit_count: int = 0

var _dummies: Array[CombatDummy] = []

@onready var _marker: Marker3D = $HitMarker
@onready var _stamina: ResourcePool = $Stamina
@onready var _mana: ResourcePool = $Mana
@onready var _label: Label = $Overlay/Label


func _ready() -> void:
	for child: Node in $Dummies.get_children():
		_dummies.append(child as CombatDummy)
	if attacker_stats == null:
		attacker_stats = StatBlock.new()
	else:
		attacker_stats = attacker_stats.duplicate() as StatBlock
	_stamina.stats = attacker_stats
	_mana.stats = attacker_stats
	_label.add_theme_color_override(&"font_color", Palette.role(&"text", WorldState.state))
	_label.add_theme_color_override(&"font_outline_color", Palette.role(&"deepest", WorldState.state))


func _process(_delta: float) -> void:
	_label.text = describe()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var status_index := STATUS_KEYS.find(key.physical_keycode)
	if status_index >= 0:
		apply_status(STATUSES[status_index])
		return
	match key.physical_keycode:
		HIT_PHYSICAL_KEY:
			spawn_hit(Factions.Faction.PLAYER, hit_damage, 0.0, false)
		HIT_FROST_KEY:
			spawn_hit(Factions.Faction.PLAYER, 0.0, hit_damage, false)
		HIT_CRIT_KEY:
			spawn_hit(Factions.Faction.PLAYER, hit_damage, 0.0, true)
		HIT_ENEMY_KEY:
			spawn_hit(Factions.Faction.ENEMY, hit_damage, 0.0, false)
		HEAL_KEY:
			heal_all()
		INVULNERABLE_KEY:
			toggle_invulnerable()
		SHIELD_KEY:
			shield_all()
		SPEND_STAMINA_KEY:
			_stamina.try_spend(stamina_cost)
		SPEND_MANA_KEY:
			_mana.try_spend(mana_cost)


## Spawns a hitbox of [param faction] in front of the HitMarker, active for
## [member hit_duration], with a packet built from the tester's stats. [param certain_crit]
## raises the tester's crit chance to 1 for this one packet. Returns the hitbox.
func spawn_hit(
		faction: Factions.Faction, physical: float, frost: float, certain_crit: bool
) -> Hitbox:
	if certain_crit:
		attacker_stats.add_modifier(CRIT_SOURCE, StatBlock.CRIT_CHANCE, CERTAIN_CHANCE, 0.0)
	var info := DamageInfo.from_stats(attacker_stats, physical, frost, SKILL_MULTIPLIER)
	attacker_stats.remove_source(CRIT_SOURCE)
	info.source = self
	info.skill_id = HIT_SKILL_ID

	var hitbox := Hitbox.new()
	hitbox.faction = faction
	hitbox.damage_info = info
	var box := BoxShape3D.new()
	box.size = hit_size
	var shape := CollisionShape3D.new()
	shape.shape = box
	hitbox.add_child(shape)
	# A thin slab on the ground shows where the hit reaches without hiding the dummies.
	var mark_size := Vector3(hit_size.x, HIT_MARK_THICKNESS, hit_size.z)
	var mark := Graybox.make_box(mark_size, Graybox.MAT_HIGHLIGHT)
	mark.position.y = (HIT_MARK_THICKNESS - hit_size.y) * 0.5
	hitbox.add_child(mark)
	# In front of the marker is along its -Z. The hitbox gets its place before it enters the
	# tree, so that it is never seen, or found by the physics engine, anywhere else.
	var centre := Vector3(0.0, hit_size.y * 0.5, -hit_distance)
	var place := Transform3D(_marker.global_basis, _marker.global_transform * centre)
	hitbox.transform = global_transform.affine_inverse() * place
	add_child(hitbox)

	last_hit_count = 0
	hitbox.hurtbox_hit.connect(_on_hurtbox_hit)
	hitbox.active = true
	var life := hitbox.create_tween()
	life.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	life.tween_interval(hit_duration)
	life.tween_callback(hitbox.queue_free)
	return hitbox


## Puts [param effect] on every dummy.
func apply_status(effect: StatusEffectData) -> void:
	for dummy: CombatDummy in _dummies:
		dummy.status.apply(effect, self)


## Heals every dummy by [member heal_amount]. A dead one comes back at full health.
func heal_all() -> void:
	for dummy: CombatDummy in _dummies:
		if dummy.health.is_dead:
			dummy.health.revive()
		else:
			dummy.health.heal(heal_amount)


## Makes every dummy invulnerable, or vulnerable again if the first one already is.
func toggle_invulnerable() -> void:
	var invulnerable := not _dummies[0].health.invulnerable
	for dummy: CombatDummy in _dummies:
		dummy.health.invulnerable = invulnerable


## Gives every dummy a shield of [member shield_amount] for [member shield_duration].
func shield_all() -> void:
	for dummy: CombatDummy in _dummies:
		dummy.health.add_shield(shield_amount, shield_duration)


## The overlay text: the keys, the tester's pools and how many hurtboxes the last hit reached.
func describe() -> String:
	return "\n".join([
		"F physical hit   G frost hit   C critical hit   E enemy hit (lands on nobody)",
		"1 bleed   2 slow   3 stun   4 root   5 armor break   6 frostbite   7 burn",
		"H heal, revive the dead   I invulnerable on/off   B shield   X spend stamina   M spend mana",
		"",
		"stamina %s / %s   mana %s / %s" % [
			DebugDamageNumbers.format_amount(_stamina.current, false),
			DebugDamageNumbers.format_amount(_stamina.maximum, false),
			DebugDamageNumbers.format_amount(_mana.current, false),
			DebugDamageNumbers.format_amount(_mana.maximum, false),
		],
		"last hit reached %d hurtboxes" % last_hit_count,
	])


func _on_hurtbox_hit(_hurtbox: Hurtbox) -> void:
	last_hit_count += 1
