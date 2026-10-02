class_name DebugDamageNumbers
extends Node3D
## Debug damage numbers, until J20 brings combat/feedback/damage_numbers.tscn and replaces
## this. The node sits above an actor. For every hit that lands on the actor's [Health] it
## shows what the hit came to on a [Label3D] that starts at this node, drifts up and is gone
## after [member lifetime]. Physical hits take the text colour and frost hits the spirit
## colour; a hit of both takes the colour of the larger part of its packet, as the attacker
## built it. A critical hit gets a "!".

## Path to the actor's [Health] node.
@export var health_path: NodePath
## Metres a number drifts up before it is gone.
@export var rise: float = 1.0
## Seconds a number is shown for.
@export var lifetime: float = 0.6
## Font size of the numbers in pixels.
@export var font_size: int = 48
## Size of one font pixel in metres.
@export var pixel_size: float = 0.006

## The node whose hits are shown: the one at [member health_path], unless a script set it.
var health: Health:
	set(value):
		if is_instance_valid(health):
			health.damaged.disconnect(_on_damaged)
		health = value
		if health != null:
			health.damaged.connect(_on_damaged)


func _ready() -> void:
	if health == null and not health_path.is_empty():
		health = get_node_or_null(health_path) as Health


## The text for a hit of [param amount]: one decimal, none on a whole number.
static func format_amount(amount: float, is_crit: bool) -> String:
	var text := ("%.1f" % amount).trim_suffix(".0")
	return text + "!" if is_crit else text


func _on_damaged(info: DamageInfo, final_amount: float) -> void:
	var label := Label3D.new()
	label.text = format_amount(final_amount, info.is_crit)
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var tint: StringName = &"spirit" if info.frost > info.physical else &"text"
	label.modulate = Palette.role(tint, WorldState.state)
	label.outline_modulate = Palette.role(&"deepest", WorldState.state)
	add_child(label)
	# The drift runs on physics ticks, like everything else that moves under an actor, so
	# that physics interpolation draws it smoothly.
	var tween := label.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(label, ^"position:y", rise, lifetime)
	tween.tween_callback(label.queue_free)
