# Execution plan: act 1 graybox

The plan is split into jobs in `plan/jobs/`. Each job is self-contained: it says what to read, what it depends on, what to build, and how to know it's done. A job can be picked up in a fresh session by a person or an agent with no memory of the design conversation.

## What we're building

A playable act 1 of an action RPG in Godot 4.7, with every asset a gray box. Design lives in `design/`:

- `design/gdd.md`: mechanics, controls, combat, loot, enemies, world states, UI, placeholder policy.
- `design/world_act1.md`: story, village, vittror, zones, glossary.
- `design/quests_act1.md`: quest data, bosses, scripted scenes, flags.
- `design/palette.json`: colours. `design/palette.md` explains the roles.

## Decisions already made

| Topic | Decision | Why |
|-------|----------|-----|
| Engine | Godot 4.7.2 stable, found at `C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` | Installed. Pin to 4.7.x |
| Language | GDScript with static typing, `class_name` on every script | Fastest iteration for a solo project |
| Dimensions | 3D with a fixed-angle top-down camera | Gray boxes swap cleanly for meshes later; day and fog are lighting and environment presets; the references are 3D |
| Physics | Jolt (Godot 4.7 default) | Default |
| Data | Custom `Resource` classes saved as `.tres` under `game/data/` | Designers edit data without touching code; quests, items, enemies, skills are all data |
| Events | One `EventBus` autoload with typed signals | Decouples quests, world state and UI |
| Navigation | `NavigationRegion3D` baked per zone, `NavigationAgent3D` on enemies | Built in |
| Tests | GUT addon for logic (damage, loot, quests, inventory); manual test scenes for feel | Cheap to keep green |
| Save | JSON in `user://saves/` | Simple, inspectable |
| Placeholders | Gray boxes per `gdd.md` placeholder policy | The user wants a playable version before any art |

## Project layout

```
game/                    Godot project (project.godot lives here)
  core/                  autoloads: event_bus, game_state, world_state, palette (generated), save_system
  player/                player scene, movement, aim, camera rig
  combat/                health, hitbox, hurtbox, damage_info, status effects, projectiles
  weapons/               weapon_data + .tres per weapon type
  skills/                skill_data, skill_executor, .tres per skill
  items/                 item_data, affixes, loot tables, item_generator, inventory, equipment
  enemies/               enemy_base, ai states, enemy_data, .tres per enemy, bosses/
  world/                 zone_base, zones/<name>/, dungeons/<name>/, spawner, state_visibility, cairn, transitions
  quests/                quest_data, objectives, quest_manager, .tres per quest
  npcs/                  npc_base, dialogue, .tres per npc
  ui/                    hud/, inventory/, character/, journal/, dialogue/, vendor/, menus/, theme
  graybox/               placeholder meshes and materials kit
  test/                  test arena scenes and GUT tests
  addons/                gut
tools/                   scripts (palette export, run helpers)
design/                  design docs (read-only for jobs unless a job says otherwise)
plan/                    this plan and the job files
```

## Conventions

- Files `snake_case.gd` / `.tscn` / `.tres`. Classes `PascalCase`. Signals `past_tense_verb` (`enemy_died`). Constants `UPPER_SNAKE`.
- One scene per entity type, one script per scene. Composition over inheritance: `Health`, `Hurtbox`, `Hitbox`, `StatBlock` are child nodes or resources, not base classes.
- No magic numbers in scripts. Anything a designer might tune lives in a `.tres` or an `@export`.
- Every job adds or updates a test scene under `game/test/` that demonstrates its feature in isolation.
- Every job ends with the editor opening the project with zero errors and warnings in the output panel.
- Colours come from `game/core/palette.gd` (generated from `design/palette.json`), never typed inline.
- Commit per job on a branch named after the job (`job/J04-weapon-skill-framework`), merged to `main` when acceptance criteria pass.

## Definition of done for a job

1. All acceptance criteria in the job file are checked.
2. The job's test scene runs and demonstrates the feature.
3. GUT tests pass, if the job adds logic tests.
4. Editor output shows no errors or warnings on project load.
5. Any design change discovered while building is written back to `design/` and noted at the bottom of the job file under "Deviations".

## How to work a job

