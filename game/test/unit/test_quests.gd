extends GutTest
## The quest system: QuestManager counts objectives from what the EventBus announces, gates
## quests behind prerequisites, hands out rewards and announces what happens to a quest.
##
## Most quests here are built in code and registered with the manager, next to the test
## chain it loads from res://data/quests/. The enemies and the cairn are stand-ins for the
## classes of J07 and J11, which the manager reads by property name.

const KILL := ObjectiveData.Type.KILL
const BOSS := ObjectiveData.Type.BOSS
const COLLECT := ObjectiveData.Type.COLLECT
const REACH := ObjectiveData.Type.REACH
const DELIVER := ObjectiveData.Type.DELIVER
const LIGHT_CAIRNS := ObjectiveData.Type.LIGHT_CAIRNS
const BOAR := ObjectiveData.Animal.BOAR
const WOLF := ObjectiveData.Animal.WOLF
const RAVEN := ObjectiveData.Animal.RAVEN
const NEUTRAL := ObjectiveData.Category.NEUTRAL
const POSSESSED := ObjectiveData.Category.POSSESSED

const QUEST := &"hunt"
const NPC := &"test_keeper"
const OTHER_NPC := &"test_smith"
const ZONE := &"test_woods"
const OTHER_ZONE := &"test_meadow"
const ITEM := &"test_pelt"
const OTHER_ITEM := &"test_hide"
const MARKER := &"test_oak"
const QUEST_MANAGER_SCRIPT := "res://quests/quest_manager.gd"


func before_each() -> void:
	_fresh_game()


func after_each() -> void:
	_fresh_game()


# --- The data on disk ---------------------------------------------------------------------


func test_the_test_chain_is_loaded_at_startup() -> void:
	for id: StringName in [&"test_a", &"test_b", &"test_c"]:
		var quest := QuestManager.get_quest(id)
		assert_not_null(quest, "%s is loaded" % id)
		assert_true(quest.resource_path.begins_with("res://data/quests/test_chain/"), "from a subfolder of res://data/quests/")
	for quest: QuestData in QuestManager.get_quests():
		assert_eq(quest.get_problems().size(), 0, "%s is sound" % quest.id)
		assert_eq(QuestManager.get_quest(quest.id), quest, "%s is found by its id" % quest.id)


func test_the_test_chain_reads_as_the_job_asks() -> void:
	var a := QuestManager.get_quest(&"test_a")
	assert_eq(a.objectives.size(), 1)
	assert_eq(a.objectives[0].type, KILL, "A: kill")
	assert_eq(a.objectives[0].enemy_id, &"test_dummy", "by enemy id")
	assert_eq(a.objectives[0].target_count, 3, "three of them")
	assert_eq(a.turn_in_npc, &"", "A completes by itself")
	assert_true(a.rewards.flags.has(&"a_done"), "and sets a_done")

	var b := QuestManager.get_quest(&"test_b")
	assert_true(b.prerequisite_flags.has(&"a_done"), "B requires a_done")
	assert_eq(b.objectives.size(), 2)
	assert_eq(b.objectives[0].type, COLLECT, "B: collect")
	assert_eq(b.objectives[0].item_id, &"test_item")
	assert_eq(b.objectives[0].target_count, 2, "two test items")
	assert_eq(b.objectives[1].type, DELIVER, "then deliver")
	assert_eq(b.objectives[1].npc_id, &"test_npc", "to the test NPC")
	assert_eq(b.turn_in_npc, &"test_npc")

	var c := QuestManager.get_quest(&"test_c")
	assert_true(c.repeatable, "C is repeatable")
	assert_eq(c.objectives.size(), 1)
	assert_eq(c.objectives[0].type, REACH, "C: reach")
	assert_eq(c.objectives[0].marker_id, &"test_c_goal", "a marker")
	assert_true(c.is_auto(), "nobody gives C: it is the player's own question")


func test_an_objective_without_the_filter_its_type_needs_is_a_problem() -> void:
	for type: ObjectiveData.Type in [BOSS, COLLECT, REACH, DELIVER]:
		assert_ne(_objective(type).get_problem(), "", "type %d cannot work without its filter" % type)
	for type: ObjectiveData.Type in [KILL, LIGHT_CAIRNS]:
		assert_eq(_objective(type).get_problem(), "", "type %d counts everything without filters" % type)
	var deliver := _objective(DELIVER)
	deliver.item_id = ITEM
	assert_ne(deliver.get_problem(), "", "DELIVER needs the NPC as well as the item")
	deliver.npc_id = NPC
	assert_eq(deliver.get_problem(), "")
	var reach := _objective(REACH)
	reach.zone_id = ZONE
	assert_eq(reach.get_problem(), "", "a zone is enough for REACH")


func test_a_quest_reports_what_keeps_it_from_working() -> void:
	var quest := QuestData.new()
	quest.objectives = [_objective(BOSS), null]
	var problems := quest.get_problems()
	assert_eq(problems.size(), 3, "no id, a boss objective without a boss, an empty objective")
	quest.id = QUEST
	quest.objectives = [_objective(KILL)]
	assert_eq(quest.get_problems().size(), 0)


# --- KILL ---------------------------------------------------------------------------------


func test_kill_counts_enemies_with_its_enemy_id_only() -> void:
	var objective := _objective(KILL, 5)
	objective.enemy_id = &"fox_possessed"
	_start_quest([objective])
	_kill(&"fox_possessed")
	_kill(&"fox_neutral")
	_kill(&"fox_possessed")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "the other fox does not count")


func test_kill_needs_every_filter_that_is_set_to_match() -> void:
	var objective := _objective(KILL, 9)
	objective.enemy_animal = RAVEN
	objective.enemy_category = POSSESSED
	objective.zone_id = ZONE
	_start_quest([objective])
	_kill(&"raven_possessed", RAVEN, POSSESSED, ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "a possessed raven in the woods counts")
	_kill(&"raven_neutral", RAVEN, NEUTRAL, ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "a neutral raven does not")
	_kill(&"wolf_possessed", WOLF, POSSESSED, ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "nor a possessed wolf")
	_kill(&"raven_possessed", RAVEN, POSSESSED, OTHER_ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "nor a possessed raven somewhere else")
	_kill(&"test_raven_boss", RAVEN, POSSESSED, ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "the enemy id is no filter here")


