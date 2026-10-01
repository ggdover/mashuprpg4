# J16: NPCs, dialogue and vendors

**Milestone:** M5 · **Depends on:** J01, J06, J15 · **Unblocks:** J17
**Reads first:** `design/world_act1.md` §Tjärnäs, §The old lady, §Ending; `design/gdd.md` §NPCs, §Loot and equipment (vendors); J15 job file

## Goal

NPCs as data with conditional dialogue, quest offers and turn-ins through the dialogue box, and two vendor screens. The lines themselves are placeholders here; J17 writes the real ones.

## Deliverables

- `game/npcs/npc_data.gd` (`class_name NpcData`), `dialogue_tier.gd` (`class_name DialogueTier`)
- `game/npcs/npc_base.tscn` and `npc.gd` (`class_name Npc`)
- `game/ui/dialogue/dialogue_box.tscn`
- `game/ui/vendor/vendor_screen.tscn`
- `game/data/npcs/*.tres` for: old_lady, storehouse_keeper, tanner, smith, fisherman, headman, norrby_headwoman, norrby_villager_1, norrby_villager_2
- `game/test/test_npcs.tscn`
- New `EventBus` signals: `dialogue_started`, `dialogue_ended` already exist; add `npc_talked(npc_id: StringName)`

## Spec

**NpcData.** `id`, `display_name`, `roles` flags TALK, QUEST, VENDOR, `tiers: Array[DialogueTier]`, `vendor_items: Array[ItemData]` with `vendor_item_levels`, `buys: bool`.

**DialogueTier.** `required_flags: Array`, `forbidden_flags: Array`, `min_phase`, `lines: Array[String]`. The NPC speaks the last tier in the array whose conditions hold, so authors order tiers from general to specific.

**Npc scene.** Graybox actor with the name label, an Area3D on layer 9 so the `Interactor` from J06 finds it with the prompt "E: Talk". On interact: freeze player input, open the dialogue box, emit `dialogue_started`. Placement: J13 left `NpcMarkers`; a `NpcPlacer` node in each village zone instances `npc_base` at each marker with the matching `NpcData`.

**Dialogue box.** Bottom of the screen: name, one line at a time, advance with `interact` or click. After the lines: if `QuestManager.turn_ins_for_npc(id)` is non-empty, show a "Deliver" step per quest that calls `try_turn_in` and shows the reward summary. Then if `available_for_npc(id)` is non-empty, offer each quest with its summary and Accept / Not now. Then if the NPC is a VENDOR, a Trade button opens the vendor screen. Closing emits `dialogue_ended` and `npc_talked` and restores input. Palette UI signals through `Palette.role`.

**Vendor screen.** Left: the NPC's stock generated from `vendor_items` at `vendor_item_levels` at COMMON or FINE rarity, restocked on each zone load, with prices `sell_value × 4`. Right: the player's inventory; selling gives `sell_value`. Quest items can't be sold. Silver shown at the top.

**Placeholder tiers.** Every NPC gets a default tier with one line naming who they are, plus one tier per phase with a line that says the phase, so J17 can see the mechanism before replacing the text. The old lady additionally gets tiers keyed on `q02_done`, `phase_2`, `phase_3`, `lantern_done`.

**Test scene.** Three NPCs (a talker, a quest giver using the J15 test chain, a vendor) around the player.

## Acceptance criteria

- [ ] Talking freezes the player, shows lines, and restores control on close
- [ ] The J15 test chain can be accepted from and turned in to an NPC through the dialogue box
- [ ] Tier selection follows flags and phase
- [ ] Buying and selling moves items and silver correctly, and quest items can't be sold
- [ ] All nine NPC data files load and the village placers put them at their markers
- [ ] Editor loads clean

## Out of scope

Real dialogue text and the vittror scenes (J17). Voice, portraits.

## Deviations

(none yet)
