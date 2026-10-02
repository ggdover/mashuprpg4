class_name EnvironmentController
extends Node
## Gives a zone the look of the forest's current state. It owns the zone's WorldEnvironment
## and DirectionalLight3D: point it at the two a scene already has, or leave the two exports
## empty and it makes its own. By day it shows the day preset, in fog the fog preset, and
## with [member force_cave] the cave preset whatever the state is. When the state changes
## it tweens from one look to the other over [member transition_seconds].
##
## The presets are the Environment and LightPreset resources in world/environment/. They are
## never changed: the WorldEnvironment gets a copy to work on. A transition tweens the fog
## (colour, density, reach, how much of the sky it covers), the ambient light (colour,
## energy) and the directional light (colour, energy, shadow softness). Everything else in
## a preset (background, sky, tonemap) is taken over as a transition starts; the day and
## the fog preset agree on all of it, so nothing jumps between those two.

## Fog properties that say what the fog looks like. A look without fog borrows them from
## the other end of a transition, so that only the amount of fog changes on the way.
const FOG_SHAPE: Array[StringName] = [
	&"fog_light_color",
	&"fog_depth_begin",
	&"fog_depth_end",
	&"fog_depth_curve",
	&"volumetric_fog_albedo",
]
## Fog properties that say how much fog there is. A look without fog has none of any.
const FOG_AMOUNT: Array[StringName] = [&"fog_density", &"fog_sky_affect", &"volumetric_fog_density"]
## The ambient light.
const AMBIENT: Array[StringName] = [&"ambient_light_color", &"ambient_light_energy"]
## The blended properties of the sun.
const SUN_COLOR := &"light_color"
const SUN_ENERGY := &"light_energy"
const SUN_SOFTNESS := &"light_angular_distance"

## Shows the cave preset in both states and switches the directional light off. Dungeons
## set it.
@export var force_cave := false:
	set(value):
		force_cave = value
		show_state(transition_seconds)
## Seconds a change of state takes to show.
@export_range(0.0, 10.0, 0.1) var transition_seconds := 2.5
## Adds volumetric fog to the fog and cave looks, with the settings the presets carry.
## Off by default: the plain fog is what the presets are tuned for.
@export var volumetric_fog := false:
	set(value):
		volumetric_fog = value
		if _environment != null:
			_environment.volumetric_fog_enabled = volumetric_fog and _environment.fog_enabled
## The zone's WorldEnvironment. Left empty, the controller makes one.
@export var world_environment: WorldEnvironment
## The zone's sun. Left empty, the controller makes one.
@export var sun: DirectionalLight3D

@export_group("Sun the controller makes")
## How high a sun the controller makes stands, in degrees above the horizon.
@export_range(0.0, 90.0, 0.1) var sun_elevation_degrees := 45.0
## Which way round it stands, in degrees around the vertical.
@export_range(-180.0, 180.0, 0.1) var sun_heading_degrees := 45.0

@export_group("Presets")
@export var day_environment: Environment = preload("res://world/environment/env_day.tres")
@export var fog_environment: Environment = preload("res://world/environment/env_fog.tres")
@export var cave_environment: Environment = preload("res://world/environment/env_cave.tres")
@export var day_light: LightPreset = preload("res://world/environment/light_day.tres")
@export var fog_light: LightPreset = preload("res://world/environment/light_fog.tres")

## The copy of a preset that the WorldEnvironment shows and the transitions write to. Null
## until the first look is shown.
var _environment: Environment
## How long the running transition takes and how much of that time has passed, in seconds.
var _transition_seconds := 0.0
var _transition_elapsed := 0.0
## What the running transition blends from and to: property name to value, for the
## environment and for the sun.
var _environment_from: Dictionary[StringName, Variant] = {}
var _environment_to: Dictionary[StringName, Variant] = {}
var _sun_from: Dictionary[StringName, Variant] = {}
var _sun_to: Dictionary[StringName, Variant] = {}


func _ready() -> void:
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = &"WorldEnvironment"
		add_child(world_environment)
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = &"Sun"
		sun.rotation_degrees = Vector3(-sun_elevation_degrees, sun_heading_degrees, 0.0)
		add_child(sun)
	# The sun casts shadows in both looks that have one: hard by day, soft in fog.
	sun.shadow_enabled = true
	EventBus.world_state_changed.connect(_on_world_state_changed)
	# Nothing is on screen yet to tween from: a zone starts in the look of its state.
	show_state(0.0)


## Brings the environment and the sun to the look of the current state over
## [param seconds]; 0 switches at once. A transition that is under way is taken over from
## where it stands. Before the controller is ready there is nothing to show; it shows the
## state by itself when it becomes ready.
func show_state(seconds: float) -> void:
	if not is_node_ready():
		return
	_set_course_of_sun(_get_target_light(), _environment != null and sun.visible)
	_set_course_of_environment(_get_target_environment())
	_transition_seconds = maxf(seconds, 0.0)
	_transition_elapsed = 0.0
	set_process(true)
	_process(0.0)