func test_kill_by_animal_alone_takes_both_categories() -> void:
	var objective := _objective(KILL, 8)
	objective.enemy_animal = BOAR
	_start_quest([objective])
	_kill(&"boar_neutral", BOAR, NEUTRAL)
	_kill(&"boar_possessed", BOAR, POSSESSED)
	_kill(&"wolf_neutral", WOLF, NEUTRAL)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "boars of either kind, and no wolf")


func test_kill_by_category_alone_takes_every_animal() -> void:
	var objective := _objective(KILL, 8)
	objective.enemy_category = NEUTRAL
	_start_quest([objective])
	_kill(&"boar_neutral", BOAR, NEUTRAL)
	_kill(&"wolf_neutral", WOLF, NEUTRAL)
	_kill(&"wolf_possessed", WOLF, POSSESSED)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "neutral animals of any kind, and nothing possessed")


func test_kill_without_filters_counts_every_enemy() -> void:
	_start_quest([_objective(KILL, 5)])
	_kill(&"fox_possessed", ObjectiveData.Animal.FOX, POSSESSED, ZONE)
	_kill(&"boar_neutral", BOAR, NEUTRAL, OTHER_ZONE)
	_announce_death_of(Node3D.new())
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 3, "even an enemy that carries no data")


func test_an_enemy_without_data_passes_no_filter() -> void:
	var objective := _objective(KILL, 5)
	objective.enemy_animal = BOAR
	_start_quest([objective])
	_announce_death_of(Node3D.new())
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0, "BOAR is 0, and a missing animal must not read as 0")


func test_an_enemy_without_a_zone_counts_for_the_zone_the_player_is_in() -> void:
	var objective := _objective(KILL, 5)
	objective.zone_id = ZONE
	_start_quest([objective])
	GameState.current_zone = ZONE
	_kill(&"boar_neutral")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "the enemy names no zone: the player's counts")
	GameState.current_zone = OTHER_ZONE
	_kill(&"boar_neutral")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1)
	_kill(&"boar_neutral", BOAR, NEUTRAL, ZONE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "the enemy's own zone comes first")


func test_kills_count_for_active_quests_only() -> void:
	var objective := _objective(KILL, 2)
	var quest := _add_quest([objective])
	_kill(&"boar_neutral")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0, "not started yet")
	QuestManager.start(QUEST)
	_kill(&"boar_neutral")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1)
	assert_eq(quest.objectives[0].target_count, 2, "the quest data is never written to")


func test_the_animal_and_category_values_are_those_of_enemy_data() -> void:
	# The kill filters compare an enemy's animal and category by value with the enums of
	# ObjectiveData. J07 brings EnemyData; until it is in the project there is nothing to
	# compare with, and from then on a drift between the two fails here.
	var enemy_data := _script_of_class("EnemyData")
	if enemy_data == null:
		pass_test("EnemyData (J07) is not in the project yet")
		return
	var constants := enemy_data.get_script_constant_map()
	_assert_enum_matches(ObjectiveData.Animal, constants, "BOAR")
	_assert_enum_matches(ObjectiveData.Category, constants, "POSSESSED")


# --- BOSS, REACH, LIGHT_CAIRNS ------------------------------------------------------------


func test_boss_finishes_on_the_defeat_of_its_boss() -> void:
	var objective := _objective(BOSS)
	objective.boss_id = &"test_raven_boss"
	_start_quest([objective], NPC)
	QuestManager.notify_boss_defeated(&"test_wolf_boss")
	assert_false(QuestManager.is_objective_finished(QUEST, 0), "another boss")
	QuestManager.notify_boss_defeated(&"test_raven_boss")
	assert_true(QuestManager.is_objective_finished(QUEST, 0))


func test_reach_finishes_on_its_marker() -> void:
	var objective := _objective(REACH)
	objective.marker_id = MARKER
	_start_quest([objective], NPC)
	EventBus.marker_reached.emit(&"some_other_marker")
	assert_false(QuestManager.is_objective_finished(QUEST, 0))
	EventBus.zone_entered.emit(MARKER)
	assert_false(QuestManager.is_objective_finished(QUEST, 0), "a zone with the marker's id is not the marker")
	EventBus.marker_reached.emit(MARKER)
	assert_true(QuestManager.is_objective_finished(QUEST, 0))


func test_reach_finishes_on_entering_its_zone() -> void:
	var objective := _objective(REACH)
	objective.zone_id = ZONE
	_start_quest([objective], NPC)
	EventBus.zone_entered.emit(OTHER_ZONE)
	assert_false(QuestManager.is_objective_finished(QUEST, 0))
	EventBus.zone_entered.emit(ZONE)
	assert_true(QuestManager.is_objective_finished(QUEST, 0))


func test_reach_is_finished_at_once_when_the_player_stands_in_the_zone() -> void:
	var objective := _objective(REACH)
	objective.zone_id = ZONE
	GameState.current_zone = ZONE
	_start_quest([objective], NPC)
	assert_true(QuestManager.is_objective_finished(QUEST, 0), "no need to leave and come back")


func test_light_cairns_counts_cairns_lit_in_its_zone() -> void:
	var objective := _objective(LIGHT_CAIRNS, 6)
	objective.zone_id = ZONE
	_start_quest([objective])
	var cairn: Node3D = autofree(Node3D.new())
	GameState.current_zone = ZONE
	QuestManager.notify_cairn_lit(cairn)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "lit where the player is, which is the zone asked for")
	GameState.current_zone = OTHER_ZONE
	QuestManager.notify_cairn_lit(cairn)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "a cairn in another zone")
	var placed: FakeCairn = autofree(FakeCairn.new())
	placed.zone_id = ZONE
	QuestManager.notify_cairn_lit(placed)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "a cairn that names its zone counts there")


func test_light_cairns_without_a_zone_counts_every_cairn() -> void:
	_start_quest([_objective(LIGHT_CAIRNS, 2)])
	GameState.current_zone = ZONE
	QuestManager.notify_cairn_lit(autofree(Node3D.new()))
	GameState.current_zone = OTHER_ZONE
	QuestManager.notify_cairn_lit(autofree(Node3D.new()))
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)


