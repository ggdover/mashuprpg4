class_name CombatDummy
extends Node3D
## A target for the combat test scenes: a gray box that carries the same nodes every actor
## that can be hurt does (a [StatBlock], [Health], [StatusEffectManager] and a [Hurtbox]),
## with a health bar, a label that spells its state out, and debug damage numbers. It
## stands still and never hits back.

## Name shown on the label.
@export var display_name: String = "Dummy"
## Whose side the dummy is on; handed to its [Hurtbox].
@export var faction: Factions.Faction = Factions.Faction.ENEMY:
	set(value):
		faction = value
		if is_node_ready():
			hurtbox.faction = faction
## Template for the dummy's stats. The dummy takes its own copy when it becomes ready, so
## dummies that were given one resource do not share their health or their modifiers.
@export var stats: StatBlock

@onready var health: Health = $Health
@onready var status: StatusEffectManager = $StatusEffectManager
@onready var hurtbox: Hurtbox = $Hurtbox
## The health bar: a box whose width is scaled to the share of health that is left.
@onready var _bar: MeshInstance3D = $HealthBar
@onready var _label: Label3D = $Label


func _ready() -> void:
	if stats == null:
		stats = StatBlock.new()
	else:
		stats = stats.duplicate() as StatBlock
	health.stats = stats
	status.stats = stats
	hurtbox.faction = faction
	_label.modulate = Palette.role(&"text", WorldState.state)
	_label.outline_modulate = Palette.role(&"deepest", WorldState.state)
	_bar.material_override = _make_bar_material()
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.maximum)


func _process(_delta: float) -> void:
	_label.text = describe()


## The label text, in short lines so that neighbouring dummies do not write over each
## other: name and faction, health and shield, the stats that damage and status effects
## work on, every running effect with its time left, and what the dummy is and cannot do.
func describe() -> String:
	var lines: Array[String] = []
	lines.append("%s (%s)" % [display_name, Factions.Faction.keys()[faction]])
	lines.append("hp %s / %s" % [_number(health.current), _number(health.maximum)])
	if health.shield > 0.0:
		lines.append("shield %s" % _number(health.shield))
	lines.append("armor %s, frost res %s" % [
		_number(stats.get_stat(StatBlock.ARMOR)),
		_number(stats.get_stat(StatBlock.FROST_RESISTANCE)),
	])
	lines.append("speed %s" % _number(stats.get_stat(StatBlock.MOVE_SPEED)))
	for id: StringName in status.get_effect_ids():
		var stacks := status.get_stacks(id)
		var entry := "%s %.1f s" % [id, status.get_time_left(id)]
		lines.append(entry if stacks == 1 else "%s x%d" % [entry, stacks])
	if health.is_dead:
		lines.append("dead")
	if health.invulnerable:
		lines.append("invulnerable")
	if not status.can_move:
		lines.append("cannot move")
	if not status.can_act:
		lines.append("cannot act")
	return "\n".join(lines)


func _on_health_changed(current: float, maximum: float) -> void:
	var fraction := current / maximum if maximum > 0.0 else 0.0
	# A box scaled to nothing has no volume left to draw; hide it instead.
	_bar.visible = fraction > 0.0
	if _bar.visible:
		_bar.scale.x = fraction


func _make_bar_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.role(&"health", WorldState.state)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## A number for the label, written the way the damage numbers are.
func _number(value: float) -> String:
	return DebugDamageNumbers.format_amount(value, false)
