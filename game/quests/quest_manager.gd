extends Node
## The quest system. It loads every QuestData under res://data/quests/ at startup, counts
## the objectives of the active quests from what EventBus announces, hands out rewards, and
## announces what happens to a quest on the bus: quest_started, quest_objective_progress,
## quest_updated (after anything about a quest changed), quest_completed, scene_requested.
##
## [b]Starting.[/b] A quest can be started once GameState.phase has reached its phase,
## its prerequisite flags are set and its prerequisite quests have been completed. That is
## worked out whenever it is asked for, and no signal announces it. Its giver offers the
## quest ([method available_for_npc]) and [method start] begins it. A quest without a giver
## begins by itself when the player walks into the QuestTrigger its auto-start marker names,
## or is in the zone it names.
##
## [b]Counting.[/b] An objective counts while its quest is active, it is open and it is not
## finished. It is open unless it has hidden_until_previous and the objective before it is
## unfinished. KILL counts enemy_died for enemies that pass every filter that is set, BOSS
## counts boss_defeated, REACH counts marker_reached and zone_entered, LIGHT_CAIRNS counts
## cairn_lit. COLLECT is the number of the item in [member inventory], so it falls when
## items leave. DELIVER happens in [method try_turn_in], which takes the items. The first
## time an objective is finished it sets its on_complete_flag and asks for its
## on_complete_scene.
##
## [b]Completing.[/b] When every objective is finished, a quest without a turn-in NPC
## completes at once. One with an NPC waits, READY_TO_TURN_IN, for [method try_turn_in]
## with that NPC. A repeatable quest can be started again right after.

## Where a quest stands. [method state_of] returns one.
enum State {
	## It cannot be started yet: a prerequisite is missing, or no quest has the id.
	NOT_AVAILABLE,
	## It can be started.
	AVAILABLE,
	## Started, with objectives left to do.
	ACTIVE,
	## Every objective is finished and the turn-in NPC has yet to be talked to.
	READY_TO_TURN_IN,
	## Done. A repeatable quest never rests here: it is AVAILABLE again.
	COMPLETED,
}

## The folder whose QuestData files are loaded at startup, subfolders included.
const QUEST_DIR := "res://data/quests"
## The file extensions a quest file can have.
const QUEST_EXTENSIONS: Array[String] = ["tres", "res"]
## Bus signals that count toward objectives and that the bus does not declare yet: J09 adds
## boss_defeated(boss_id: StringName), J11 adds cairn_lit(cairn). The manager connects each
## one the bus has to the method named here; until then the methods are called directly.
const LATER_BUS_SIGNALS: Dictionary[StringName, StringName] = {
	&"boss_defeated": &"notify_boss_defeated",
	&"cairn_lit": &"notify_cairn_lit",
}
## Keys of the dictionaries [method to_dict] writes.
const KEY_ACTIVE := "active"
const KEY_COMPLETED := "completed"
const KEY_ID := "id"
const KEY_COUNTS := "counts"
const KEY_LOCKED := "locked"
const KEY_FIRED := "fired"
const KEY_TIMES := "times"

## The player's inventory as the quest system sees it: COLLECT counts what is in it, DELIVER
## takes from it, rewards go into it. A QuestInventory stand-in until the job that has J06's
## Inventory assigns an adapter (see QuestInventory). Assigning null puts an empty stand-in back.
var inventory: QuestInventory:
	set(value):
		if inventory != null:
			inventory.changed.disconnect(_on_inventory_changed)
		inventory = value if value != null else QuestInventory.new()
		inventory.changed.connect(_on_inventory_changed)
		_on_inventory_changed()