func test_boss_defeated_and_cairn_lit_are_heard_once_the_bus_declares_them() -> void:
	# J09 and J11 add the two signals to the EventBus. A signal the bus has by now only
	# needs the autoload to be listening. For one it lacks, the test adds it for its own
	# length and lets a manager of its own become ready, connect and hear it; nothing else
	# can be listening to a signal that does not exist yet.
	var added: Array[StringName] = []
	for signal_name: StringName in QuestManager.LATER_BUS_SIGNALS:
		if EventBus.has_signal(signal_name):
			var listener := Callable(QuestManager, QuestManager.LATER_BUS_SIGNALS[signal_name])
			assert_true(EventBus.is_connected(signal_name, listener), "QuestManager listens to %s" % signal_name)
		else:
			EventBus.add_user_signal(signal_name, [{"name": "what", "type": TYPE_NIL}])
			added.append(signal_name)
	if added.is_empty():
		return
	var manager: Node = (load(QUEST_MANAGER_SCRIPT) as GDScript).new()
	add_child_autofree(manager)
	var boss := _objective(BOSS)
	boss.boss_id = &"test_raven_boss"
	var quest := QuestData.new()
	quest.id = QUEST
	quest.turn_in_npc = NPC
	quest.objectives = [boss, _objective(LIGHT_CAIRNS)]
	manager.register(quest)
	manager.start(QUEST)
	if added.has(&"boss_defeated"):
		EventBus.emit_signal(&"boss_defeated", &"test_raven_boss")
		assert_true(manager.is_objective_finished(QUEST, 0), "boss_defeated on the bus finishes the BOSS objective")
	if added.has(&"cairn_lit"):
		EventBus.emit_signal(&"cairn_lit", autofree(Node3D.new()))
		assert_true(manager.is_objective_finished(QUEST, 1), "cairn_lit on the bus counts for LIGHT_CAIRNS")
	for signal_name: StringName in added:
		EventBus.remove_user_signal(signal_name)


# --- COLLECT ------------------------------------------------------------------------------


func test_collect_follows_the_inventory_up_and_down() -> void:
	var objective := _objective(COLLECT, 3)
	objective.item_id = ITEM
	_start_quest([objective], NPC)
	watch_signals(EventBus)
	QuestManager.inventory.add(ITEM, 2)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2)
	assert_signal_emitted_with_parameters(EventBus, "quest_objective_progress", [QUEST, 0, 2, 3])
	QuestManager.inventory.remove(ITEM, 1)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "dropping an item takes the progress back")
	assert_signal_emitted_with_parameters(EventBus, "quest_objective_progress", [QUEST, 0, 1, 3])
	QuestManager.inventory.add(OTHER_ITEM, 5)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "another item is another matter")
	assert_signal_emit_count(EventBus, "quest_objective_progress", 2, "and moves nothing")


func test_collect_counts_what_the_player_holds_when_the_quest_starts() -> void:
	var objective := _objective(COLLECT, 3)
	objective.item_id = ITEM
	QuestManager.inventory.add(ITEM, 2)
	_start_quest([objective], NPC)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2)


func test_collect_never_shows_more_than_its_target() -> void:
	var objective := _objective(COLLECT, 3)
	objective.item_id = ITEM
	_start_quest([objective], NPC)
	QuestManager.inventory.add(ITEM, 7)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 3)
	assert_true(QuestManager.is_objective_finished(QUEST, 0))
	QuestManager.inventory.remove(ITEM, 3)
	assert_true(QuestManager.is_objective_finished(QUEST, 0), "four are left: still enough")
	QuestManager.inventory.remove(ITEM, 2)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2)


func test_collect_follows_an_inventory_that_is_put_in_place_later() -> void:
	# What J16 does with its adapter over J06's Inventory.
	var objective := _objective(COLLECT, 3)
	objective.item_id = ITEM
	_start_quest([objective], NPC)
	var stand_in := QuestManager.inventory
	var real := QuestInventory.new()
	real.add(ITEM, 2)
	QuestManager.inventory = real
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "read the moment it is assigned")
	real.remove(ITEM, 1)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "and followed from then on")
	stand_in.add(ITEM, 9)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1, "the one it replaced is no longer listened to")
	QuestManager.inventory = null
	assert_not_null(QuestManager.inventory, "taking the inventory away leaves an empty stand-in")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0)


func test_the_stand_in_inventory_counts_what_goes_in_and_out() -> void:
	var inventory := QuestInventory.new()
	watch_signals(inventory)
	assert_eq(inventory.count_of(ITEM), 0)
	assert_true(inventory.add(ITEM, 3))
	assert_false(inventory.remove(ITEM, 4), "not more than there is")
	assert_eq(inventory.count_of(ITEM), 3, "and then nothing is taken")
	assert_true(inventory.remove(ITEM, 2))
	assert_eq(inventory.count_of(ITEM), 1)
	inventory.add_silver(12)
	assert_eq(inventory.silver, 12)
	assert_signal_emit_count(inventory, "changed", 2, "one for the add, one for the removal that happened")


func test_a_quest_ready_to_turn_in_goes_back_to_active_when_its_items_leave() -> void:
	var objective := _objective(COLLECT, 2)
	objective.item_id = ITEM
	_start_quest([objective], NPC)
	QuestManager.inventory.add(ITEM, 2)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN)
	QuestManager.inventory.remove(ITEM, 1)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)
	assert_false(QuestManager.try_turn_in(QUEST, NPC), "nothing to turn in with one item short")
	QuestManager.inventory.add(ITEM, 1)
	assert_true(QuestManager.try_turn_in(QUEST, NPC))
	assert_eq(QuestManager.inventory.count_of(ITEM), 2, "COLLECT alone takes nothing from the player")


# --- DELIVER ------------------------------------------------------------------------------


func test_deliver_takes_the_items_when_the_player_talks_to_its_npc() -> void:
	var deliver := _deliver_objective(ITEM, 2, NPC)
	_start_quest([deliver, _objective(KILL)])
	QuestManager.inventory.add(ITEM, 3)
	assert_false(QuestManager.try_turn_in(QUEST, OTHER_NPC), "the smith is not who it is for")
	assert_eq(QuestManager.inventory.count_of(ITEM), 3)
	assert_false(QuestManager.try_turn_in(QUEST, NPC), "the delivery is made, and the quest goes on")
	assert_true(QuestManager.is_objective_finished(QUEST, 0))
	assert_eq(QuestManager.inventory.count_of(ITEM), 1, "two were handed over")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE, "the kill is still to do")


func test_deliver_does_nothing_while_the_player_holds_too_few() -> void:
	_start_quest([_deliver_objective(ITEM, 2, NPC)])
	QuestManager.inventory.add(ITEM, 1)
	assert_false(QuestManager.try_turn_in(QUEST, NPC))
	assert_eq(QuestManager.inventory.count_of(ITEM), 1, "nothing is taken")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0)
	assert_eq(QuestManager.turn_ins_for_npc(NPC).size(), 0, "so the NPC has nothing to offer")


