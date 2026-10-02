class_name Journal
extends Control
## The journal screen: one tab with the quests under way and their objectives, one with
## the quests that are done. The journal action (J) opens and closes it. It reads
## QuestManager and redraws whenever a quest changes while it is open.
##
## A quest nobody gave is the player's own question. It is listed under its summary, which
## is that question in the player's words, with a tag that says so; a quest somebody gave
## is listed under its name with the summary below.
##
## Colours are the palette's UI signals for the current world state: text, panel and
## highlight. Sizes and margins are in journal.tscn.

## The tag over a quest nobody gave.
const TEXT_QUESTION := "Question"
## The line under a quest whose objectives are finished and that waits for its NPC.
const TEXT_READY := "Ready to turn in"
## What the tabs say while they are empty.
const TEXT_NO_ACTIVE := "Nothing under way."
const TEXT_NO_COMPLETED := "Nothing completed yet."
## An objective line: description, count, target.
const OBJECTIVE_FORMAT := "%s  %d / %d"
## A repeatable quest in the completed tab: title, times completed.
const TIMES_FORMAT := "%s  × %d"

## How solid the panel is over the game, 0 to 1. design/palette.md asks for about 85 %.
@export_range(0.0, 1.0) var panel_opacity := 0.85
## How strongly a finished objective is drawn next to an open one, 0 to 1.
@export_range(0.0, 1.0) var finished_opacity := 0.6
## Font size of the title and of each quest's heading, in pixels.
@export var heading_font_size := 22

## The palette's text and highlight colours for the current world state.
var _text_color: Color
var _highlight_color: Color
var _panel_box: StyleBoxFlat
var _selected_tab_box: StyleBoxFlat

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _tabs: TabContainer = %Tabs
@onready var _active_list: VBoxContainer = %ActiveList
@onready var _completed_list: VBoxContainer = %CompletedList


func _ready() -> void:
	# Copies of the two style boxes that get a palette colour, so that painting them never
	# reaches a box some other screen shares.
	_panel_box = _panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	_panel.add_theme_stylebox_override(&"panel", _panel_box)
	_selected_tab_box = _tabs.get_theme_stylebox(&"tab_selected").duplicate() as StyleBoxFlat
	_tabs.add_theme_stylebox_override(&"tab_selected", _selected_tab_box)
	_title.add_theme_font_size_override(&"font_size", heading_font_size)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	_apply_palette()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal"):
		toggle()
		get_viewport().set_input_as_handled()


## Whether the journal is on screen.
func is_open() -> bool:
	return visible


## Shows the journal, up to date.
func open() -> void:
	refresh()
	show()


## Hides the journal.
func close() -> void:
	hide()


## Opens the journal if it is closed and closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Rebuilds both tabs from QuestManager.
func refresh() -> void:
	_clear(_active_list)
	_clear(_completed_list)
	for quest: QuestData in QuestManager.get_active_quests():
		_active_list.add_child(_make_active_entry(quest))
	if _active_list.get_child_count() == 0:
		_active_list.add_child(_make_label(TEXT_NO_ACTIVE, _text_color))
	for quest: QuestData in QuestManager.get_completed_quests():
		_completed_list.add_child(_make_completed_entry(quest))
	if _completed_list.get_child_count() == 0:
		_completed_list.add_child(_make_label(TEXT_NO_COMPLETED, _text_color))


## One quest under way: tag, heading, summary, the open objectives with their counts.
func _make_active_entry(quest: QuestData) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.name = String(quest.id)
	if quest.is_auto():
		entry.add_child(_make_label(TEXT_QUESTION, _highlight_color))
	entry.add_child(_make_heading(_title_of(quest)))
	if not quest.is_auto() and quest.summary != "":
		entry.add_child(_make_label(quest.summary, _text_color))
	for index: int in quest.objectives.size():
		if not QuestManager.is_objective_open(quest.id, index):
			continue
		var objective := quest.objectives[index]
		var count := QuestManager.get_objective_count(quest.id, index)
		var line := _make_label(OBJECTIVE_FORMAT % [objective.description, count, objective.get_target()], _text_color)
		if QuestManager.is_objective_finished(quest.id, index):
			line.modulate.a = finished_opacity
		entry.add_child(line)
	if QuestManager.state_of(quest.id) == QuestManager.State.READY_TO_TURN_IN:
		entry.add_child(_make_label(TEXT_READY, _highlight_color))
	return entry


## One completed quest: its title, and how often for a repeatable one.
func _make_completed_entry(quest: QuestData) -> Label:
	var text := _title_of(quest)
	if quest.repeatable:
		text = TIMES_FORMAT % [text, QuestManager.times_completed(quest.id)]
	var entry := _make_label(text, _text_color)
	entry.name = String(quest.id)
	return entry


## What a quest is listed under: its name, or for a quest nobody gave the question it is.
func _title_of(quest: QuestData) -> String:
	if quest.is_auto() and quest.summary != "":
		return quest.summary
	return quest.display_name


func _make_heading(text: String) -> Label:
	var heading := _make_label(text, _text_color)
	heading.add_theme_font_size_override(&"font_size", heading_font_size)
	return heading


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	return label


## Frees every child of [param list] at once, not at the end of the frame, so that what is
## read back right after a refresh is the new content only.
func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		child.free()


## Paints the screen with the palette's UI signals for the current world state.
func _apply_palette() -> void:
	var state := WorldState.state
	_text_color = Palette.role(&"text", state)
	_highlight_color = Palette.role(&"highlight", state)
	_panel_box.bg_color = Color(Palette.role(&"panel", state), panel_opacity)
	_selected_tab_box.border_color = _highlight_color
	_tabs.add_theme_color_override(&"font_selected_color", _highlight_color)
	_tabs.add_theme_color_override(&"font_unselected_color", _text_color)
	_tabs.add_theme_color_override(&"font_hovered_color", _text_color)
	_title.add_theme_color_override(&"font_color", _text_color)


func _on_quest_updated(_quest_id: StringName) -> void:
	if is_open():
		refresh()


func _on_world_state_changed(_state: int) -> void:
	_apply_palette()
	if is_open():
		refresh()
