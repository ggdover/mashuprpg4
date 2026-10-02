class_name QuestTestScene
extends Node3D
## J15's test scene: the three-quest test chain from res://data/quests/test_chain/ played
## in the arena, with the journal (J) to follow it in.
##
## Quest A: the test NPC asks for three test dummies; it completes on the third and sets
## a_done. Quest B: the NPC then asks for two test items, which are collected, can be
## dropped again, and are delivered to the NPC. Quest C: the player's own question, which
## starts on the path south once B is done, is answered at the far stone, and can be
## asked again.
##
## The props stand in for what later jobs bring. E does what the nearest prop is for:
## knock down a dummy (J07's enemies), pick up an item (J06's world items), talk to the NPC
## (J16's dialogue). The overlay lists what the EventBus announced last.

## How close the player has to stand to a prop to interact with it, in metres.
@export var interact_range := 2.0
## The item the drop key takes out of the inventory.
@export var drop_item_id: StringName = &"test_item"
## How many of the latest quest events the overlay lists.
@export var log_length := 8
## Thickness in metres of the slab that shows where a quest trigger lies.
@export var slab_height := 0.02

var _log: Array[String] = []

@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _spawn: Marker3D = $Arena/PlayerSpawn
@onready var _props: Node3D = $Props
@onready var _triggers: Node3D = $Triggers
@onready var _label: Label = $Overlay/Label


func _ready() -> void:
	_player.global_position = _spawn.global_position
	_player.reset_physics_interpolation()
	_camera_rig.snap_to_target()
	var text := Palette.role(&"text", WorldState.state)
	var outline := Palette.role(&"deepest", WorldState.state)
	_label.add_theme_color_override(&"font_color", text)
	_label.add_theme_color_override(&"font_outline_color", outline)
	for node: Node in find_children("*", "Label3D", true, false):
		var name_label := node as Label3D
		name_label.modulate = text
		name_label.outline_modulate = outline
	for node: Node in _triggers.get_children():
		var trigger := node as QuestTrigger
		if trigger != null:
			_mark(trigger)
	EventBus.quest_started.connect(_on_quest_started)
	EventBus.quest_objective_progress.connect(_on_quest_objective_progress)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.flag_set.connect(_on_flag_set)
	EventBus.scene_requested.connect(_on_scene_requested)
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.marker_reached.connect(_on_marker_reached)


func _process(_delta: float) -> void:
	_label.text = _describe()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		interact()
	elif event.is_action_pressed(&"skill_2"):
		drop_item()


## Does what the nearest prop within reach is for: knocks a dummy down, picks an item up,
## talks to the NPC. Returns that prop, or null when none is within reach.
func interact() -> Node3D:
	var prop := _nearest_prop()
	if prop is QuestTestDummy:
		(prop as QuestTestDummy).die()
	elif prop is QuestTestPickup:
		(prop as QuestTestPickup).pick_up()
	elif prop is QuestTestNpc:
		(prop as QuestTestNpc).talk()
	return prop


## Takes one test item out of the inventory and puts it on the ground at the player's
## feet. Returns whether the player held one.
func drop_item() -> bool:
	if not QuestManager.inventory.remove(drop_item_id, 1):
		return false
	for prop: Node in _props.get_children():
		var pickup := prop as QuestTestPickup
		if pickup != null and pickup.item_id == drop_item_id and not pickup.is_on_ground():
			pickup.drop_at(_player.global_position)
			break
	return true


## The nearest prop that is there (a dummy that stands, an item on the ground, the NPC)
## within [member interact_range] of the player, or null.
func _nearest_prop() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := interact_range
	for node: Node in _props.get_children():
		var prop := node as Node3D
		if prop == null or not prop.visible:
			continue
		var distance := prop.global_position.distance_to(_player.global_position)
		if distance <= nearest_distance:
			nearest = prop
			nearest_distance = distance
	return nearest


## Lays a thin highlighted slab over the ground [param trigger] covers: a trigger has no
## visual of its own.
func _mark(trigger: QuestTrigger) -> void:
	var slab := Graybox.make_box(Vector3(trigger.size.x, slab_height, trigger.size.z), Graybox.MAT_HIGHLIGHT)
	slab.position.y = slab_height * 0.5
	trigger.add_child(slab)


## Adds a line to the event log and drops the oldest beyond [member log_length].
func _note(line: String) -> void:
	_log.append(line)
	while _log.size() > log_length:
		_log.pop_front()


## The overlay text: the keys, what the player holds, the flags, the latest events.
func _describe() -> String:
	var flags := PackedStringArray()
	for flag: StringName in GameState.flags:
		flags.append(String(flag))
	var lines := PackedStringArray([
		"E: talk to the NPC, knock down a dummy, pick up an item",
		"1: drop a test item    J: journal    WASD move, mouse aim",
		"Quest C starts on the path to the south once B is done.",
		"",
		"%s held: %d    silver: %d" % [drop_item_id, QuestManager.inventory.count_of(drop_item_id), QuestManager.inventory.silver],
		"flags: %s" % (", ".join(flags) if not flags.is_empty() else "none"),
		"",
	])
	lines.append_array(PackedStringArray(_log))
	return "\n".join(lines)


func _on_quest_started(quest_id: StringName) -> void:
	_note("quest_started(%s)" % quest_id)


func _on_quest_objective_progress(quest_id: StringName, index: int, current: int, target: int) -> void:
	_note("quest_objective_progress(%s, %d, %d, %d)" % [quest_id, index, current, target])


func _on_quest_completed(quest_id: StringName) -> void:
	_note("quest_completed(%s)" % quest_id)


func _on_flag_set(flag: StringName) -> void:
	_note("flag_set(%s)" % flag)


func _on_scene_requested(scene_id: StringName) -> void:
	_note("scene_requested(%s)" % scene_id)


func _on_xp_gained(amount: int) -> void:
	_note("xp_gained(%d)" % amount)


func _on_marker_reached(id: StringName) -> void:
	_note("marker_reached(%s)" % id)