func test_a_quest_whose_last_objective_is_a_delivery_completes_in_the_same_talk() -> void:
	var collect := _objective(COLLECT, 2)
	collect.item_id = ITEM
	var deliver := _deliver_objective(ITEM, 2, NPC)
	deliver.hidden_until_previous = true
	_start_quest([collect, deliver], NPC)
	QuestManager.inventory.add(ITEM, 2)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE, "collected, not yet delivered")
	assert_true(QuestManager.try_turn_in(QUEST, NPC), "delivered and turned in at once")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_eq(QuestManager.inventory.count_of(ITEM), 0, "the items are gone")


func test_a_delivery_does_not_take_the_collect_objective_back() -> void:
	var collect := _objective(COLLECT, 2)
	collect.item_id = ITEM
	var deliver := _deliver_objective(ITEM, 2, NPC)
	deliver.hidden_until_previous = true
	_start_quest([collect, deliver, _objective(KILL)], OTHER_NPC)
	QuestManager.inventory.add(ITEM, 2)
	QuestManager.try_turn_in(QUEST, NPC)
	assert_eq(QuestManager.inventory.count_of(ITEM), 0)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "the collecting stays done although the items left")
	assert_true(QuestManager.is_objective_finished(QUEST, 1))
	_kill(&"boar_neutral")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN, "so the quest can still be finished")


func test_two_kinds_of_item_are_delivered_in_one_talk() -> void:
	# Q10's shape: pelts and hides, collected side by side, handed to the tanner in order.
	var pelts := _objective(COLLECT, 6)
	pelts.item_id = ITEM
	var hides := _objective(COLLECT, 2)
	hides.item_id = OTHER_ITEM
	var hand_pelts := _deliver_objective(ITEM, 6, NPC)
	hand_pelts.hidden_until_previous = true
	var hand_hides := _deliver_objective(OTHER_ITEM, 2, NPC)
	hand_hides.hidden_until_previous = true
	_start_quest([pelts, hides, hand_pelts, hand_hides], NPC)
	QuestManager.inventory.add(ITEM, 6)
	assert_eq(QuestManager.turn_ins_for_npc(NPC).size(), 0, "the hides are missing")
	QuestManager.inventory.add(OTHER_ITEM, 2)
	assert_eq(QuestManager.turn_ins_for_npc(NPC).size(), 1)
	assert_true(QuestManager.try_turn_in(QUEST, NPC))
	assert_eq(QuestManager.inventory.count_of(ITEM), 0)
	assert_eq(QuestManager.inventory.count_of(OTHER_ITEM), 0)


func test_a_delivery_completes_a_quest_that_has_no_turn_in_npc() -> void:
	_start_quest([_deliver_objective(ITEM, 1, NPC)])
	QuestManager.inventory.add(ITEM, 1)
	assert_true(QuestManager.try_turn_in(QUEST, NPC), "the call that delivered completed the quest")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)


# --- Objectives in order ------------------------------------------------------------------


func test_a_hidden_objective_counts_nothing_until_the_one_before_it_is_finished() -> void:
	# Q04's shape: boars, then the path home, then the alpha.
	var boars := _objective(KILL, 2)
	boars.enemy_animal = BOAR
	var path := _objective(REACH)
	path.marker_id = MARKER
	path.hidden_until_previous = true
	var alpha := _objective(BOSS)
	alpha.boss_id = &"test_wolf_boss"
	alpha.hidden_until_previous = true
	_start_quest([boars, path, alpha], NPC)
	assert_true(QuestManager.is_objective_open(QUEST, 0))
	assert_false(QuestManager.is_objective_open(QUEST, 1), "the path home is not in the journal yet")
	assert_false(QuestManager.is_objective_open(QUEST, 2))

	EventBus.marker_reached.emit(MARKER)
	QuestManager.notify_boss_defeated(&"test_wolf_boss")
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 0, "walking the path before the boars are done counts nothing")
	assert_eq(QuestManager.get_objective_count(QUEST, 2), 0)

	_kill(&"boar", BOAR)
	_kill(&"boar", BOAR)
	assert_true(QuestManager.is_objective_open(QUEST, 1), "the boars are done: the path opens")
	assert_false(QuestManager.is_objective_open(QUEST, 2), "the alpha waits for the path")
	QuestManager.notify_boss_defeated(&"test_wolf_boss")
	assert_eq(QuestManager.get_objective_count(QUEST, 2), 0)

	EventBus.marker_reached.emit(MARKER)
	assert_true(QuestManager.is_objective_open(QUEST, 2))
	QuestManager.notify_boss_defeated(&"test_wolf_boss")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN)


func test_the_kill_that_finishes_an_objective_does_not_count_for_the_next() -> void:
	var first := _objective(KILL, 1)
	var second := _objective(KILL, 2)
	second.hidden_until_previous = true
	_start_quest([first, second])
	_kill(&"wolf")
	assert_true(QuestManager.is_objective_finished(QUEST, 0))
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 0, "the second objective opened after that kill")
	_kill(&"wolf")
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 1)


func test_objectives_that_are_not_hidden_count_side_by_side() -> void:
	var wolves := _objective(KILL, 2)
	wolves.enemy_animal = WOLF
	var boars := _objective(KILL, 2)
	boars.enemy_animal = BOAR
	_start_quest([wolves, boars])
	_kill(&"boar", BOAR)
	_kill(&"wolf", WOLF)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 1)
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 1)
	assert_true(QuestManager.is_objective_open(QUEST, 1), "both are in the journal from the start")


func test_a_finished_objective_stops_counting() -> void:
	_start_quest([_objective(KILL, 2), _objective(KILL, 9)])
	for i: int in 4:
		_kill(&"wolf")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "never past the target")


# --- Hooks on objectives and on the start -------------------------------------------------


func test_an_objective_flag_is_set_exactly_once() -> void:
	var boars := _objective(KILL, 2)
	boars.on_complete_flag = &"test_fog"
	_start_quest([boars, _objective(KILL, 9)])
	watch_signals(EventBus)
	_kill(&"boar")
	assert_false(GameState.has_flag(&"test_fog"), "not before the objective is finished")
	_kill(&"boar")
	assert_true(GameState.has_flag(&"test_fog"), "the moment it finishes")
	_kill(&"boar")
	_kill(&"boar")
	assert_signal_emit_count(EventBus, "flag_set", 1, "and never again")
	assert_signal_emitted_with_parameters(EventBus, "flag_set", [&"test_fog"])


