# J19: Save and load

**Milestone:** M5 · **Depends on:** J06, J10, J12, J15 · **Unblocks:** J22
**Reads first:** `plan/README.md` §Decisions (JSON in `user://saves/`); J06, J10, J12, J15 job files for the `to_dict` / `from_dict` hooks they expose

## Goal

Save the whole game state to a JSON file and restore it, from the pause menu and automatically at zone transitions and quest completions, with a Continue button on the main menu.

## Deliverables

- `game/core/save_system.gd` completed (`SaveSystem` autoload)
- `game/core/save_data.gd` (`class_name SaveData`): the schema in one place with a `version` field
- Continue enabled in the main menu (J18) and Save / Load in the pause menu
- `game/test/unit/test_save.gd`

## Spec

**Schema (version 1).** `player`: position, zone id, health, stamina, mana. `progression`: level, xp, allocated points. `inventory`: items as `ItemInstance.to_dict()`, silver, quest items. `equipment`: slot to item dict. `game_state`: phase, flags, zone_state. `quests`: state per quest id and objective progress. `world`: state (always saved as DAY; fog doesn't persist), `fog_scene_active` false. `settings` are not here; they live in `user://settings.cfg`.

**Writing.** `SaveSystem.save(slot := "auto")` collects dicts from `Player`, `Progression`, `Inventory`, `Equipment`, `GameState`, `QuestManager`, writes `user://saves/<slot>.json` with `JSON.stringify(data, "\t")`, and keeps one backup `<slot>.bak`. Autosave on `zone_entered` and `quest_completed`, throttled to once per 5 s. Manual save from the pause menu into slot "manual".

**Reading.** `load(slot)`: read, validate `version`, migrate if needed (a `migrations` dictionary keyed by version, empty for now), then: set `GameState` first, restore progression, inventory, equipment (equip through `Equipment.equip` so stats apply), quests, then `ZoneManager.change_zone(zone, entry)` and place the player at the saved position. Return false and show a toast on any failure without leaving a half-loaded state.

**Continue.** Enabled when `user://saves/auto.json` or `manual.json` exists; loads the newest.

**Tests.** Round-trip: build a state, save to a temp path, load into fresh objects, compare dicts. Corrupt file returns false. Missing keys fall back to defaults.

## Acceptance criteria

- [ ] Save, quit to menu, Continue restores zone, position, items, equipment, level, quest progress and flags
- [ ] Autosave happens on zone change and quest completion, no more than once per 5 s
- [ ] A corrupt save shows a toast and the game stays in the menu
- [ ] GUT tests pass, editor loads clean

## Out of scope

Cloud saves, multiple manual slots, save thumbnails.

## Deviations

(none yet)
