# J21: Test suite

**Milestone:** M6 · **Depends on:** J03, J06, J15 (and whatever else is merged) · **Unblocks:** J22
**Reads first:** `plan/README.md` §Definition of done; every job's GUT test list

## Goal

Consolidate the unit tests written by earlier jobs, fill the gaps, add a headless runner, and make "tests green" a one-command check.

## Deliverables

- `tools/test.cmd`: runs GUT headless with `"C:\Users\filip\Godot_v4.7.2-stable_win64.exe" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` and returns the exit code
- `game/test/unit/` organised by area: `combat/`, `items/`, `quests/`, `progression/`, `world/`, `save/`
- New tests covering: item generation never produces a stat below zero or above the tier max; loot tables with `drop_chance` 0 drop nothing; the spawner population math for all three phases and both states; `WorldState.on_zone_entered` never triggers fog in villages; quest objective filters across every type; save round-trip of a full act 1 state (use fixture data)
- A smoke test scene runner: `game/test/smoke_zones.gd` that loads every `ZoneData` scene headless and asserts no script errors
- `game/README.md` §Testing updated

## Acceptance criteria

- [ ] `tools/test.cmd` runs all tests in under two minutes and exits non-zero on failure
- [ ] Every earlier job's tests are present and passing
- [ ] The smoke test loads all ten zones without errors
- [ ] Editor loads clean

## Out of scope

Play testing (J22), performance benchmarks.

## Deviations

(none yet)