func test_an_objective_scene_is_asked_for_once_though_collect_finishes_twice() -> void:
	var collect := _objective(COLLECT, 2)
	collect.item_id = ITEM
	collect.on_complete_flag = &"test_found"
	collect.on_complete_scene = &"test_voices"
	_start_quest([collect], NPC)
	watch_signals(EventBus)
	QuestManager.inventory.add(ITEM, 2)
	QuestManager.inventory.remove(ITEM, 1)
	QuestManager.inventory.add(ITEM, 1)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2, "finished, unfinished, finished again")
	assert_signal_emit_count(EventBus, "scene_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "scene_requested", [&"test_voices"])
	assert_signal_emit_count(EventBus, "flag_set", 1)


func test_on_start_flags_are_set_when_the_quest_starts() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.on_start_flags = [&"test_henhouse_open"]
	assert_false(GameState.has_flag(&"test_henhouse_open"))
	QuestManager.start(QUEST)
	assert_true(GameState.has_flag(&"test_henhouse_open"))


# --- Completing ---------------------------------------------------------------------------


func test_a_quest_without_turn_in_npc_completes_the_moment_its_last_objective_finishes() -> void:
	_start_quest([_objective(KILL, 2)])
	watch_signals(EventBus)
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_signal_emitted_with_parameters(EventBus, "quest_completed", [QUEST])
	assert_eq(QuestManager.get_active_quests().size(), 0)
	assert_eq(QuestManager.get_completed_quests().size(), 1)


func test_a_quest_without_turn_in_npc_is_never_seen_waiting_to_be_turned_in() -> void:
	_start_quest([_objective(KILL)])
	var seen: Array[int] = []
	var on_updated := func(id: StringName) -> void: seen.append(QuestManager.state_of(id))
	EventBus.quest_updated.connect(on_updated)
	_kill(&"wolf")
	EventBus.quest_updated.disconnect(on_updated)
	assert_false(seen.has(QuestManager.State.READY_TO_TURN_IN), "whoever listens sees it active, then completed")
	assert_eq(seen.back(), QuestManager.State.COMPLETED)


func test_a_quest_with_a_turn_in_npc_waits_for_the_talk() -> void:
	_start_quest([_objective(KILL, 1)], NPC)
	watch_signals(EventBus)
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN)
	assert_signal_not_emitted(EventBus, "quest_completed")
	assert_false(QuestManager.try_turn_in(QUEST, OTHER_NPC), "the smith is not the turn-in NPC")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN)
	assert_true(QuestManager.try_turn_in(QUEST, NPC))
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_signal_emit_count(EventBus, "quest_completed", 1)


func test_try_turn_in_before_the_objectives_are_finished_does_nothing() -> void:
	_start_quest([_objective(KILL, 2)], NPC)
	_kill(&"wolf")
	assert_false(QuestManager.try_turn_in(QUEST, NPC))
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)


func test_complete_forces_a_quest_under_way_and_no_other() -> void:
	var quest := _add_quest([_objective(KILL, 5)], NPC)
	quest.rewards.silver = 10
	assert_false(QuestManager.complete(QUEST), "not started")
	QuestManager.start(QUEST)
	assert_true(QuestManager.complete(QUEST), "what a debug console does")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_eq(QuestManager.inventory.silver, 10, "with its rewards")
	assert_false(QuestManager.complete(QUEST), "and only once")
	assert_eq(QuestManager.inventory.silver, 10)


# --- Rewards ------------------------------------------------------------------------------


func test_rewards_are_handed_out_when_the_quest_completes() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.rewards.xp = 120
	quest.rewards.silver = 30
	quest.rewards.item_ids = [&"test_brew", &"test_brew", &"test_axe"]
	quest.rewards.flags = [&"test_reward_done", &"test_reward_phase"]
	quest.on_complete_scene = &"test_trust"
	QuestManager.start(QUEST)
	watch_signals(EventBus)
	_kill(&"wolf")
	assert_signal_emitted_with_parameters(EventBus, "xp_gained", [120])
	assert_eq(QuestManager.inventory.silver, 30)
	assert_eq(QuestManager.inventory.count_of(&"test_brew"), 2, "an id named twice is two of the item")
	assert_eq(QuestManager.inventory.count_of(&"test_axe"), 1)
	assert_true(GameState.has_flag(&"test_reward_done"), "reward flags are in GameState")
	assert_true(GameState.has_flag(&"test_reward_phase"))
	assert_signal_emit_count(EventBus, "flag_set", 2, "and flag_set fires for each")
	assert_signal_emitted_with_parameters(EventBus, "quest_completed", [QUEST])
	assert_signal_emitted_with_parameters(EventBus, "scene_requested", [&"test_trust"])


func test_a_quest_without_rewards_completes_quietly() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.rewards = null
	QuestManager.start(QUEST)
	watch_signals(EventBus)
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_signal_not_emitted(EventBus, "xp_gained")
	assert_signal_not_emitted(EventBus, "scene_requested")
	assert_signal_not_emitted(EventBus, "flag_set")


# --- Prerequisites ------------------------------------------------------------------------


func test_prerequisite_flags_gate_a_quest() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.giver_npc = NPC
	quest.prerequisite_flags = [&"test_first_done", &"test_met"]
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.NOT_AVAILABLE)
	GameState.set_flag(&"test_first_done")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.NOT_AVAILABLE, "one flag of two is not enough")
	assert_eq(QuestManager.available_for_npc(NPC).size(), 0, "the giver does not offer it")
	assert_false(QuestManager.start(QUEST), "and it cannot be started")
	GameState.set_flag(&"test_met")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	assert_eq(QuestManager.available_for_npc(NPC).size(), 1)
	assert_true(QuestManager.start(QUEST))


func test_prerequisite_quests_gate_a_quest() -> void:
	_add_quest([_objective(KILL)])
	var next := _add_quest([_objective(KILL)], &"", &"next")
	next.prerequisite_quests = [QUEST]
	assert_eq(QuestManager.state_of(&"next"), QuestManager.State.NOT_AVAILABLE)
	QuestManager.start(QUEST)
	assert_eq(QuestManager.state_of(&"next"), QuestManager.State.NOT_AVAILABLE, "started is not completed")
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(&"next"), QuestManager.State.AVAILABLE)


func test_the_phase_gates_a_quest() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.phase = 2
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.NOT_AVAILABLE, "a phase 2 quest in phase 1")
	GameState.phase = 2
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	GameState.phase = 3
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE, "and from then on")


