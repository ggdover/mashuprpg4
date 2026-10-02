extends GutTest
## J15's test scene played the way a player would: the three-quest test chain through the
## stand-in props and the two quest triggers, with the journal read after every step.
##
## The scene runs in a viewport of its own, so the key presses the tests send reach the
## scene and nothing else. The player is put next to things instead of walked there; the
## triggers still fire from real physics.

const TEST_SCENE: PackedScene = preload("res://test/test_quests.tscn")
## Canvas size of the viewport the scene runs in: the size of the project window.
const VIEW_SIZE := Vector2i(1600, 900)
## Physics frames a trigger gets to notice that the player came.
const TRIGGER_FRAMES := 4
## Where the player is put inside the far stone's trigger: beside the stone, not in it.
const BESIDE := Vector3(1.5, 0.0, 0.0)
## Longest the walk from the spawn to the far stone may take, in physics frames. It is nine
## metres at six metres a second: about a hundred frames.
const WALK_TIMEOUT_FRAMES := 300
const NPC := "Props/TestNpc"
const PATH := "Triggers/Path"
const GOAL := "Triggers/Goal"

var _viewport: SubViewport
var _scene: QuestTestScene
var _player: Player
var _journal: Journal


func before_each() -> void:
	_fresh_game()
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	add_child_autofree(_viewport)
	_scene = TEST_SCENE.instantiate()
	_viewport.add_child(_scene)
	_player = _scene.get_node("Player")
	_journal = _scene.get_node("Overlay/Journal")
	await wait_physics_frames(2)


func after_each() -> void:
	Input.action_release(&"move_down")
	_fresh_game()


func test_the_scene_holds_what_the_chain_needs() -> void:
	assert_eq(_scene.get_node(NPC).get("npc_id"), &"test_npc", "the NPC that gives A and B and takes B's items")
	var dummies := 0
	var items := 0
	for prop: Node in _scene.get_node("Props").get_children():
		if prop is QuestTestDummy and (prop as QuestTestDummy).enemy_id == &"test_dummy":
			dummies += 1
		elif prop is QuestTestPickup and (prop as QuestTestPickup).item_id == &"test_item":
			items += 1
	assert_gte(dummies, 3, "three test dummies for quest A")
	assert_gte(items, 2, "two test items for quest B")
	assert_eq((_scene.get_node(PATH) as QuestTrigger).marker_id, QuestManager.get_quest(&"test_c").auto_start_marker)
	assert_eq((_scene.get_node(GOAL) as QuestTrigger).marker_id, QuestManager.get_quest(&"test_c").objectives[0].marker_id)
	assert_false(_journal.is_open(), "the journal is closed until J is pressed")
	assert_eq(QuestManager.get_active_quests().size(), 0, "and nothing has started by itself")


func test_what_the_player_deals_with_can_be_seen() -> void:
	var text := Palette.role(&"text", WorldState.state)
	for prop: Node in _scene.get_node("Props").get_children():
		assert_gt(prop.find_children("*", "MeshInstance3D", true, false).size(), 0, "%s is a box" % prop.name)
		var labels := prop.find_children("*", "Label3D", true, false)
		assert_eq(labels.size(), 1, "%s has its name over it" % prop.name)
		assert_eq((labels[0] as Label3D).modulate, text, "in the palette's text colour")
	for path: String in [PATH, GOAL]:
		var trigger: QuestTrigger = _scene.get_node(path)
		var slabs := trigger.find_children("*", "MeshInstance3D", true, false)
		assert_eq(slabs.size(), 1, "a slab on the ground shows where the trigger %s lies" % trigger.name)
		var slab := (slabs[0] as MeshInstance3D).mesh as BoxMesh
		assert_almost_eq(Vector2(slab.size.x, slab.size.z), Vector2(trigger.size.x, trigger.size.z), Vector2.ONE * 0.0001, "as wide and as deep as the trigger")
		assert_eq(slab.material, Graybox.MAT_HIGHLIGHT, "in the highlight material")