## Carries the running transition on by [param delta] seconds and ends it once its time is
## up. A transition of no length ends at once.
func _process(delta: float) -> void:
	_transition_elapsed += delta
	if _transition_elapsed < _transition_seconds:
		_blend(_transition_elapsed / _transition_seconds)
		return
	_blend(1.0)
	_finish()


## The preset the environment is heading for.
func _get_target_environment() -> Environment:
	if force_cave:
		return cave_environment
	return fog_environment if WorldState.state == WorldState.State.FOG else day_environment


## The preset the sun is heading for; none in a cave, where no sun shines.
func _get_target_light() -> LightPreset:
	if force_cave:
		return null
	return fog_light if WorldState.state == WorldState.State.FOG else day_light


## Notes where the environment stands and where [param target] takes it, and gives the
## WorldEnvironment a fresh copy of [param target] to blend in.
func _set_course_of_environment(target: Environment) -> void:
	var shown := _environment
	var had_fog := shown != null and shown.fog_enabled
	_environment_to = _read_environment(target)
	_environment_from = _read_environment(shown) if shown != null else _environment_to.duplicate()
	_environment = target.duplicate() as Environment
	world_environment.environment = _environment
	if not had_fog:
		_borrow(FOG_SHAPE, _environment_to, _environment_from)
	elif not target.fog_enabled:
		# Fog that fades out keeps its shape to the end: the preset it fades to has none.
		_borrow(FOG_SHAPE, _environment_from, _environment_to)
		_environment.fog_mode = shown.fog_mode
	# The fog stays switched on for as long as either end of the way has it.
	_environment.fog_enabled = had_fog or target.fog_enabled
	_environment.volumetric_fog_enabled = volumetric_fog and _environment.fog_enabled


## Notes where the sun stands and where [param light] takes it; no light is no sun.
## [param is_lit] says whether the sun shines now.
func _set_course_of_sun(light: LightPreset, is_lit: bool) -> void:
	_sun_from = _read_sun(sun.light_color, sun.light_energy if is_lit else 0.0, sun.light_angular_distance)
	if light != null:
		_sun_to = _read_sun(light.color, light.energy, light.shadow_softness)
	else:
		_sun_to = _read_sun(sun.light_color, 0.0, sun.light_angular_distance)
	if not is_lit:
		# A sun that comes up does so in the colour it is going to have.
		_borrow([SUN_COLOR, SUN_SOFTNESS], _sun_to, _sun_from)
	# The sun stays switched on for as long as either end of the way has it.
	sun.visible = is_lit or light != null


## The blended properties of [param environment], as a look: property name to value. An
## environment whose fog is switched off has no amount of it.
func _read_environment(environment: Environment) -> Dictionary[StringName, Variant]:
	var look: Dictionary[StringName, Variant] = {}
	for property: StringName in FOG_SHAPE + AMBIENT:
		look[property] = environment.get(property)
	for property: StringName in FOG_AMOUNT:
		look[property] = environment.get(property) if environment.fog_enabled else 0.0
	return look


## The blended properties of a sun, as a look.
func _read_sun(color: Color, energy: float, softness: float) -> Dictionary[StringName, Variant]:
	var look: Dictionary[StringName, Variant] = {}
	look[SUN_COLOR] = color
	look[SUN_ENERGY] = energy
	look[SUN_SOFTNESS] = softness
	return look


## Copies the [param properties] of the look [param lender] over those of [param borrower].
func _borrow(properties: Array[StringName], lender: Dictionary[StringName, Variant], borrower: Dictionary[StringName, Variant]) -> void:
	for property: StringName in properties:
		borrower[property] = lender[property]


## Writes the look that lies [param weight] of the way from where the transition started
## to its preset: 0 is the start, 1 the preset.
func _blend(weight: float) -> void:
	for property: StringName in _environment_to:
		_environment.set(property, lerp(_environment_from[property], _environment_to[property], weight))
	for property: StringName in _sun_to:
		sun.set(property, lerp(_sun_from[property], _sun_to[property], weight))


## Ends a transition: what the preset does not have is switched off for good, and the
## controller rests until the next one.
func _finish() -> void:
	_environment.fog_enabled = _get_target_environment().fog_enabled
	_environment.volumetric_fog_enabled = volumetric_fog and _environment.fog_enabled
	sun.visible = _get_target_light() != null
	set_process(false)


func _on_world_state_changed(_state: int) -> void:
	# A cave looks the same in both states.
	if not force_cave:
		show_state(transition_seconds)