func test_a_quest_nobody_knows_is_not_available() -> void:
	assert_eq(QuestManager.state_of(&"no_such_quest"), QuestManager.State.NOT_AVAILABLE)
	assert_null(QuestManager.get_quest(&"no_such_quest"))


# --- Repeatables --------------------------------------------------------------------------


func test_a_repeatable_quest_can_be_started_again_after_completion() -> void:
	var quest := _add_quest([_objective(KILL, 2)])
	quest.repeatable = true
	quest.rewards.silver = 15
	QuestManager.start(QUEST)
	_kill(&"boar")
	_kill(&"boar")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE, "back to available, not completed")
	assert_eq(QuestManager.times_completed(QUEST), 1)
	assert_eq(QuestManager.get_completed_quests().size(), 1, "and listed as done once")

	assert_true(QuestManager.start(QUEST))
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0, "the count starts over")
	_kill(&"boar")
	_kill(&"boar")
	assert_eq(QuestManager.times_completed(QUEST), 2)
	assert_eq(QuestManager.inventory.silver, 30, "paid each time")
	assert_eq(QuestManager.get_completed_quests().size(), 1)


func test_a_quest_that_is_not_repeatable_stays_completed() -> void:
	_start_quest([_objective(KILL)])
	_kill(&"boar")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.COMPLETED)
	assert_false(QuestManager.start(QUEST))
	assert_eq(QuestManager.times_completed(QUEST), 1)


func test_a_completed_repeatable_counts_as_a_prerequisite() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.repeatable = true
	var next := _add_quest([_objective(KILL)], &"", &"next")
	next.prerequisite_quests = [QUEST]
	QuestManager.start(QUEST)
	_kill(&"boar")
	assert_eq(QuestManager.state_of(&"next"), QuestManager.State.AVAILABLE, "done once is done")


# --- What an NPC offers and takes ---------------------------------------------------------


func test_available_for_npc_lists_what_the_npc_gives_and_can_be_started() -> void:
	var offered := _add_quest([_objective(KILL)])
	offered.giver_npc = NPC
	var gated := _add_quest([_objective(KILL)], &"", &"gated")
	gated.giver_npc = NPC
	gated.prerequisite_flags = [&"test_later"]
	var elsewhere := _add_quest([_objective(KILL)], &"", &"elsewhere")
	elsewhere.giver_npc = OTHER_NPC
	_add_quest([_objective(KILL)], &"", &"own_question")

	var quests := QuestManager.available_for_npc(NPC)
	assert_eq(quests.size(), 1)
	assert_eq(quests[0], offered)
	assert_eq(QuestManager.available_for_npc(&"").size(), 0, "a quest nobody gives is offered by nobody")
	QuestManager.start(QUEST)
	assert_eq(QuestManager.available_for_npc(NPC).size(), 0, "a quest under way is not offered again")


func test_turn_ins_for_npc_lists_what_try_turn_in_would_act_on() -> void:
	_start_quest([_objective(KILL)], NPC)
	var bring := _add_quest([_deliver_objective(ITEM, 2, NPC)], OTHER_NPC, &"bring")
	QuestManager.start(&"bring")
	assert_eq(QuestManager.turn_ins_for_npc(NPC).size(), 0, "nothing finished, nothing to hand over")
	_kill(&"wolf")
	var turn_ins := QuestManager.turn_ins_for_npc(NPC)
	assert_eq(turn_ins.size(), 1)
	assert_eq(turn_ins[0].id, QUEST, "the finished quest")
	assert_eq(QuestManager.turn_ins_for_npc(OTHER_NPC).size(), 0)
	QuestManager.inventory.add(ITEM, 2)
	assert_eq(QuestManager.turn_ins_for_npc(NPC).size(), 2, "and the delivery the player can now make")
	assert_true(QuestManager.turn_ins_for_npc(NPC).has(bring))


# --- Quests that start by themselves ------------------------------------------------------


func test_an_auto_quest_starts_at_its_marker() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.auto_start_marker = MARKER
	watch_signals(EventBus)
	EventBus.marker_reached.emit(&"some_other_marker")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	EventBus.marker_reached.emit(MARKER)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)
	assert_signal_emitted_with_parameters(EventBus, "quest_started", [QUEST])
	EventBus.marker_reached.emit(MARKER)
	assert_signal_emit_count(EventBus, "quest_started", 1, "walking in again starts nothing twice")


func test_an_auto_quest_starts_on_entering_its_zone() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.auto_start_marker = ZONE
	EventBus.zone_entered.emit(OTHER_ZONE)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	EventBus.zone_entered.emit(ZONE)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)


func test_a_quest_with_a_giver_does_not_start_by_itself() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.giver_npc = NPC
	quest.auto_start_marker = MARKER
	EventBus.marker_reached.emit(MARKER)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE, "it waits to be accepted from its giver")
	assert_eq(QuestManager.available_for_npc(NPC).size(), 1)
	assert_eq(quest.get_problems().size(), 1, "and a marker on such a quest is reported when the quest is loaded")


func test_an_auto_quest_waits_for_its_prerequisites() -> void:
	var quest := _add_quest([_objective(KILL)])
	quest.auto_start_marker = ZONE
	quest.prerequisite_flags = [&"test_first_done"]
	EventBus.zone_entered.emit(ZONE)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.NOT_AVAILABLE, "in the zone too early")
	GameState.set_flag(&"test_first_done")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE, "the player has left: nothing starts")
	EventBus.zone_entered.emit(ZONE)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)


func test_an_auto_quest_starts_when_its_last_flag_comes_while_the_player_is_in_its_zone() -> void:
	# Q12's shape: both flags, and the player in Tjärnäs.
	var quest := _add_quest([_objective(KILL)])
	quest.auto_start_marker = ZONE
	quest.prerequisite_flags = [&"test_coat", &"test_lantern"]
	GameState.current_zone = ZONE
	GameState.set_flag(&"test_coat")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.NOT_AVAILABLE)
	GameState.set_flag(&"test_lantern")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE, "no need to leave the village and come back")


