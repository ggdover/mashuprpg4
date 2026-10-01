# J10: Character progression and character sheet

**Milestone:** M3 · **Depends on:** J03, J04, J06 · **Unblocks:** J18, J19
**Reads first:** `design/gdd.md` §Progression, §Weapons and skills (unlock levels)

## Goal

XP, levels 1 to 20, stat growth, stat points, weapon skill unlocks driven by level, and a character sheet screen.

## Deliverables

- `game/player/progression.gd` (`class_name Progression`, Node on the player)
- `game/ui/character/character_sheet.tscn`
- `game/data/progression/level_curve.tres` (or constants in `Progression`)
- `game/test/test_progression.tscn`
- GUT tests in `game/test/unit/test_progression.gd`

## Spec

**XP.** Listens to `EventBus.xp_gained(amount)`. `xp_to_next(level) = round(100 * level ^ 1.5)`. Level cap 20 for act 1. On level up: base `max_health` +10, `max_stamina` +5, `max_mana` +5, one stat point, emit `leveled_up(level)`. Health refills on level up.

**Stat points.** `allocate(stat)` with four choices: health (+15 max_health), damage (+3% physical_bonus), armor (+5 armor), speed (+2% move_speed). Stored as counts per stat and applied to the StatBlock under source `&"points"`. A `respec()` function exists for debugging and vendors later.

**Skill unlocks.** `Player.level` becomes a property backed by `Progression.level`. J04's executor already gates on it, so nothing else changes.

**Character sheet.** Toggled by `character`. Shows level, xp bar with numbers, unspent points, the four allocation buttons, and every stat from the StatBlock as final computed values with the breakdown on hover (base, gear, points, status). Shows the equipped weapon and which of its skills are unlocked. Palette UI signals through `Palette.role`.

**Test scene.** A key grants 50 xp, a key grants a level, dummies from J03 give xp on death through the J07 signal if merged.

**Tests.** Curve values at levels 1, 5, 20; no xp gain past the cap; allocation applies and respec removes; level-up refills health.

## Acceptance criteria

- [ ] Killing enemies raises xp and levels; the sheet updates live
- [ ] Points allocate and change the computed stats shown on the sheet and in play
- [ ] Sword Whirl unlocks exactly at level 4 and Parry at 8, with no other change
- [ ] GUT tests pass, editor loads clean

## Out of scope

HUD xp bar (J18). Saving (J19), but keep `Progression.to_dict()` and `from_dict()` working.

## Deviations

(none yet)