1. Read `plan/README.md`, the job file, and the design docs it names under "Reads first".
2. Check that the jobs listed under "Depends on" are merged.
3. Build to the spec. When the spec is silent, choose the simplest thing that satisfies the acceptance criteria and write the choice into the job file's Deviations.
4. Run the test scene, run GUT, open the editor clean.
5. Commit and merge.

## Milestones and job index

| Milestone | Playable checkpoint | Jobs |
|-----------|---------------------|------|
| M1 Moving box | Walk and aim a box in an arena | J01, J02 |
| M2 Fighting box | Fight enemies with all six weapons | J03, J04, J05, J07, J08, J20 |
| M3 Loot and levels | Pick up, equip, level up, HUD | J06, J10, J18 |
| M4 The forest | Zones, day and fog, dungeons, bosses | J11, J12, J13, J14, J09 |
| M5 Act 1 playable | Quests, NPCs, scripted scenes, saves | J15, J16, J17, J19 |
| M6 Ship the graybox | Tests, debug tools, full walkthrough | J21, J22 |

| Job | Title | Depends on | Unblocks |
|-----|-------|------------|----------|
| J01 | Project skeleton and conventions | none | everything |
| J02 | Player movement, aim and camera | J01 | J04 |
| J03 | Stats, health and damage pipeline | J01 | J04, J06, J07, J10, J20 |
| J04 | Weapon and skill framework (sword, bow) | J02, J03 | J05, J07 |
| J05 | Remaining weapons and skill sets | J04 | J17 |
| J06 | Items, inventory, equipment and loot | J03 | J10, J16, J18, J19 |
| J07 | Enemy framework and AI | J03, J04 | J08, J13 |
| J08 | Act 1 bestiary | J07 | J09, J13, J14 |
| J09 | Boss framework and the six bosses | J07, J08 | J17 |
| J10 | Character progression and sheet | J03, J04, J06 | J18, J19 |
| J11 | World state: day and fog | J01 | J12, J13 |
| J12 | Zone framework, transitions and world map | J01, J11 | J13, J14, J19 |
| J13 | Graybox zones | J12, J07, J08 | J17 |
| J14 | Dungeons: wolf den and flooded cave | J12, J08 | J17 |
| J15 | Quest system and journal | J01 | J16, J17, J18, J19 |
| J16 | NPCs, dialogue and vendors | J01, J06, J15 | J17 |
| J17 | Act 1 quest content and scripted scenes | J05, J09, J11, J13, J14, J15, J16 | J22 |
| J18 | HUD and menus | J03, J04, J06, J10, J15 | J22 |
| J19 | Save and load | J06, J10, J12, J15 | J22 |
| J20 | Combat feel and feedback | J03, J04 | J22 |
| J21 | Test suite | J03, J06, J15 | J22 |
| J22 | Playtest build, debug tools and walkthrough | all | none |

## Parallel lanes

After J01 to J03 are merged, four lanes can run at once in separate sessions:

- **Combat lane:** J04 → J05 → J07 → J08 → J09 → J20
- **Items lane:** J06 → J10 → J18
- **World lane:** J11 → J12 → J13 and J14
- **Quest lane:** J15 → J16

Then J17 and J19 join the lanes, and J21 and J22 close.

## Recommended solo order

J01, J02, J03, J04, J07, J08, J06, J05, J10, J18, J11, J12, J13, J14, J09, J15, J16, J17, J19, J20, J21, J22. This gets to a fight fast and leaves polish for last.

## Godot from the command line

The download was extracted into a folder that carries the executable's name, so the real path is
`C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe\Godot_v4.7.2-stable_win64_console.exe`. Use the `_console` build for scripts; it writes output to the terminal. The sibling `Godot_v4.7.2-stable_win64.exe` is the same engine without a console.

From the repo root, with `GODOT` set to that path:

```
"%GODOT%" --path game --editor                                   open the editor
"%GODOT%" --headless --path game --import                        import resources and exit (first run, or after adding files)
"%GODOT%" --headless --path game --quit                          run the main scene for one frame; script errors print here
"%GODOT%" --headless --path game --check-only -s res://x.gd      parse-check one script
"%GODOT%" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit    run GUT tests
```

An agent cannot see the editor. "Editor loads clean" in a job's acceptance criteria is checked headless: `--import` then `--quit` must print no lines containing `ERROR`, `SCRIPT ERROR` or `Parse Error`.