func test_an_auto_quest_starts_when_the_quest_it_waits_for_completes_in_its_zone() -> void:
	var first := _add_quest([_objective(KILL)])
	first.rewards.flags = [&"test_bells_done"]
	var next := _add_quest([_objective(KILL, 5)], &"", &"next")
	next.auto_start_marker = ZONE
	next.prerequisite_quests = [QUEST]
	next.prerequisite_flags = [&"test_bells_done"]
	GameState.current_zone = ZONE
	QuestManager.start(QUEST)
	var order: Array[String] = []
	var on_completed := func(id: StringName) -> void: order.append("completed %s" % id)
	var on_started := func(id: StringName) -> void: order.append("started %s" % id)
	EventBus.quest_completed.connect(on_completed)
	EventBus.quest_started.connect(on_started)
	_kill(&"wolf")
	EventBus.quest_completed.disconnect(on_completed)
	EventBus.quest_started.disconnect(on_started)
	assert_eq(QuestManager.state_of(&"next"), QuestManager.State.ACTIVE)
	assert_eq(", ".join(order), "completed hunt, started next", "the completion is announced before the next start")
	assert_eq(QuestManager.get_objective_count(&"next", 0), 0, "and the kill that ended the first quest is not counted for the next")


func test_a_repeatable_auto_quest_does_not_start_itself_over_in_its_own_zone() -> void:
	# It holds what it asks for, so it completes the moment it starts. Starting it again
	# from its own completion would never end.
	var collect := _objective(COLLECT, 1)
	collect.item_id = ITEM
	var quest := _add_quest([collect])
	quest.repeatable = true
	quest.auto_start_marker = ZONE
	QuestManager.inventory.add(ITEM, 1)
	GameState.current_zone = ZONE
	EventBus.zone_entered.emit(ZONE)
	assert_eq(QuestManager.times_completed(QUEST), 1, "once per visit")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	EventBus.zone_entered.emit(ZONE)
	assert_eq(QuestManager.times_completed(QUEST), 2)


func test_the_marker_that_starts_a_quest_does_not_count_for_it() -> void:
	var objective := _objective(REACH, 1)
	objective.marker_id = MARKER
	var quest := _add_quest([objective], NPC)
	quest.auto_start_marker = MARKER
	EventBus.marker_reached.emit(MARKER)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE, "started by the marker")
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 0, "which it has yet to reach as an objective")
	EventBus.marker_reached.emit(MARKER)
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN)


# --- Announcements and the calls ----------------------------------------------------------


func test_a_start_is_announced() -> void:
	_add_quest([_objective(KILL)])
	watch_signals(EventBus)
	assert_true(QuestManager.start(QUEST))
	assert_signal_emitted_with_parameters(EventBus, "quest_started", [QUEST])
	assert_signal_emitted_with_parameters(EventBus, "quest_updated", [QUEST])
	assert_false(QuestManager.start(QUEST), "a quest under way does not start again")
	assert_signal_emit_count(EventBus, "quest_started", 1)


func test_progress_is_announced_with_index_count_and_target() -> void:
	_start_quest([_objective(KILL, 9), _objective(KILL, 8)])
	watch_signals(EventBus)
	_kill(&"wolf")
	assert_signal_emit_count(EventBus, "quest_objective_progress", 2, "one for each objective that moved")
	assert_signal_emitted_with_parameters(EventBus, "quest_objective_progress", [QUEST, 0, 1, 9], 0)
	assert_signal_emitted_with_parameters(EventBus, "quest_objective_progress", [QUEST, 1, 1, 8], 1)
	assert_signal_emit_count(EventBus, "quest_updated", 1, "and one update for the quest")


func test_an_event_that_counts_for_nothing_announces_nothing() -> void:
	var objective := _objective(KILL, 3)
	objective.enemy_animal = WOLF
	_start_quest([objective])
	watch_signals(EventBus)
	_kill(&"boar", BOAR)
	QuestManager.inventory.add(ITEM, 1)
	assert_signal_not_emitted(EventBus, "quest_objective_progress")
	assert_signal_not_emitted(EventBus, "quest_updated")


func test_progress_adds_to_an_objective_that_is_counting() -> void:
	var collect := _objective(COLLECT, 3)
	collect.item_id = ITEM
	var hidden := _objective(KILL, 3)
	hidden.hidden_until_previous = true
	_start_quest([_objective(KILL, 3), collect, hidden], NPC)
	QuestManager.progress(QUEST, 0, 2)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 2)
	QuestManager.progress(QUEST, 1, 2)
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 0, "COLLECT follows the inventory and nothing else")
	QuestManager.progress(QUEST, 2, 1)
	assert_eq(QuestManager.get_objective_count(QUEST, 2), 0, "a hidden objective counts nothing")
	QuestManager.progress(QUEST, 0, 5)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 3, "never past the target")
	QuestManager.progress(&"test_a", 0, 1)
	assert_eq(QuestManager.get_objective_count(&"test_a", 0), 0, "a quest that is not under way counts nothing")


func test_reset_forgets_all_progress_and_keeps_the_quests() -> void:
	_start_quest([_objective(KILL, 2)])
	var done := _add_quest([_objective(KILL)], &"", &"done")
	QuestManager.start(&"done")
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(&"done"), QuestManager.State.COMPLETED)
	watch_signals(EventBus)
	QuestManager.reset()
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE)
	assert_eq(QuestManager.state_of(&"done"), QuestManager.State.AVAILABLE)
	assert_eq(QuestManager.times_completed(&"done"), 0)
	assert_eq(done, QuestManager.get_quest(&"done"), "the quests themselves stay")
	assert_signal_emit_count(EventBus, "quest_updated", 2, "one for each quest that had progress")


# --- Saving -------------------------------------------------------------------------------


