# J22: Playtest build, debug tools and act 1 walkthrough

**Milestone:** M6 · **Depends on:** every other job · **Unblocks:** nothing, this closes the graybox milestone
**Reads first:** `plan/walkthrough_act1.md` (from J17), `plan/README.md` §Definition of done, `design/gdd.md`

## Goal

A debug console for fast testing, a Windows export, a full playthrough of act 1 against the walkthrough with findings written down, and a first balance pass on the numbers that were obviously wrong.

## Deliverables

- `game/ui/debug/debug_console.tscn` on `debug_console` (F1): commands `zone <id> [entry]`, `fog`, `day`, `phase <n>`, `flag <name>`, `give <item_id> [level] [rarity]`, `silver <n>`, `level <n>`, `spawn <enemy_id> [count]`, `boss <id>`, `quest start|complete <id>`, `god`, `killall`, `noclip`, `timescale <f>`, `help`. Disabled in release exports via a feature tag
- A performance overlay toggle: fps, frame time, draw calls, enemy count
- Export preset for Windows Desktop in `game/export_presets.cfg`, output to `game/export/` (gitignored), plus `tools/export.cmd`
- `plan/playtest_1.md`: findings from a full playthrough, grouped as blockers, bugs, balance, feel, with the quest they occurred in
- Balance changes applied to data files with a note in the job's Deviations
- `plan/README.md` updated with a "Graybox milestone complete" line and the date

## Spec

**Console.** A `LineEdit` with history and autocompletion of command names. Commands call the same public APIs the game uses (`ZoneManager.change_zone`, `WorldState.request_fog`, `QuestManager.start`, `ItemGenerator.generate`, spawners' `spawn_one`). `god` sets `Health.invulnerable`. `noclip` disables the player's collision mask.

**Playthrough.** Play from New game to the end screen following the walkthrough, without the console except to note where a console command was needed to continue (that's a blocker). Time each phase. Record deaths per boss.

**Balance pass.** Target: a player who does every main quest and a few repeatables reaches level 14 to 16 at the troll and needs two or three attempts. Adjust enemy health and damage, xp values, and the troll's petrify window in data only.

## Acceptance criteria

- [ ] Every console command works and the console is absent from the exported build
- [ ] The exported build runs on this machine from `game/export/` and completes the walkthrough
- [ ] `plan/playtest_1.md` exists with at least the timing table and any blockers fixed or listed
- [ ] `tools/test.cmd` is green after the balance changes
- [ ] Editor loads clean

## Out of scope

Anything from the "Out of scope" list in the gdd. New features found wanting during the playthrough go into a new job file, not into this one.

## Deviations

(none yet)