## Every quest by id, in the order they were loaded.
var _quests: Dictionary[StringName, QuestData] = {}
## The quests that are under way by id, in the order they were started.
var _runs: Dictionary[StringName, Run] = {}
## How often each quest has been completed, in the order of their first completion.
var _completions: Dictionary[StringName, int] = {}
## Above zero while [method complete] hands out rewards. A flag set then does not start the
## next quest ahead of quest_completed; [method complete] starts it at its end.
var _rewarding: int = 0
## True while [method try_turn_in] takes items out of the inventory, so that the change is
## not read before the delivery is on the books.
var _inventory_muted: bool = false


func _ready() -> void:
	inventory = QuestInventory.new()
	load_quests()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.marker_reached.connect(_on_marker_reached)
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.flag_set.connect(_on_flag_set)
	for signal_name: StringName in LATER_BUS_SIGNALS:
		if EventBus.has_signal(signal_name):
			EventBus.connect(signal_name, Callable(self, LATER_BUS_SIGNALS[signal_name]))


## Forgets every quest and all progress, then loads the quests under [constant QUEST_DIR].
func load_quests() -> void:
	reset()
	_quests.clear()
	for path: String in _list_quest_files(QUEST_DIR):
		var quest := ResourceLoader.load(path) as QuestData
		if quest != null:
			register(quest)
	for id: StringName in _quests:
		for other: StringName in _quests[id].prerequisite_quests:
			if not _quests.has(other):
				push_error("QuestManager: quest '%s' asks for the quest '%s', which does not exist." % [id, other])


## Adds [param quest] to the quests the manager knows. Returns [code]false[/code], and says
## why in an error, for a quest that has problems ([method QuestData.get_problems]) or whose
## id is taken.
func register(quest: QuestData) -> bool:
	if quest == null:
		return false
	var problems := quest.get_problems()
	if _quests.has(quest.id):
		problems.append("another quest has the id already")
	if not problems.is_empty():
		push_error("QuestManager: quest '%s' (%s) is left out: %s." % [quest.id, quest.resource_path, "; ".join(problems)])
		return false
	_quests[quest.id] = quest
	return true


## Forgets all progress, as for a new game: no quest is active or completed. The quests
## themselves stay, and so does [member inventory].
func reset() -> void:
	var touched: Dictionary[StringName, bool] = {}
	for id: StringName in _runs:
		touched[id] = true
	for id: StringName in _completions:
		touched[id] = true
	_runs.clear()
	_completions.clear()
	for id: StringName in touched:
		EventBus.quest_updated.emit(id)


## The quest with [param id], or null.
func get_quest(id: StringName) -> QuestData:
	return _quests.get(id)


## Every quest the manager knows, in the order they were loaded.
func get_quests() -> Array[QuestData]:
	var quests: Array[QuestData] = []
	for id: StringName in _quests:
		quests.append(_quests[id])
	return quests


## Where the quest [param id] stands.
func state_of(id: StringName) -> State:
	var run: Run = _runs.get(id)
	var quest: QuestData = _quests.get(id)
	if quest == null:
		return State.NOT_AVAILABLE
	if run != null:
		# A quest without a turn-in NPC never waits: it completes as its last objective does.
		return State.READY_TO_TURN_IN if run.ready and quest.turn_in_npc != &"" else State.ACTIVE
	if not quest.repeatable and times_completed(id) > 0:
		return State.COMPLETED
	return State.AVAILABLE if _prerequisites_hold(quest) else State.NOT_AVAILABLE


## How often the quest [param id] has been completed: 0 or 1, and more for a repeatable one.
func times_completed(id: StringName) -> int:
	return _completions.get(id, 0)


## The quests that are under way, ACTIVE or READY_TO_TURN_IN, oldest first.
func get_active_quests() -> Array[QuestData]:
	var quests: Array[QuestData] = []
	for id: StringName in _runs:
		quests.append(_quests[id])
	return quests


## The quests that have been completed at least once, in the order they first were.
func get_completed_quests() -> Array[QuestData]:
	var quests: Array[QuestData] = []
	for id: StringName in _completions:
		quests.append(_quests[id])
	return quests


