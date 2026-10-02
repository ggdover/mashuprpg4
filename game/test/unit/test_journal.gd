extends GutTest
## The journal screen on its own: J opens and closes it, one tab lists the quests under way
## with their open objectives and counts, the other lists what is done, a quest nobody gave
## reads as the player's question, and the colours are the palette's UI signals.
##
## The journal runs in a viewport of its own, so the key presses the tests send reach it
## and nothing else.

const JOURNAL: PackedScene = preload("res://ui/journal/journal.tscn")
const VIEW_SIZE := Vector2i(1600, 900)
const QUEST := &"hunt"
const NPC := &"test_keeper"
const ITEM := &"test_pelt"

var _viewport: SubViewport
var _journal: Journal


func before_each() -> void:
	_fresh_game()
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	add_child_autofree(_viewport)
	_journal = JOURNAL.instantiate()
	_viewport.add_child(_journal)


func after_each() -> void:
	_fresh_game()


func test_j_opens_and_closes_the_journal() -> void:
	assert_false(_journal.is_open(), "closed until asked for")
	assert_false(_journal.visible)
	_press(&"journal")
	assert_true(_journal.is_open(), "the journal action opens it")
	assert_true(_journal.visible)
	_press(&"inventory")
	assert_true(_journal.is_open(), "another key leaves it alone")
	_press(&"journal")
	assert_false(_journal.is_open(), "and the journal action closes it again")


func test_it_has_an_active_and_a_completed_tab() -> void:
	var tabs: TabContainer = _journal.get_node("%Tabs")
	assert_eq(tabs.get_tab_count(), 2)
	assert_eq(tabs.get_tab_title(0), "Active")
	assert_eq(tabs.get_tab_title(1), "Completed")
	assert_eq(tabs.current_tab, 0, "the quests under way come first")
	_journal.open()
	assert_eq(_active_lines(), PackedStringArray([Journal.TEXT_NO_ACTIVE]), "an empty tab says so")
	assert_eq(_completed_lines(), PackedStringArray([Journal.TEXT_NO_COMPLETED]))


func test_the_panel_leaves_the_middle_of_the_screen_free() -> void:
	_journal.open()
	await wait_process_frames(2)
	var panel: Control = _journal.get_node("%Panel")
	var rect := panel.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)).encloses(rect), "the panel is on screen")
	assert_false(rect.has_point(Vector2(VIEW_SIZE) * 0.5), "and not over the player, who stands in the middle of it")


func test_a_given_quest_is_listed_under_its_name_with_summary_and_counts() -> void:
	var foxes := _kill_objective("Kill possessed foxes", 5)
	var quest := _add_quest([foxes, _kill_objective("Kill ravens", 12)])
	quest.display_name = "Foxes at the henhouse"
	quest.summary = "The fisherman wants the foxes at the henhouse gone."
	quest.giver_npc = NPC
	QuestManager.start(QUEST)
	QuestManager.progress(QUEST, 0, 3)
	_journal.open()
	assert_eq(_active_lines(), PackedStringArray([
		"Foxes at the henhouse",
		"The fisherman wants the foxes at the henhouse gone.",
		"Kill possessed foxes  3 / 5",
		"Kill ravens  0 / 12",
	]))


func test_a_quest_nobody_gave_is_listed_as_the_players_question() -> void:
	var quest := _add_quest([_kill_objective("Kill possessed wolves", 15)])
	quest.display_name = "Bells in the fog"
	quest.summary = "Whose bells are those in the fog?"
	QuestManager.start(QUEST)
	_journal.open()
	assert_eq(_active_lines(), PackedStringArray([
		Journal.TEXT_QUESTION,
		"Whose bells are those in the fog?",
		"Kill possessed wolves  0 / 15",
	]), "the question stands where a given quest has its name")
	QuestManager.complete(QUEST)
	assert_eq(_completed_lines(), PackedStringArray(["Whose bells are those in the fog?"]))


func test_an_objective_shows_once_the_one_before_it_is_finished() -> void:
	var path := _kill_objective("Walk the path home", 1)
	path.hidden_until_previous = true
	_add_quest([_kill_objective("Kill boars", 2), path], NPC).giver_npc = NPC
	QuestManager.start(QUEST)
	_journal.open()
	assert_false(_active_lines().has("Walk the path home  0 / 1"), "hidden until the boars are done")
	QuestManager.progress(QUEST, 0, 2)
	assert_true(_active_lines().has("Kill boars  2 / 2"))
	assert_true(_active_lines().has("Walk the path home  0 / 1"), "the open journal shows it the moment it opens")


func test_a_finished_objective_is_drawn_fainter() -> void:
	_add_quest([_kill_objective("Kill boars", 2), _kill_objective("Kill wolves", 2)]).giver_npc = NPC
	QuestManager.start(QUEST)
	QuestManager.progress(QUEST, 0, 2)
	_journal.open()
	var entry: Node = _journal.get_node("%ActiveList").get_node(String(QUEST))
	var boars: Label = entry.get_child(1)
	var wolves: Label = entry.get_child(2)
	assert_eq(boars.text, "Kill boars  2 / 2")
	assert_almost_eq(boars.modulate.a, _journal.finished_opacity, 0.0001, "done: fainter")
	assert_almost_eq(wolves.modulate.a, 1.0, 0.0001, "still to do: full strength")