func test_the_chain_plays_through_with_the_journal_showing_each_step() -> void:
	watch_signals(EventBus)
	_press(&"journal")
	assert_true(_journal.is_open(), "J opens the journal")
	_assert_active(Journal.TEXT_NO_ACTIVE)
	_assert_completed(Journal.TEXT_NO_COMPLETED)

	# Quest C needs B: its path starts nothing yet.
	await _walk_into(PATH)
	assert_eq(QuestManager.state_of(&"test_c"), QuestManager.State.NOT_AVAILABLE)
	_assert_active(Journal.TEXT_NO_ACTIVE)

	# Quest A, accepted from the NPC. B is not on offer before a_done.
	await _interact_with(NPC)
	assert_eq(QuestManager.state_of(&"test_a"), QuestManager.State.ACTIVE)
	assert_eq(QuestManager.state_of(&"test_b"), QuestManager.State.NOT_AVAILABLE)
	_assert_active("Dummies in the yard")
	_assert_active("The test NPC wants three test dummies knocked down.")
	_assert_active("Knock down test dummies  0 / 3")
	_assert_not_active(Journal.TEXT_QUESTION, "a quest somebody gave is no question")

	await _interact_with("Props/OtherDummy")
	assert_false((_scene.get_node("Props/OtherDummy") as QuestTestDummy).is_alive(), "the other dummy went down")
	_assert_active("Knock down test dummies  0 / 3", "and does not count")
	await _interact_with("Props/Dummy1")
	_assert_active("Knock down test dummies  1 / 3")
	await _interact_with("Props/Dummy2")
	_assert_active("Knock down test dummies  2 / 3")
	await _interact_with("Props/Dummy3")
	assert_eq(QuestManager.state_of(&"test_a"), QuestManager.State.COMPLETED, "no turn-in NPC: done on the third dummy")
	assert_true(GameState.has_flag(&"a_done"))
	assert_signal_emitted_with_parameters(EventBus, "flag_set", [&"a_done"])
	assert_signal_emitted_with_parameters(EventBus, "xp_gained", [50])
	_assert_active(Journal.TEXT_NO_ACTIVE)
	_assert_completed("Dummies in the yard")

	# Quest B: collect two, with a drop in between, then deliver.
	await _interact_with(NPC)
	assert_eq(QuestManager.state_of(&"test_b"), QuestManager.State.ACTIVE)
	_assert_active("Test items for the test NPC")
	_assert_active("Pick up test items  0 / 2")
	_assert_not_active("Bring them to the test NPC", "the delivery is hidden until the items are collected")
	await _interact_with("Props/Item1")
	_assert_active("Pick up test items  1 / 2")
	await _interact_with("Props/Item2")
	_assert_active("Pick up test items  2 / 2")
	_assert_active("Bring them to the test NPC  0 / 2", "and now the delivery shows")
	assert_true(GameState.has_flag(&"b_items_found"), "the objective's own flag")

	_press(&"skill_2")
	assert_eq(QuestManager.inventory.count_of(&"test_item"), 1, "the 1 key drops an item")
	_assert_active("Pick up test items  1 / 2", "and the journal counts down")
	_assert_not_active("Bring them to the test NPC")
	await _interact_with(NPC)
	assert_eq(QuestManager.state_of(&"test_b"), QuestManager.State.ACTIVE, "one item is not enough for the NPC")
	assert_eq(QuestManager.inventory.count_of(&"test_item"), 1, "who takes nothing")
	await _interact_with("Props/Item1")
	_assert_active("Pick up test items  2 / 2", "the dropped item is picked up again")

	await _interact_with(NPC)
	assert_eq(QuestManager.state_of(&"test_b"), QuestManager.State.COMPLETED, "the NPC waited for the talk")
	assert_eq(QuestManager.inventory.count_of(&"test_item"), 0, "and kept the items")
	assert_eq(QuestManager.inventory.silver, 25)
	assert_eq(QuestManager.inventory.count_of(&"test_token"), 1, "the reward item")
	assert_true(GameState.has_flag(&"b_done"))
	assert_signal_emit_count(EventBus, "flag_set", 3, "a_done, b_items_found and b_done, each once")
	_assert_active(Journal.TEXT_NO_ACTIVE)
	_assert_completed("Test items for the test NPC")

	# Quest C: the player's own question, asked on the path, answered at the stone, twice.
	await _walk_into(PATH)
	assert_eq(QuestManager.state_of(&"test_c"), QuestManager.State.ACTIVE, "B is done: the path starts C")
	_assert_active(Journal.TEXT_QUESTION)
	_assert_active("What is that stone at the far end of the yard?")
	_assert_not_active("The far stone", "the question stands in for the quest's name")
	_assert_active("Walk up to the far stone  0 / 1")
	await _walk_into(GOAL, BESIDE)
	assert_eq(QuestManager.times_completed(&"test_c"), 1)
	assert_eq(QuestManager.state_of(&"test_c"), QuestManager.State.AVAILABLE, "repeatable: it can be asked again")
	assert_signal_emitted_with_parameters(EventBus, "scene_requested", [&"test_stone_scene"])
	assert_eq(QuestManager.inventory.silver, 30)
	_assert_active(Journal.TEXT_NO_ACTIVE)
	_assert_completed(Journal.TIMES_FORMAT % ["What is that stone at the far end of the yard?", 1])

	await _walk_into(PATH)
	assert_eq(QuestManager.state_of(&"test_c"), QuestManager.State.ACTIVE)
	_assert_active("Walk up to the far stone  0 / 1")
	await _walk_into(GOAL, BESIDE)
	assert_eq(QuestManager.times_completed(&"test_c"), 2)
	assert_eq(QuestManager.inventory.silver, 35, "paid again")
	_assert_completed(Journal.TIMES_FORMAT % ["What is that stone at the far end of the yard?", 2])
	assert_signal_emit_count(EventBus, "quest_completed", 4, "A, B and C twice")

	_press(&"journal")
	assert_false(_journal.is_open(), "J closes the journal")