## How far objective [param index] of the quest [param id] has come: 0 up to the
## objective's target. 0 for a quest that is not under way.
func get_objective_count(id: StringName, index: int) -> int:
	var run: Run = _runs.get(id)
	if run == null or index < 0 or index >= run.counts.size():
		return 0
	return run.counts[index]


## Whether objective [param index] of the quest [param id] has reached its target.
func is_objective_finished(id: StringName, index: int) -> bool:
	var run: Run = _runs.get(id)
	if run == null or index < 0 or index >= run.counts.size():
		return false
	return _is_finished(run, _quests[id], index)


## Whether objective [param index] of the quest [param id] is open: the quest is under way
## and nothing hides the objective. The journal lists the open ones.
func is_objective_open(id: StringName, index: int) -> bool:
	var run: Run = _runs.get(id)
	if run == null or index < 0 or index >= run.counts.size():
		return false
	return _is_open(run, _quests[id], index)


## Starts the quest [param id] if it is AVAILABLE and returns whether it did.
func start(id: StringName) -> bool:
	if not _is_known(id) or state_of(id) != State.AVAILABLE:
		return false
	var quest := _quests[id]
	_runs[id] = Run.new(quest.objectives.size())
	EventBus.quest_started.emit(id)
	for flag: StringName in quest.on_start_flags:
		GameState.set_flag(flag)
	_settle(id, true)
	return true


## Adds [param amount] to objective [param index] of the quest [param id], as an event
## that counts would. Nothing happens unless the objective is counting, and never for a
## COLLECT objective, which follows the inventory.
func progress(id: StringName, index: int, amount: int) -> void:
	var run: Run = _runs.get(id)
	if run == null:
		return
	var quest := _quests[id]
	if index < 0 or index >= quest.objectives.size():
		push_error("QuestManager: quest '%s' has no objective %d." % [id, index])
		return
	var objective := quest.objectives[index]
	if objective.type == ObjectiveData.Type.COLLECT or not _is_counting(run, quest, index):
		return
	run.counts[index] = clampi(run.counts[index] + amount, 0, objective.get_target())
	_settle(id)


## The player talks to [param npc_id] about the quest [param id]. Every open DELIVER
## objective for that NPC whose items the player holds is carried out: the items leave the
## inventory. Then, if every objective is finished and the NPC is the quest's turn-in NPC,
## the quest completes. Returns whether the quest was completed by this call.
func try_turn_in(id: StringName, npc_id: StringName) -> bool:
	if not _is_known(id) or npc_id == &"" or not _runs.has(id):
		return false
	var completed_before := times_completed(id)
	_deliver(id, npc_id)
	var run: Run = _runs.get(id)
	if run != null and run.ready and _quests[id].turn_in_npc == npc_id:
		complete(id)
	return times_completed(id) > completed_before


## Completes the quest [param id], which has to be under way, whatever its objectives say:
## the manager calls this once they are finished, and a debug console can force it. Hands
## out the rewards (xp on xp_gained, silver and items into [member inventory], flags through
## GameState), emits quest_completed, asks for the quest's on_complete_scene on
## scene_requested, and leaves a repeatable quest AVAILABLE again. Returns whether it did.
func complete(id: StringName) -> bool:
	if not _is_known(id) or not _runs.has(id):
		return false
	var quest := _quests[id]
	_runs.erase(id)
	_completions[id] = times_completed(id) + 1
	_rewarding += 1
	_hand_out(quest.rewards)
	_rewarding -= 1
	EventBus.quest_completed.emit(id)
	if quest.on_complete_scene != &"":
		EventBus.scene_requested.emit(quest.on_complete_scene)
	EventBus.quest_updated.emit(id)
	_start_auto_quests(GameState.current_zone, id)
	return true


