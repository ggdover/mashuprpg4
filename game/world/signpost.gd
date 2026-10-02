class_name Signpost
extends Node3D
## A signpost: a post with a text above it that always faces the camera. It carries a
## [StateVisibility], so a signpost can stand by day only (Sjön, Berget), in fog only (Norr,
## Skogen, Ingen väg, Frost) or in both. A day signpost and a fog signpost placed on the same
## spot read as one post whose sign changes with the fog.

## What the sign says.
@export var text := "":
	set(value):
		text = value
		_apply()
## Whether the signpost stands by day.
@export var day := true:
	set(value):
		day = value
		_apply()
## Whether the signpost stands in fog.
@export var fog := true:
	set(value):
		fog = value
		_apply()

## The text above the post.
@onready var label: Label3D = $Label
## Shows and hides the signpost with the state of the forest.
@onready var state_visibility: StateVisibility = $StateVisibility


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	label.text = text
	# A sign is read in the state it stands in: a fog-only sign takes the fog's text colour.
	var read_in: int = WorldState.State.DAY if day else WorldState.State.FOG
	label.modulate = Palette.role(&"text", read_in)
	label.outline_modulate = Palette.role(&"deepest", read_in)
	state_visibility.day = day
	state_visibility.fog = fog
