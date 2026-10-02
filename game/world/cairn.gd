class_name Cairn
extends Node3D
## A stone waypoint with a lantern: a stack of boxes that, once it is lit, burns with an
## ember light and raises a tall beacon the fog does not hide. A lit cairn is a safe marker
## in fog and a place to respawn at.
##
## [member lit] is what the cairn shows. [method light] is the event: it lights the cairn,
## remembers it in [member GameState.zone_state] and announces it. A cairn that was lit in
## an earlier visit to its zone comes back lit.

## The list in [member GameState.zone_state] that holds the ids of a zone's lit cairns.
const ZONE_STATE_KEY := &"cairns_lit"
## Id of the item a cairn burns. Whoever calls [method interact] counts it in the inventory.
const TALLOW_ITEM_ID := &"tallow"
## What an interaction prompt says at an unlit cairn; the tallow cost goes in.
const PROMPT := "E: Light the cairn (%d tallow)"

## Whether the lantern burns. Setting it changes what the cairn shows and nothing else;
## light a cairn for the player with [method light].
@export var lit := false:
	set(value):
		lit = value
		_show_lit()
## The id the cairn is remembered under in its zone. Left empty, it is the node's name.
@export var cairn_id: StringName = &""
## Tallow it takes to light the cairn.
@export_range(0, 10) var tallow_cost := 1

## Whether the player may respawn here: a lit cairn is a safe point, an unlit one is not.
## Read-only.
var is_safe_point: bool:
	get:
		return lit
	set(_value):
		push_error("Cairn.is_safe_point is read-only.")

## What the scene says about [member lit], before any remembered state is applied.
var _lit_in_scene := false

## The lantern's light.
@onready var fire: OmniLight3D = $Fire
## The tall glowing box over a lit cairn. Its material ignores the fog and the light.
@onready var beacon: MeshInstance3D = $Beacon
## What the player's interactor finds: an Area3D on the interactable layer.
@onready var interact_area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group(WorldState.CAIRN_GROUP)
	if cairn_id.is_empty():
		cairn_id = name
	var ember := Palette.role(&"ember", WorldState.State.FOG)
	fire.light_color = ember
	beacon.material_override = _make_beacon_material(ember)
	_lit_in_scene = lit
	EventBus.zone_entered.connect(_on_zone_entered)
	_restore(GameState.current_zone)


## The player interacts with the cairn while carrying [param tallow_available] tallow. An
## unlit cairn is lit when that covers [member tallow_cost]. Returns the tallow that was
## burnt, which the caller takes out of the inventory: 0 when the cairn was lit already or
## the tallow is short.
func interact(tallow_available: int) -> int:
	if lit or tallow_available < tallow_cost:
		return 0
	light()
	return tallow_cost


## Lights the cairn for good: remembers it under the current zone in
## [member GameState.zone_state] and emits [signal EventBus.cairn_lit]. Does nothing to a
## cairn that is lit already.
func light() -> void:
	if lit:
		return
	lit = true
	GameState.add_zone_state(GameState.current_zone, ZONE_STATE_KEY, cairn_id)
	EventBus.cairn_lit.emit(self)


## The interaction prompt: what E does here, or nothing at a lit cairn.
func get_prompt() -> String:
	return "" if lit else PROMPT % tallow_cost


## Shows the cairn as lit when the scene says so or when it was lit before in
## [param zone_id]. Nothing is announced: the cairn was lit long ago.
func _restore(zone_id: StringName) -> void:
	lit = _lit_in_scene or GameState.has_zone_state(zone_id, ZONE_STATE_KEY, cairn_id)


func _show_lit() -> void:
	if not is_node_ready():
		return
	fire.visible = lit
	beacon.visible = lit


## The beacon glows by itself: it shows its colour whatever light falls on it, and the fog
## leaves it alone, so it is seen from as far as the camera sees.
func _make_beacon_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.disable_fog = true
	return material


## The zone manager may name the zone only after the cairn became ready, so the remembered
## state is read again when the zone is announced.
func _on_zone_entered(zone_id: StringName) -> void:
	_restore(zone_id)