func test_a_quest_that_waits_for_its_npc_says_so() -> void:
	_add_quest([_kill_objective("Kill boars", 1)], NPC).giver_npc = NPC
	QuestManager.start(QUEST)
	_journal.open()
	assert_false(_active_lines().has(Journal.TEXT_READY))
	QuestManager.progress(QUEST, 0, 1)
	assert_true(_active_lines().has(Journal.TEXT_READY))
	QuestManager.try_turn_in(QUEST, NPC)
	assert_eq(_active_lines(), PackedStringArray([Journal.TEXT_NO_ACTIVE]))
	assert_eq(_completed_lines(), PackedStringArray([String(QUEST)]))


func test_a_collected_item_that_is_dropped_counts_down_in_the_open_journal() -> void:
	var collect := ObjectiveData.new()
	collect.type = ObjectiveData.Type.COLLECT
	collect.item_id = ITEM
	collect.target_count = 10
	collect.description = "Collect goldieflowers"
	_add_quest([collect], NPC).giver_npc = NPC
	QuestManager.start(QUEST)
	_journal.open()
	QuestManager.inventory.add(ITEM, 4)
	assert_true(_active_lines().has("Collect goldieflowers  4 / 10"))
	QuestManager.inventory.remove(ITEM, 1)
	assert_true(_active_lines().has("Collect goldieflowers  3 / 10"))


func test_a_closed_journal_is_up_to_date_when_it_opens() -> void:
	_add_quest([_kill_objective("Kill boars", 5)]).giver_npc = NPC
	_journal.open()
	_journal.close()
	QuestManager.start(QUEST)
	QuestManager.progress(QUEST, 0, 4)
	_journal.open()
	assert_true(_active_lines().has("Kill boars  4 / 5"))


func test_a_repeatable_quest_is_listed_with_how_often_it_was_done() -> void:
	var quest := _add_quest([_kill_objective("Kill boars", 1)])
	quest.display_name = "Boar meat for the storehouse"
	quest.giver_npc = NPC
	quest.repeatable = true
	_journal.open()
	for times: int in [1, 2]:
		QuestManager.start(QUEST)
		QuestManager.progress(QUEST, 0, 1)
		assert_eq(_completed_lines(), PackedStringArray([Journal.TIMES_FORMAT % ["Boar meat for the storehouse", times]]))
	assert_eq(_active_lines(), PackedStringArray([Journal.TEXT_NO_ACTIVE]), "and it is not under way after a completion")


func test_the_colours_are_the_ui_signals_of_the_world_state() -> void:
	_add_quest([_kill_objective("Kill possessed wolves", 15)]).summary = "Whose bells are those in the fog?"
	QuestManager.start(QUEST)
	_journal.open()
	for state: WorldState.State in [WorldState.State.DAY, WorldState.State.FOG, WorldState.State.DAY]:
		WorldState.state = state
		var text := Palette.role(&"text", state)
		var highlight := Palette.role(&"highlight", state)
		var panel: PanelContainer = _journal.get_node("%Panel")
		var panel_box := panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(panel_box.bg_color, Color(Palette.role(&"panel", state), _journal.panel_opacity), "the panel colour, see-through, in state %d" % state)
		var tabs: TabContainer = _journal.get_node("%Tabs")
		assert_eq(tabs.get_theme_color(&"font_selected_color"), highlight, "the open tab is highlighted")
		assert_eq(tabs.get_theme_color(&"font_unselected_color"), text)
		assert_eq((_journal.get_node("%Title") as Label).get_theme_color(&"font_color"), text)
		var entry: Node = _journal.get_node("%ActiveList").get_node(String(QUEST))
		assert_eq((entry.get_child(0) as Label).get_theme_color(&"font_color"), highlight, "the question tag is highlighted")
		assert_eq((entry.get_child(1) as Label).get_theme_color(&"font_color"), text, "the rest is text")
	assert_ne(Palette.role(&"text", WorldState.State.DAY), Palette.role(&"text", WorldState.State.FOG), "the two states do differ")


## A new game that knows only the quests on disk. The other test scripts share the autoloads.
func _fresh_game() -> void:
	WorldState.state = WorldState.State.DAY
	GameState.flags.clear()
	GameState.phase = 1
	GameState.current_zone = &""
	QuestManager.inventory = QuestInventory.new()
	QuestManager.load_quests()


## Presses and releases the key of [param action] inside the journal's viewport.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_viewport.push_input(event)


func _kill_objective(description: String, target: int) -> ObjectiveData:
	var objective := ObjectiveData.new()
	objective.type = ObjectiveData.Type.KILL
	objective.description = description
	objective.target_count = target
	return objective


func _add_quest(objectives: Array[ObjectiveData], turn_in_npc: StringName = &"") -> QuestData:
	var quest := QuestData.new()
	quest.id = QUEST
	quest.display_name = String(QUEST)
	quest.objectives = objectives
	quest.turn_in_npc = turn_in_npc
	QuestManager.register(quest)
	return quest


func _active_lines() -> PackedStringArray:
	return _lines_of(_journal.get_node("%ActiveList"))


func _completed_lines() -> PackedStringArray:
	return _lines_of(_journal.get_node("%CompletedList"))


## The text of every label under [param list], top to bottom: what the tab shows.
func _lines_of(list: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	for node: Node in list.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return lines
