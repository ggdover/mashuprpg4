class_name WorldStateTestScene
extends Node3D
## J11's test scene: the arena under an EnvironmentController, with a day and a fog signpost
## on one post, a landmark the fog swallows, a path that is only there in fog, a lit and an
## unlit cairn, and the player with its light. Keys bring and end the fog, raise the story
## phase, toggle the lantern and walk the player into a zone of each kind; E lights the
## cairn the player stands at. The overlay shows what the world state makes of it.

## What the horn toast will say (J18). Until there is a HUD the scene prints it.
const HORN_TEXT := "The horn sounds from Tjärnäs."
## The reason the fog key gives [method WorldState.request_fog].
const FOG_REASON := &"test"
## The highest story phase of act 1; the phase key wraps round after it.
const LAST_PHASE := 3
const KEY_FOG := KEY_F
const KEY_END_FOG := KEY_G
const KEY_PHASE := KEY_P
const KEY_LANTERN := KEY_L
const KEY_ENTER_OPEN := KEY_O
const KEY_ENTER_VILLAGE := KEY_V
const KEY_ENTER_DUNGEON := KEY_U

## How close the player has to stand to a cairn to light it, in metres: the interactor's
## reach (J06).
@export var interact_range := 2.0
## Tallow the player carries in this scene. Lighting a cairn burns some of it.
@export var tallow := 1

## Times the horn has sounded since the scene started.
var horn_count := 0

@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _spawn: Marker3D = $Arena/PlayerSpawn
@onready var _environment: EnvironmentController = $EnvironmentController
@onready var _player_light: PlayerLight = $Player/PlayerLight
@onready var _label: Label = $Overlay/Label


func _ready() -> void:
	_player.global_position = _spawn.global_position
	_player.reset_physics_interpolation()
	_camera_rig.snap_to_target()
	EventBus.horn_sounded.connect(_on_horn_sounded)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	_colour_overlay()


func _process(_delta: float) -> void:
	_label.text = _describe()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		_light_nearest_cairn()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_FOG:
			WorldState.request_fog(FOG_REASON)
		KEY_END_FOG:
			WorldState.end_fog()
		KEY_PHASE:
			GameState.phase = GameState.phase % LAST_PHASE + 1
		KEY_LANTERN:
			_toggle_lantern()
		KEY_ENTER_OPEN:
			_enter_zone(&"test_open", WorldState.ZoneKind.OPEN)
		KEY_ENTER_VILLAGE:
			_enter_zone(&"test_village", WorldState.ZoneKind.VILLAGE)
		KEY_ENTER_DUNGEON:
			_enter_zone(&"test_dungeon", WorldState.ZoneKind.DUNGEON)


## Stands in for J12's zone change: tells the world state that the player entered a zone of
## [param kind], and shows the cave environment in a dungeon.
func _enter_zone(zone_id: StringName, kind: WorldState.ZoneKind) -> void:
	_environment.force_cave = kind == WorldState.ZoneKind.DUNGEON
	WorldState.on_zone_entered(zone_id, kind)


func _toggle_lantern() -> void:
	if GameState.has_flag(PlayerLight.LANTERN_FLAG):
		GameState.flags.erase(PlayerLight.LANTERN_FLAG)
	else:
		GameState.set_flag(PlayerLight.LANTERN_FLAG)


## Stands in for J06's interactor: E at a cairn within reach lights it with the tallow the
## scene carries.
func _light_nearest_cairn() -> void:
	var cairn := _get_cairn_in_reach()
	if cairn != null:
		tallow -= cairn.interact(tallow)


## The nearest cairn within [member interact_range] of the player, or null.
func _get_cairn_in_reach() -> Cairn:
	var nearest: Cairn = null
	var nearest_distance := interact_range
	for node: Node in get_tree().get_nodes_in_group(WorldState.CAIRN_GROUP):
		var cairn := node as Cairn
		if cairn == null or not is_ancestor_of(cairn):
			continue
		var distance := cairn.global_position.distance_to(_player.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = cairn
	return nearest


func _colour_overlay() -> void:
	_label.add_theme_color_override(&"font_color", Palette.role(&"text", WorldState.state))
	_label.add_theme_color_override(&"font_outline_color", Palette.role(&"deepest", WorldState.state))


## The overlay text: what the world state makes of the scene, and the keys.
func _describe() -> String:
	var state_name: String = WorldState.State.find_key(WorldState.state)
	var kind_name: String = WorldState.ZoneKind.find_key(WorldState.zone_kind)
	var chance: float = WorldState.fog_chance_by_phase.get(GameState.phase, 0.0)
	var light := _player_light.light
	var light_text := "%d m" % roundi(light.omni_range) if light.visible else "off"
	var lantern_text := "yes" if GameState.has_flag(PlayerLight.LANTERN_FLAG) else "no"
	var cairn_text := "none in reach"
	var cairn := _get_cairn_in_reach()
	if cairn != null:
		cairn_text = "lit" if cairn.lit else cairn.get_prompt()
	var bell_text := "none"
	var lit_cairn := WorldState.nearest_lit_cairn(_player.global_position)
	if lit_cairn != null:
		bell_text = "%.1f m away" % lit_cairn.global_position.distance_to(_player.global_position)
	return "\n".join([
		"state %s" % state_name,
		"zone kind %s" % kind_name,
		"phase %d: fog chance on entering an open zone %d %%" % [GameState.phase, roundi(chance * 100.0)],
		"player light %s, lantern %s" % [light_text, lantern_text],
		"horn sounded %d times" % horn_count,
		"tallow %d, cairn here: %s" % [tallow, cairn_text],
		"nearest lit cairn %s" % bell_text,
		"fps %d" % roundi(Engine.get_frames_per_second()),
		"",
		"WASD move, F fog, G end fog, P phase, L lantern, E light a cairn",
		"enter a zone: O open (rolls for fog), V village (ends fog), U dungeon (cave)",
	])


func _on_horn_sounded() -> void:
	horn_count += 1
	print(HORN_TEXT)


func _on_world_state_changed(_state: int) -> void:
	_colour_overlay()