## The quests the NPC [param npc_id] gives that can be started now, for the dialogue's offers.
func available_for_npc(npc_id: StringName) -> Array[QuestData]:
	var quests: Array[QuestData] = []
	if npc_id == &"":
		return quests
	for id: StringName in _quests:
		if _quests[id].giver_npc == npc_id and state_of(id) == State.AVAILABLE:
			quests.append(_quests[id])
	return quests


## The quests under way for which [method try_turn_in] with [param npc_id] would do
## something now: the NPC is the turn-in NPC of a quest whose objectives are finished, or
## the player holds what an open DELIVER objective for the NPC asks for.
func turn_ins_for_npc(npc_id: StringName) -> Array[QuestData]:
	var quests: Array[QuestData] = []
	if npc_id == &"":
		return quests
	for id: StringName in _runs:
		var quest := _quests[id]
		var run := _runs[id]
		if (run.ready and quest.turn_in_npc == npc_id) or not _deliverable(run, quest, npc_id).is_empty():
			quests.append(quest)
	return quests


## Counts the defeat of the boss [param boss_id] toward BOSS objectives. Connected to the
## bus signal boss_defeated once J09 declares it.
func notify_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"":
		return
	_count_event(ObjectiveData.Type.BOSS, func(objective: ObjectiveData) -> bool:
		return objective.boss_id == boss_id)


## Counts a cairn that was lit toward LIGHT_CAIRNS objectives. The zone it counts in is
## the [code]zone_id[/code] of [param cairn] if it has one, else the zone the player is in.
## Connected to the bus signal cairn_lit once J11 declares it.
func notify_cairn_lit(cairn: Variant) -> void:
	var zone := _zone_of(cairn)
	_count_event(ObjectiveData.Type.LIGHT_CAIRNS, func(objective: ObjectiveData) -> bool:
		return objective.zone_id == &"" or objective.zone_id == zone)


## The progress of every quest as plain data that survives JSON, for SaveSystem (J19):
## the quests under way with their objective counts, and how often each quest was completed.
func to_dict() -> Dictionary:
	var active: Array[Dictionary] = []
	for id: StringName in _runs:
		var run := _runs[id]
		active.append({
			KEY_ID: String(id),
			KEY_COUNTS: run.counts.duplicate(),
			KEY_LOCKED: run.locked.duplicate(),
			KEY_FIRED: run.fired.duplicate(),
		})
	var completed: Array[Dictionary] = []
	for id: StringName in _completions:
		completed.append({KEY_ID: String(id), KEY_TIMES: _completions[id]})
	return {KEY_ACTIVE: active, KEY_COMPLETED: completed}


## Replaces all progress with what [method to_dict] wrote into [param data]. Restore
## GameState and the inventory first: COLLECT objectives read the inventory as they come
## back. A quest the game no longer has is dropped, and whatever is missing or malformed
## counts as not started.
func from_dict(data: Dictionary) -> void:
	reset()
	for entry: Variant in _as_array(data.get(KEY_COMPLETED)):
		var id := _saved_id(entry)
		if id != &"":
			_completions[id] = maxi(_as_int((entry as Dictionary).get(KEY_TIMES, 1)), 1)
	for entry: Variant in _as_array(data.get(KEY_ACTIVE)):
		var id := _saved_id(entry)
		if id == &"" or state_of(id) == State.COMPLETED:
			continue
		var saved: Dictionary = entry
		var run := Run.new(_quests[id].objectives.size())
		var counts := _as_array(saved.get(KEY_COUNTS))
		var locked := _as_array(saved.get(KEY_LOCKED))
		var fired := _as_array(saved.get(KEY_FIRED))
		for index: int in run.counts.size():
			var target := _quests[id].objectives[index].get_target()
			if index < counts.size():
				run.counts[index] = clampi(_as_int(counts[index]), 0, target)
			if index < locked.size():
				run.locked[index] = locked[index] is bool and locked[index]
			# Without a record of it, an objective that was saved finished has set off its
			# flag and scene: a scene must not play again because a game was loaded.
			run.fired[index] = run.counts[index] >= target
			if index < fired.size():
				run.fired[index] = fired[index] is bool and fired[index]
		run.announced = run.counts.duplicate()
		_runs[id] = run
	for id: StringName in _completions:
		EventBus.quest_updated.emit(id)
	for id: StringName in _runs.keys():
		_settle(id, true)


