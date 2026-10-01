# J17: Act 1 quest content and scripted scenes

**Milestone:** M5 · **Depends on:** J05, J09, J11, J13, J14, J15, J16 · **Unblocks:** J22
**Reads first:** `design/quests_act1.md` (every row is a deliverable), `design/world_act1.md` (tone for every line of text), `design/gdd.md` §World; J13 and J14 marker names; J15 and J16 job files

## Goal

Author all thirteen main quests, three repeatables, the five scripted scenes and the real dialogue, and wire every trigger, so act 1 can be played from the first fox to the troll's cave.

## Deliverables

- `game/data/quests/act1/q01.tres` to `q13.tres`, `r1.tres` to `r3.tres`
- `game/scenes/scene_runner.gd` (`SceneRunner` autoload) and `game/data/scenes/*.tres` (`ScriptedScene` resources)
- `game/scenes/spirit_light.tscn`: an emissive wisp-coloured box used as the vittror's presence
- Real dialogue tiers in every `NpcData`
- `game/ui/menus/end_of_act.tscn`: a simple "End of act 1" screen
- `plan/walkthrough_act1.md`: the step-by-step playthrough checklist J22 uses

## Spec

**Quest wiring.** Follow the table in `quests_act1.md` exactly for objectives, zones, turn-ins, rewards and flags. Notes per quest:

- Q01 activates the `Q01_Henhouse` spawner on start. Turn-in with the fisherman.
- Q02 uses COLLECT on goldieflowers from the Fairmeadow pickups. Its completion sets `q02_done` and `SceneRunner` plays `first_fog_village` the next time the player enters Tjärnäs (a REACH-style listener inside the scene runner, not a quest).
- Q03 counts 12 possessed ravens in `hunting_woods` then BOSS `great_raven`; the boss marker spawns the boss when the quest is active.
- Q04 has three objectives in order: KILL 8 boars (any category) in `hunting_woods`; REACH `Q04_FogTrigger` whose `on_complete_flag` is `FOG_1` (the scene runner listens for it: `WorldState.request_fog(&"FOG_1")`, sets `fog_scene_active`, spawns the wolf pack and the Alpha Wolf at `Q04_WolfSpawn`); BOSS `alpha_wolf` with `on_complete_scene` `vittror_1`. Turn-in with the storehouse keeper, who accepts the meat. Completion sets `phase_2` and `GameState.phase = 2`; fog ends when the player enters Tjärnäs.
- Q05: the rune interactables become usable only when their `RuneGroup_n` spawner reports all dead; each gives one rune rubbing (COLLECT 4). DELIVER to the old lady.
- Q06: REACH `Cairn_Crossroads` sets `FOG_2`; then KILL 15 possessed wolves in `crossroads` from the `Q06_Wolves` waves; `on_complete_scene` `vittror_2`, rewards flag `has_bell`.
- Q07: LIGHT_CAIRNS 6 in `crossroads`. Cairns need 1 tallow each; boars drop tallow at 40% while Q07 is active (add a quest-conditional entry to the boar loot table). Sets `cairns_lit`.
- Q08: REACH `norrby`, BOSS `the_old_one` (spawned at its marker when the quest is active), COLLECT 1 unmelting shard (a guaranteed quest drop from the boss while the quest is active), DELIVER to the old lady.
- Q09: REACH `wolf_den`, BOSS `pack_mother`, then REACH `frost_line` (leaving the den) with `on_complete_flag` `FOG_3` and `on_complete_scene` `vittror_3`. Sets `phase_3` and phase 3.
- Q10: KILL 6 wolves with `enemy_category` NEUTRAL and 2 bears NEUTRAL, COLLECT 6 wolf pelts and 2 bear hides (neutral drops only; possessed drop ruined hides), DELIVER to the tanner. Reward item: winter coat.
- Q11: REACH `flooded_cave`, BOSS `the_sleeper`, COLLECT the lantern from `Pickup_Lantern` (placed by the quest), DELIVER to the old lady. Reward flag `has_lantern`.
- Q12: KILL 20 possessed ravens in `berget_approach`. Requires `coat_done` and `lantern_done`.
- Q13: on start, `farewell` plays in Tjärnäs. REACH `Q13_DawnTrigger` forces DAY through `WorldState.end_fog()` and spawns the troll at `Boss_Troll`. BOSS `the_troll` sets `act1_troll_dead`, which enables the cave exit. Entering the cave exit sets `act1_complete` and shows the end screen.
- Repeatables R1 to R3 as in the table, offered by the storehouse keeper, tanner and fisherman.

**AUTO quests.** Quests with no giver start from `auto_start_marker`: Q03 when entering `hunting_woods` after `q01_done`; Q06 when entering `crossroads` in phase 2; Q07 after `vittror_2`; Q09 when entering `frost_line`; Q12 when both `coat_done` and `lantern_done` are set and the player is in Tjärnäs; Q13 after `q12_done` when talking to the old lady (she is the giver). The journal shows them as questions.

**Scripted scenes.** `ScriptedScene` resource: `id`, `steps: Array` of `{type: TEXT | WAIT | SPAWN_LIGHTS | BELLS | END_FOG | SET_FLAG, text, seconds, marker, flag}`. `SceneRunner` plays steps in order: TEXT shows a subtitle at the bottom (speaker "?" for the vittror in scene 1, "the vittror" after), SPAWN_LIGHTS places spirit lights around the named marker, BELLS shows "bells, somewhere in the fog" and a small screen pulse, WAIT delays, END_FOG calls `WorldState.end_fog()`. During a scene enemies are frozen (a `SceneRunner.scene_active` flag the AI checks) and the player can still move. Write the five scenes:

- `first_fog_village`: the horn, three villagers walk to their doors (move NPC boxes to markers), a line from the fisherman, fog for 20 s, then day.
- `vittror_1`: bells, lights appear at `Scene_Vittror1`, six to eight short lines. They beg. They say their home is threatened and they stay because of it. They don't explain the possessed.
- `vittror_2`: fewer lines. Trust. The bell is given.
- `vittror_3`: the cold followed them. It takes what dies in it. Their road runs under Berget. Something sits in the cave.
- `farewell`: night preset (reuse fog environment with the light at 0.1), the old lady at the last fence, five lines, the lantern already given, the headman's house dark. Ends with the player walking out of the village.

**Dialogue.** Replace every placeholder tier with real lines in the tone of `world_act1.md`: short, plain, no speeches. The village treats fog like weather. The headman's tiers dismiss the old lady more sharply each phase. The old lady's tiers track the reveals and end with the farewell.

**Walkthrough.** Write `plan/walkthrough_act1.md`: every quest, where to go, what to kill, what should happen, expected flags after each step. J22 follows it.

## Acceptance criteria

- [ ] Act 1 can be played from a fresh start to the end screen following the walkthrough, with no debug commands
- [ ] Fog starts and ends exactly when the table says; random fog never interrupts a scripted scene
- [ ] Phase changes shift the possessed spawn share and the fog chance
- [ ] The bell, the coat and the lantern each change the game as the gdd describes
- [ ] The troll fight is winnable using sunlight and not otherwise practical
- [ ] Every NPC has real lines for every tier, and the journal reads as questions for AUTO quests
- [ ] Editor loads clean

## Out of scope

Balance passes (J22), save compatibility (J19 handles the flags generically).

## Deviations

(none yet)
