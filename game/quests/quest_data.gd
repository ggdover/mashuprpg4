class_name QuestData
extends Resource
## A quest as data: who gives it, what it asks for, what it pays and what it sets off.
## QuestManager loads every QuestData under res://data/quests/ and does the tracking; its
## class comment has the rules.

## The id every call and signal uses, "q01" for one. Unique among all quests.
@export var id: StringName = &""
## The name shown to the player.
@export var display_name: String = ""
## The story phase the quest belongs to. It cannot be started while GameState.phase is lower.
@export var phase: int = 1
## One or two sentences for the journal. For a quest without a giver this is the question
## the player asks, in the player's own words: the journal shows it in place of the name.
@export_multiline var summary: String = ""
## What has to be done, in the order the journal lists it.
@export var objectives: Array[ObjectiveData] = []
## The NPC who offers the quest. Empty means AUTO: nobody gives it, it is the player's own
## question, and it starts at [member auto_start_marker].
@export var giver_npc: StringName = &""
## The NPC the quest is turned in to once every objective is finished. Empty means it
## completes the moment the last objective finishes.
@export var turn_in_npc: StringName = &""
## Story flags that all have to be set before the quest can be started.
@export var prerequisite_flags: Array[StringName] = []
## Quests that all have to have been completed, at least once, before this one can be started.
@export var prerequisite_quests: Array[StringName] = []
## What completing the quest pays.
@export var rewards: QuestRewards = QuestRewards.new()
## Story flags set the moment the quest starts.
@export var on_start_flags: Array[StringName] = []
## A scripted scene asked for through scene_requested when the quest completes.
@export var on_complete_scene: StringName = &""
## A repeatable quest can be started again as soon as it is completed.
@export var repeatable: bool = false
## For a quest without a giver: it starts by itself when the player walks into the
## QuestTrigger with this marker id, or is in the zone with this id, and it can be started.
@export var auto_start_marker: StringName = &""


## Whether nobody gives the quest: it is the player's own question.
func is_auto() -> bool:
	return giver_npc == &""


## Everything that keeps the quest from working, one sentence each; empty when it is sound.
## QuestManager refuses a quest that has any.
func get_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("the quest has no id")
	for index: int in objectives.size():
		var objective := objectives[index]
		if objective == null:
			problems.append("objective %d is empty" % index)
			continue
		var problem := objective.get_problem()
		if problem != "":
			problems.append("objective %d: %s" % [index, problem])
	if not is_auto() and auto_start_marker != &"":
		problems.append("auto_start_marker is for a quest without a giver; this one has %s" % giver_npc)
	return problems