func test_walking_south_asks_the_question_and_answers_it_at_the_stone() -> void:
	# No teleport here: S is held and the player walks from the spawn across the path and up
	# to the stone, the way it is played. Quest C needs B done first.
	QuestManager.from_dict({"completed": [{"id": "test_b", "times": 1}]})
	watch_signals(EventBus)
	Input.action_press(&"move_down")
	var frames := 0
	while QuestManager.times_completed(&"test_c") == 0 and frames < WALK_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_down")
	assert_eq(QuestManager.times_completed(&"test_c"), 1, "the walk south started quest C on the path and finished it at the stone")
	assert_signal_emitted_with_parameters(EventBus, "marker_reached", [&"test_c_start"], 0)
	assert_signal_emitted_with_parameters(EventBus, "marker_reached", [&"test_c_goal"], 1)
	assert_signal_emit_count(EventBus, "marker_reached", 2, "each trigger announced the player once")
	assert_gt(_player.global_position.z, 8.0, "the player stands by the stone")


func test_the_overlay_lists_what_the_bus_announced() -> void:
	await _interact_with(NPC)
	await _interact_with("Props/Dummy1")
	await wait_process_frames(2)
	var overlay: Label = _scene.get_node("Overlay/Label")
	assert_is(overlay.get_parent(), CanvasLayer)
	for expected: String in ["quest_started(test_a)", "quest_objective_progress(test_a, 0, 1, 3)", "test_item held: 0", "silver: 0", "flags: none"]:
		assert_string_contains(overlay.text, expected)


func test_nothing_out_of_reach_is_interacted_with() -> void:
	# The spawn is five metres from the NPC and further from everything else.
	assert_null(_scene.interact(), "nothing within two metres of the spawn")
	_press(&"interact")
	assert_eq(QuestManager.get_active_quests().size(), 0)
	assert_false(_scene.drop_item(), "and nothing to drop")


func test_a_dummy_that_went_down_stands_up_again() -> void:
	var dummy: QuestTestDummy = _scene.get_node("Props/Dummy1")
	var respawn: Timer = dummy.get_node("Respawn")
	respawn.wait_time = 0.05
	await _interact_with("Props/Dummy1")
	assert_false(dummy.is_alive())
	await wait_for_signal(respawn.timeout, 2.0)
	assert_true(dummy.is_alive(), "so the scene never runs short of dummies")


## A new game that knows only the quests on disk. The other test scripts share the autoloads.
func _fresh_game() -> void:
	GameState.flags.clear()
	GameState.phase = 1
	GameState.current_zone = &""
	QuestManager.inventory = QuestInventory.new()
	QuestManager.load_quests()


## Presses and releases the key of [param action] inside the scene's viewport.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_viewport.push_input(event)


## Puts the player on the prop at [param path], lets a physics frame pass, as walking there
## would, so that a trigger the player stood in sees it leave, and presses E.
func _interact_with(path: String) -> void:
	_put_player_at((_scene.get_node(path) as Node3D).global_position)
	await get_tree().physics_frame
	_press(&"interact")


## Puts the player into the trigger at [param path], [param offset] from its middle, and
## gives the trigger the physics frames it takes to notice.
func _walk_into(path: String, offset: Vector3 = Vector3.ZERO) -> void:
	_put_player_at((_scene.get_node(path) as Node3D).global_position + offset)
	for i: int in TRIGGER_FRAMES:
		await get_tree().physics_frame


func _put_player_at(place: Vector3) -> void:
	_player.global_position = place
	_player.reset_physics_interpolation()


func _assert_active(expected: String, why: String = "") -> void:
	var shown := _text_of(_journal.get_node("%ActiveList"))
	assert_true(shown.contains(expected), "the active tab shows '%s' %s\n%s" % [expected, why, shown])


func _assert_not_active(unexpected: String, why: String = "") -> void:
	var shown := _text_of(_journal.get_node("%ActiveList"))
	assert_false(shown.contains(unexpected), "the active tab does not show '%s' %s\n%s" % [unexpected, why, shown])


func _assert_completed(expected: String, why: String = "") -> void:
	var shown := _text_of(_journal.get_node("%CompletedList"))
	assert_true(shown.contains(expected), "the completed tab shows '%s' %s\n%s" % [expected, why, shown])


## Every label under [param list], one line each: what the tab shows.
func _text_of(list: Node) -> String:
	var lines := PackedStringArray()
	for node: Node in list.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)