## The progress of one quest that is under way.
class Run:
	extends RefCounted

	## How far each objective has come, 0 up to its target.
	var counts: Array[int] = []
	## Per objective: a COLLECT objective that no longer follows the inventory, because a
	## DELIVER objective of the quest has handed its items over.
	var locked: Array[bool] = []
	## Per objective: its on-complete flag and scene have been set off.
	var fired: Array[bool] = []
	## Per objective: the count last announced on quest_objective_progress.
	var announced: Array[int] = []
	## Every objective is finished.
	var ready: bool = false

	func _init(objective_count: int) -> void:
		counts.resize(objective_count)
		locked.resize(objective_count)
		fired.resize(objective_count)
		announced.resize(objective_count)


## Brings the quest [param id] up to date after something that may have moved it, and
## announces what did move. COLLECT objectives take their count from the inventory, a REACH
## objective for the zone the player already stands in is finished, objectives finished for
## the first time set off their flag and scene, and a quest whose objectives are all
## finished becomes ready to turn in, or completes when it has no turn-in NPC.
## [param announce] emits quest_updated even when nothing moved.
func _settle(id: StringName, announce: bool = false) -> void:
	var run: Run = _runs.get(id)
	if run == null:
		return
	var quest := _quests[id]
	var newly_finished: Array[ObjectiveData] = []
	# One pass in list order is enough: an objective only ever waits for the one before it.
	for index: int in quest.objectives.size():
		if not _is_open(run, quest, index):
			continue
		var objective := quest.objectives[index]
		match objective.type:
			ObjectiveData.Type.COLLECT:
				if not run.locked[index]:
					run.counts[index] = mini(inventory.count_of(objective.item_id), objective.get_target())
			ObjectiveData.Type.REACH:
				if objective.zone_id != &"" and objective.zone_id == GameState.current_zone:
					run.counts[index] = objective.get_target()
		if _is_finished(run, quest, index) and not run.fired[index]:
			run.fired[index] = true
			newly_finished.append(objective)
	var was_ready := run.ready
	run.ready = _all_finished(run, quest)
	var moved := announce or run.ready != was_ready or not newly_finished.is_empty()

	# The books are in order from here on, so whoever listens may call back in.
	for index: int in quest.objectives.size():
		if run.counts[index] != run.announced[index]:
			run.announced[index] = run.counts[index]
			moved = true
			EventBus.quest_objective_progress.emit(id, index, run.counts[index], quest.objectives[index].get_target())
	for objective: ObjectiveData in newly_finished:
		if objective.on_complete_flag != &"":
			GameState.set_flag(objective.on_complete_flag)
		if objective.on_complete_scene != &"":
			EventBus.scene_requested.emit(objective.on_complete_scene)
	if moved:
		EventBus.quest_updated.emit(id)
	if run.ready and quest.turn_in_npc == &"" and _runs.get(id) == run:
		complete(id)


## Carries out every open DELIVER objective of the quest [param id] for [param npc_id]
## that the player holds the items for, in list order, and settles every quest afterwards.
func _deliver(id: StringName, npc_id: StringName) -> void:
	var run := _runs[id]
	var quest := _quests[id]
	# Looked up one at a time: a delivery can open the next DELIVER objective in the list.
	var due := _deliverable(run, quest, npc_id)
	while not due.is_empty():
		var index := due[0]
		var objective := quest.objectives[index]
		_inventory_muted = true
		var taken := inventory.remove(objective.item_id, objective.get_target())
		_inventory_muted = false
		if not taken:
			break
		run.counts[index] = objective.get_target()
		# The COLLECT objectives that gathered these items keep what they showed instead of
		# following the inventory down. Their counts are from before the items were taken.
		for other: int in quest.objectives.size():
			var gathered := quest.objectives[other]
			if gathered.type == ObjectiveData.Type.COLLECT and gathered.item_id == objective.item_id and _is_finished(run, quest, other):
				run.locked[other] = true
		due = _deliverable(run, quest, npc_id)
	_on_inventory_changed()


