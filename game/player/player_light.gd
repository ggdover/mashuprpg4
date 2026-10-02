class_name PlayerLight
extends Node3D
## The player's own light: an ember OmniLight3D that burns in fog and in dungeons and is out
## by day, so the day scene looks as it would without it. The old lady's lantern (the
## [code]has_lantern[/code] flag, a phase 3 reward) doubles how far it reaches.
##
## The node makes its light itself and hangs it where the node stands, so the node's place
## under the player is the height of the light. It looks at the world state, the kind of
## zone and the flag every frame instead of waiting for signals: a loaded save or a debug
## command can change any of the three without announcing it.

## The story flag that widens the light.
const LANTERN_FLAG := &"has_lantern"

## How far the light reaches in metres without the lantern.
@export var base_range := 6.0
## How far it reaches with the lantern.
@export var lantern_range := 12.0
## Strength of the light.
@export_range(0.0, 16.0, 0.01) var energy := 3.0
## How fast the light fades with distance: 1 is the natural falloff, lower values spread it
## more evenly over its range.
@export_range(0.0, 4.0, 0.01) var attenuation := 0.6

## The light itself. Read-only.
var light: OmniLight3D:
	get:
		return _light
	set(_value):
		push_error("PlayerLight.light is read-only.")

var _light: OmniLight3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.name = &"Light"
	_light.light_color = Palette.role(&"ember", WorldState.State.FOG)
	_light.light_energy = energy
	_light.omni_attenuation = attenuation
	add_child(_light)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Whether the light should burn now: in fog, and in a dungeon whatever the state.
func is_needed() -> bool:
	return WorldState.state == WorldState.State.FOG or WorldState.zone_kind == WorldState.ZoneKind.DUNGEON


## How far the light reaches now, in metres.
func get_wanted_range() -> float:
	return lantern_range if GameState.has_flag(LANTERN_FLAG) else base_range


## Switches the light on or off and sets its range for the state of the world right now.
## Runs every frame; call it to see the result within the frame of a change.
func refresh() -> void:
	_light.visible = is_needed()
	_light.omni_range = get_wanted_range()
