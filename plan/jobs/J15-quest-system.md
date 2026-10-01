# J15: Quest system and journal

**Milestone:** M5 · **Depends on:** J01 · **Unblocks:** J16, J17, J18, J19
**Reads first:** `design/quests_act1.md` (all of it, the data model must express every row); `design/gdd.md` §Quests

## Goal

Quests as data with objective types that cover every act 1 quest, a manager that tracks progress from EventBus signals, prerequisites and flags, rewards, repeatables, scripted-scene hooks, and a journal screen. J17 only authors data on top of this.

## Deliverables

- `game/quests/quest_data.gd` (`class_name QuestData`), `objective_data.gd` (`class_name ObjectiveData`)
- `game/quests/quest_manager.gd` (`QuestManager` autoload)
- `game/quests/quest_trigger.tscn` and `quest_trigger.gd`: an Area3D that emits `marker_reached(id)` for the player
- `game/ui/journal/journal.tscn`
- `game/data/quests/test_chain/*.tres`: a three-quest test chain
- `game/test/test_quests.tscn`
- GUT tests in `game/test/unit/test_quests.gd`
- New `EventBus` signals: `marker_reached(id: StringName)`, `quest_started(quest_id)`, `quest_objective_progress(quest_id, index, current, target)`, `scene_requested(scene_id: StringName)`, `xp_gained` reused for rewards

## Spec

**ObjectiveData.** `type` enum KILL, BOSS, COLLECT, REACH, DELIVER, LIGHT_CAIRNS, `description`, `target_count`, and filters: `enemy_id`, `enemy_animal`, `enemy_category`, `zone_id`, `boss_id`, `item_id`, `marker_id`, `npc_id`. `hidden_until_previous: bool` (objectives in order). `on_complete_flag: StringName` and `on_complete_scene: StringName` per objective so a mid-quest event (fog on the path home) can fire when one objective finishes.

**Counting rules.** KILL counts `enemy_died` where every set filter matches `enemy.data`. BOSS completes on `boss_defeated(boss_id)`. COLLECT tracks the inventory count of `item_id` live (progress can go down if the player drops items). REACH completes on `marker_reached(marker_id)` or on `zone_entered(zone_id)`. DELIVER completes when the player talks to `npc_id` with `target_count` of `item_id`, removing the items. LIGHT_CAIRNS counts `cairn_lit` in `zone_id`.

**QuestData.** `id`, `display_name`, `phase`, `summary`, `objectives: Array[ObjectiveData]`, `giver_npc` (empty means AUTO, the player's own question), `turn_in_npc` (empty means auto-complete when objectives finish), `prerequisite_flags`, `prerequisite_quests`, `rewards` `{xp, silver, item_ids: Array, flags: Array}`, `on_start_flags`, `on_complete_scene`, `repeatable: bool`, `auto_start_marker` (AUTO quests start when the player reaches this marker or enters this zone, if prerequisites hold).

**QuestManager.** Loads every `QuestData` under `game/data/quests/` at startup. State per quest: NOT_AVAILABLE, AVAILABLE, ACTIVE, READY_TO_TURN_IN, COMPLETED. `start(id)`, `progress(id, index, amount)`, `try_turn_in(id, npc_id) -> bool`, `complete(id)` applies rewards (xp through `xp_gained`, silver and items into the inventory, flags through `GameState.set_flag`), emits `quest_completed`, requests `on_complete_scene` through `scene_requested`, and resets repeatables to AVAILABLE. `available_for_npc(npc_id)` and `turn_ins_for_npc(npc_id)` for J16. Listens to every relevant EventBus signal once and dispatches to active quests. Auto-start logic checks `auto_start_marker` on `marker_reached` and `zone_entered`.

**Journal.** Toggled by `journal`. Two tabs: active and completed. Each active quest shows its summary and objectives with progress "3 / 8". AUTO quests are labelled as questions in the player's own words (use the `summary`). Palette UI signals.

**Test chain.** Quest A: kill 3 test dummies (KILL by `enemy_id`), auto-complete, flag `a_done`. Quest B: requires `a_done`, COLLECT 2 of a test item, DELIVER to a test NPC placeholder (a box with an npc_id that calls `try_turn_in` on interact). Quest C: repeatable, REACH a marker.

**Tests.** Filters match and don't match, COLLECT decreases on drop, prerequisites gate availability, repeatable resets, rewards apply, objective order with `hidden_until_previous`, per-objective flag fires exactly once.

## Acceptance criteria

- [ ] The test chain plays through in the test scene with the journal reflecting each step
- [ ] Every objective type listed above is exercised by the test chain or a unit test
- [ ] A quest with an empty turn-in completes the moment its last objective finishes; one with an NPC waits for the talk
- [ ] Flags set by quests are visible in `GameState` and `flag_set` fires
- [ ] GUT tests pass, editor loads clean

## Out of scope

Real quests (J17), dialogue (J16), HUD tracker (J18).

## Notes for later jobs

- J16's dialogue asks `QuestManager.available_for_npc` and `turn_ins_for_npc` to build its offer and turn-in lines.
- J17 listens to `scene_requested` in its scene runner.

## Deviations

(none yet)