## The indices of the open, unfinished DELIVER objectives of [param quest] for
## [param npc_id] whose items the player holds.
func _deliverable(run: Run, quest: QuestData, npc_id: StringName) -> Array[int]:
	var indices: Array[int] = []
	for index: int in quest.objectives.size():
		var objective := quest.objectives[index]
		if objective.type != ObjectiveData.Type.DELIVER or objective.npc_id != npc_id:
			continue
		if _is_counting(run, quest, index) and inventory.count_of(objective.item_id) >= objective.get_target():
			indices.append(index)
	return indices


## Hands out [param rewards]: xp, silver, items, flags.
func _hand_out(rewards: QuestRewards) -> void:
	if rewards == null:
		return
	if rewards.xp > 0:
		EventBus.xp_gained.emit(rewards.xp)
	if rewards.silver > 0:
		inventory.add_silver(rewards.silver)
	for item_id: StringName in rewards.item_ids:
		if not inventory.add(item_id, 1):
			push_warning("QuestManager: the reward item '%s' did not go into the inventory." % item_id)
	for flag: StringName in rewards.flags:
		GameState.set_flag(flag)


## Adds one to every counting objective of [param type] that [param matches] accepts, in
## every quest under way. [param matches] takes an ObjectiveData and returns a bool.
func _count_event(type: ObjectiveData.Type, matches: Callable) -> void:
	# A copy of the ids: settling can complete a quest and start another.
	for id: StringName in _runs.keys():
		var run: Run = _runs.get(id)
		if run == null:
			continue
		var quest := _quests[id]
		# Found first and counted after, so that an objective this event opens does not
		# count the event too.
		var hits: Array[int] = []
		for index: int in quest.objectives.size():
			var objective := quest.objectives[index]
			if objective.type == type and _is_counting(run, quest, index) and matches.call(objective):
				hits.append(index)
		for index: int in hits:
			run.counts[index] += 1
		if not hits.is_empty():
			_settle(id)


## Starts every AVAILABLE quest without a giver whose auto-start marker is [param place], a
## marker id or a zone id. [param except] is left alone: a repeatable quest that has just
## completed in its own auto-start zone waits for the player to come back, or it could
## start itself forever.
func _start_auto_quests(place: StringName, except: StringName = &"") -> void:
	if place == &"":
		return
	for id: StringName in _quests:
		var quest := _quests[id]
		if id != except and quest.is_auto() and quest.auto_start_marker == place:
			start(id)


func _on_enemy_died(enemy: Node) -> void:
	_count_event(ObjectiveData.Type.KILL, func(objective: ObjectiveData) -> bool:
		return _kill_matches(objective, enemy))


func _on_marker_reached(id: StringName) -> void:
	if id == &"":
		return
	_count_event(ObjectiveData.Type.REACH, func(objective: ObjectiveData) -> bool:
		return objective.marker_id == id)
	_start_auto_quests(id)


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id == &"":
		return
	_count_event(ObjectiveData.Type.REACH, func(objective: ObjectiveData) -> bool:
		return objective.zone_id == zone_id)
	_start_auto_quests(zone_id)


## A flag may be the last thing a quest waited for whose auto-start zone the player is
## standing in already.
func _on_flag_set(_flag: StringName) -> void:
	if _rewarding == 0:
		_start_auto_quests(GameState.current_zone)


