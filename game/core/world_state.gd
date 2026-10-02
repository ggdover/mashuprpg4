extends Node
## The two states of the forest and what moves it from one to the other. Everything else in
## the game asks here which state it is: the environment, the signposts, the spawners, the
## player's light.
##
## Fog comes through [method request_fog]: from a story event (J17), or from the roll that
## [method on_zone_entered] makes when the player walks into an open zone. It goes through
## [method end_fog]: when the player enters a village, or when the scripted scene that
## brought it resolves. Assigning [member state] switches the state without the fog signals
## and without the horn; a loaded save and a debug key do that.

## The two states of the forest. Values are what [signal EventBus.world_state_changed] carries.
enum State { DAY, FOG }

## What kind of place a zone is, as far as the fog goes. J12's zone data names one per zone.
enum ZoneKind {
	## Never in fog: entering one ends the fog, and none starts while the player is in one.
	VILLAGE,
	## Entering one may bring fog, by the chance of the story phase.
	OPEN,
	## Leaves the state alone and shows the cave environment. The horn is not heard inside.
	DUNGEON,
}

## The reason [method on_zone_entered] gives [method request_fog] for the fog it rolls.
const RANDOM_REASON := &"random"
## The group every [Cairn] is in; [method nearest_lit_cairn] searches it.
const CAIRN_GROUP := &"cairns"

## The active state. Assigning a different value emits [signal EventBus.world_state_changed];
## assigning the same value again does nothing.
var state: State = State.DAY:
	set(value):
		if value == state:
			return
		state = value
		EventBus.world_state_changed.emit(state)

## Chance that entering an open zone brings fog, by [member GameState.phase]. A phase that is
## not listed has none. It rises with the story, so the village is right that the fog comes
## more often (gdd, World).
var fog_chance_by_phase: Dictionary[int, float] = {1: 0.0, 2: 0.10, 3: 0.25}
## True while a scripted scene owns the fog; J17 sets it around its scenes. Entering a zone
## then neither rolls for fog nor ends it. [method request_fog] and [method end_fog] still
## do as they are told, so the scene itself starts and ends its fog.
var fog_scene_active: bool = false
## The kind of zone the player is in: what [method on_zone_entered] was last given. OPEN
## until a zone has been entered, so a scene without zones can have fog.
var zone_kind: ZoneKind = ZoneKind.OPEN
## Rolls the fog chance. A test seeds it.
var rng := RandomNumberGenerator.new()

## The open zones whose last entry brought the fog by a roll. The next entry into one of
## them does not roll, so no zone gets random fog twice in a row.
var _fogged_on_last_entry: Dictionary[StringName, bool] = {}


## Brings the fog and says why. Emits [signal EventBus.fog_started] with [param reason] and,
## outside a dungeon, [signal EventBus.horn_sounded]. Does nothing in a village, which fog
## never enters, and nothing while it is fog already. Returns whether the fog started.
func request_fog(reason: StringName) -> bool:
	if zone_kind == ZoneKind.VILLAGE or state == State.FOG:
		return false
	state = State.FOG
	EventBus.fog_started.emit(reason)
	if zone_kind != ZoneKind.DUNGEON:
		EventBus.horn_sounded.emit()
	return true


## Takes the fog away and emits [signal EventBus.fog_ended]. Does nothing by day.
func end_fog() -> void:
	if state == State.DAY:
		return
	state = State.DAY
	EventBus.fog_ended.emit()


## Tells the world state that the player has entered the zone [param zone_id] of
## [param kind]. J12's zone manager calls it once the player stands in the new zone.
## A village ends the fog. An open zone rolls [member fog_chance_by_phase] for the story
## phase and asks for fog with [constant RANDOM_REASON] when the roll succeeds, unless the
## last entry into that same zone brought fog that way. A dungeon changes nothing. While
## [member fog_scene_active] is set, no kind of zone starts or ends the fog.
func on_zone_entered(zone_id: StringName, kind: ZoneKind) -> void:
	zone_kind = kind
	if fog_scene_active:
		return
	match kind:
		ZoneKind.VILLAGE:
			end_fog()
		ZoneKind.OPEN:
			_roll_for_fog(zone_id)


## The lit [Cairn] nearest to [param position] among those in the scene tree, or
## [code]null[/code] when none is lit. The bell points at it (J18).
func nearest_lit_cairn(position: Vector3) -> Cairn:
	var nearest: Cairn = null
	var nearest_distance_squared := INF
	for node: Node in get_tree().get_nodes_in_group(CAIRN_GROUP):
		var cairn := node as Cairn
		if cairn == null or not cairn.lit or cairn.is_queued_for_deletion():
			continue
		var distance_squared := cairn.global_position.distance_squared_to(position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = cairn
	return nearest


## The roll an open zone makes when the player enters it by day.
func _roll_for_fog(zone_id: StringName) -> void:
	if state == State.FOG:
		return
	if _fogged_on_last_entry.erase(zone_id):
		return
	var chance: float = fog_chance_by_phase.get(GameState.phase, 0.0)
	if rng.randf() < chance and request_fog(RANDOM_REASON):
		_fogged_on_last_entry[zone_id] = true