func test_progress_survives_a_round_trip_through_json() -> void:
	var collect := _objective(COLLECT, 2)
	collect.item_id = ITEM
	collect.on_complete_scene = &"test_voices"
	var deliver := _deliver_objective(ITEM, 2, NPC)
	deliver.hidden_until_previous = true
	_start_quest([_objective(KILL, 5), collect, deliver, _objective(KILL, 3)], NPC)
	var hunt := _add_quest([_objective(KILL, 2)], &"", &"repeat")
	hunt.repeatable = true
	_add_quest([_objective(KILL)], &"", &"done")
	for id: StringName in [&"repeat", &"done"]:
		QuestManager.start(id)
	QuestManager.inventory.add(ITEM, 2)
	_kill(&"wolf")
	_kill(&"wolf")
	QuestManager.start(&"repeat")
	_kill(&"wolf")
	QuestManager.try_turn_in(QUEST, NPC)
	assert_eq(QuestManager.inventory.count_of(ITEM), 0, "delivered: the collecting is on the books, not in the bag")

	var saved: Variant = JSON.parse_string(JSON.stringify(QuestManager.to_dict()))
	assert_typeof(saved, TYPE_DICTIONARY)
	QuestManager.reset()
	watch_signals(EventBus)
	QuestManager.from_dict(saved)

	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 3)
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 2, "the delivered collecting is still done")
	assert_true(QuestManager.is_objective_finished(QUEST, 2))
	assert_eq(QuestManager.get_objective_count(QUEST, 3), 3)
	assert_eq(QuestManager.state_of(&"repeat"), QuestManager.State.ACTIVE, "the repeatable is in its second run")
	assert_eq(QuestManager.get_objective_count(&"repeat", 0), 1)
	assert_eq(QuestManager.times_completed(&"repeat"), 1)
	assert_eq(QuestManager.state_of(&"done"), QuestManager.State.COMPLETED)
	assert_eq(QuestManager.get_active_quests()[0].id, QUEST, "in the order they were started")
	assert_signal_not_emitted(EventBus, "scene_requested", "an objective scene that has played does not play again")
	assert_signal_not_emitted(EventBus, "quest_objective_progress", "nothing moved by loading")
	assert_signal_not_emitted(EventBus, "quest_completed")
	assert_signal_not_emitted(EventBus, "xp_gained")

	_kill(&"wolf")
	_kill(&"wolf")
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.READY_TO_TURN_IN, "and it plays on from there")


func test_an_objective_that_was_saved_finished_does_not_set_off_its_scene_again() -> void:
	var boars := _objective(KILL, 2)
	boars.on_complete_scene = &"test_voices"
	_add_quest([boars, _objective(KILL, 9)])
	watch_signals(EventBus)
	QuestManager.from_dict({"active": [{"id": "hunt", "counts": [2, 1]}]})
	assert_true(QuestManager.is_objective_finished(QUEST, 0))
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 1)
	assert_signal_not_emitted(EventBus, "scene_requested", "even when the save does not say that it played")
	assert_signal_emitted_with_parameters(EventBus, "quest_updated", [QUEST])


func test_from_dict_takes_missing_and_malformed_data_as_not_started() -> void:
	_start_quest([_objective(KILL, 5), _objective(KILL, 5)])
	_kill(&"wolf")
	QuestManager.from_dict({})
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.AVAILABLE, "an empty save is a new game")
	QuestManager.from_dict({
		"active": [
			{"id": "hunt", "counts": [4.0]},
			{"id": "a_quest_that_was_cut", "counts": [1.0]},
			"not an entry",
			{"counts": [1.0]},
		],
		"completed": "not a list",
	})
	assert_eq(QuestManager.state_of(QUEST), QuestManager.State.ACTIVE)
	assert_eq(QuestManager.get_objective_count(QUEST, 0), 4, "what is there is read")
	assert_eq(QuestManager.get_objective_count(QUEST, 1), 0, "what is missing starts at nothing")
	assert_eq(QuestManager.get_active_quests().size(), 1, "and what makes no sense is left out")


# --- Helpers ------------------------------------------------------------------------------


## A new game that knows only the quests on disk. The other test scripts share the autoloads.
func _fresh_game() -> void:
	GameState.flags.clear()
	GameState.phase = 1
	GameState.current_zone = &""
	QuestManager.inventory = QuestInventory.new()
	QuestManager.load_quests()


func _objective(type: ObjectiveData.Type, target: int = 1) -> ObjectiveData:
	var objective := ObjectiveData.new()
	objective.type = type
	objective.target_count = target
	return objective


func _deliver_objective(item_id: StringName, count: int, npc_id: StringName) -> ObjectiveData:
	var objective := _objective(DELIVER, count)
	objective.item_id = item_id
	objective.npc_id = npc_id
	return objective


## Registers a quest with [param objectives]. It has no giver and no prerequisites.
func _add_quest(objectives: Array[ObjectiveData], turn_in_npc: StringName = &"", id: StringName = QUEST) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.display_name = String(id)
	quest.objectives = objectives
	quest.turn_in_npc = turn_in_npc
	assert_true(QuestManager.register(quest), "the quest %s is sound" % id)
	return quest


## Registers the quest and starts it.
func _start_quest(objectives: Array[ObjectiveData], turn_in_npc: StringName = &"") -> QuestData:
	var quest := _add_quest(objectives, turn_in_npc)
	assert_true(QuestManager.start(quest.id), "the quest starts")
	return quest


## An enemy dies, as J07's Enemy will announce it: a body in the scene, with its data.
func _kill(enemy_id: StringName, animal: int = WOLF, category: int = NEUTRAL, zone_id: StringName = &"") -> void:
	var enemy := FakeEnemy.new()
	enemy.data.id = enemy_id
	enemy.data.animal = animal
	enemy.data.category = category
	enemy.zone_id = zone_id
	_announce_death_of(enemy)


## Puts [param enemy] into the scene, announces its death on the bus and frees it.
func _announce_death_of(enemy: Node3D) -> void:
	add_child(enemy)
	EventBus.enemy_died.emit(enemy)
	enemy.free()


## The script of the global class [param global_name], or null when the project has none.
func _script_of_class(global_name: String) -> GDScript:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == global_name:
			return load(entry["path"]) as GDScript
	return null


## Asserts that the enum among [param constants] that has the key [param telltale] carries
## the keys and values of [param filter_enum], which has ANY on top of them.
func _assert_enum_matches(filter_enum: Dictionary, constants: Dictionary, telltale: String) -> void:
	for constant: Variant in constants.values():
		if not (constant is Dictionary and (constant as Dictionary).has(telltale)):
			continue
		var theirs: Dictionary = constant
		assert_eq(theirs.size(), filter_enum.size() - 1, "the same members, but for ANY")
		for key: String in theirs:
			assert_eq(filter_enum.get(key), theirs[key], "%s in ObjectiveData has the value EnemyData gives it; change the two enums together" % key)
		return
	fail_test("EnemyData has no enum with %s: the kill filters compare against nothing" % telltale)


## Stands in for J07's Enemy: the body enemy_died carries, with what quests read of it.
class FakeEnemy:
	extends Node3D

	var data: FakeEnemyData = FakeEnemyData.new()
	var zone_id: StringName = &""


## Stands in for J07's EnemyData.
class FakeEnemyData:
	extends Resource

	var id: StringName = &""
	var animal: int = 0
	var category: int = 0


## Stands in for a cairn that knows its zone.
class FakeCairn:
	extends Node3D

	var zone_id: StringName = &""