func _on_inventory_changed() -> void:
	if _inventory_muted:
		return
	for id: StringName in _runs.keys():
		_settle(id)


## Whether the enemy that died passes every filter [param objective] sets. The enemy's
## [code]data[/code] (J07's EnemyData) carries id, animal and category.
func _kill_matches(objective: ObjectiveData, enemy: Node) -> bool:
	var data: Variant = _field(enemy, &"data")
	if objective.enemy_id != &"" and _as_name(_field(data, &"id")) != objective.enemy_id:
		return false
	if objective.enemy_animal != ObjectiveData.Animal.ANY and _as_int(_field(data, &"animal"), ObjectiveData.Animal.ANY) != objective.enemy_animal:
		return false
	if objective.enemy_category != ObjectiveData.Category.ANY and _as_int(_field(data, &"category"), ObjectiveData.Category.ANY) != objective.enemy_category:
		return false
	return objective.zone_id == &"" or objective.zone_id == _zone_of(enemy)


func _prerequisites_hold(quest: QuestData) -> bool:
	if GameState.phase < quest.phase:
		return false
	for flag: StringName in quest.prerequisite_flags:
		if not GameState.has_flag(flag):
			return false
	for other: StringName in quest.prerequisite_quests:
		if times_completed(other) == 0:
			return false
	return true


func _is_open(run: Run, quest: QuestData, index: int) -> bool:
	return index == 0 or not quest.objectives[index].hidden_until_previous or _is_finished(run, quest, index - 1)


func _is_finished(run: Run, quest: QuestData, index: int) -> bool:
	return run.counts[index] >= quest.objectives[index].get_target()


func _is_counting(run: Run, quest: QuestData, index: int) -> bool:
	return _is_open(run, quest, index) and not _is_finished(run, quest, index)


func _all_finished(run: Run, quest: QuestData) -> bool:
	for index: int in quest.objectives.size():
		if not _is_finished(run, quest, index):
			return false
	return true


## Whether a quest has the id; an unknown id is a mistake in the caller and is reported.
func _is_known(id: StringName) -> bool:
	if _quests.has(id):
		return true
	push_error("QuestManager: there is no quest '%s'." % id)
	return false


## The zone something happened in: the [code]zone_id[/code] of [param source] when it has
## one, else the zone the player is in.
func _zone_of(source: Variant) -> StringName:
	var zone := _as_name(_field(source, &"zone_id"))
	return zone if zone != &"" else GameState.current_zone


## The .tres and .res files under [param dir], subfolders included, in a fixed order.
func _list_quest_files(dir: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var entries := ResourceLoader.list_directory(dir)
	entries.sort()
	for entry: String in entries:
		var path := dir.path_join(entry)
		if entry.ends_with("/"):
			paths.append_array(_list_quest_files(path))
		elif QUEST_EXTENSIONS.has(entry.get_extension()):
			paths.append(path)
	return paths


## The quest id in an entry of a saved dictionary, or an empty name when the entry is
## malformed or names a quest the game does not have.
func _saved_id(entry: Variant) -> StringName:
	if not entry is Dictionary:
		return &""
	var id := _as_name((entry as Dictionary).get(KEY_ID))
	return id if _quests.has(id) else &""


## The property [param field] of [param source], or null when [param source] is no live
## object or has no such property. Enemies and cairns are read this way: their classes
## belong to jobs this one does not depend on.
static func _field(source: Variant, field: StringName) -> Variant:
	if is_instance_valid(source):
		return (source as Object).get(field)
	return null


static func _as_name(value: Variant) -> StringName:
	if value is StringName or value is String:
		return StringName(value)
	return &""


## [param value] as an int: JSON hands every number back as a float. [param fallback] for
## anything that is no number.
static func _as_int(value: Variant, fallback: int = 0) -> int:
	if value is int or value is float:
		return int(value)
	return fallback


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
