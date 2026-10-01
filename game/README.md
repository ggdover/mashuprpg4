# mashuprpg4 (Godot project)

Godot 4.7.2, Forward+, GDScript with static typing. The design lives in `../design/`, the execution plan in `../plan/`. Everything in here is a gray box until the art pass.

## Open, run, test

From the repo root on Windows:

| Command | What it does |
|---------|--------------|
| `tools\godot.cmd` | Opens this project in the Godot editor |
| `tools\run.cmd` | Runs the game (main scene `res://test/test_player.tscn`) without the editor. Another scene: `tools\run.cmd res://test/test_graybox.tscn` |
| `tools\test.cmd` | Runs the GUT unit tests in `res://test/unit` headless; exit code 0 means no test failed |
| `tools\gut_panel_setup.cmd` | Once per machine: points the GUT panel in the editor at `res://test/unit` (see GUT in the editor) |

All four call `C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (the console build, so output lands in the terminal) and pass extra arguments through to Godot.

### Headless checks

This is what the plan means by "the editor loads clean" when nobody can look at the editor:

```
set GODOT=C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
"%GODOT%" --headless --path game --import     import resources (first run, or after adding files)
"%GODOT%" --headless --path game --quit       run the main scene for one frame; script errors print here
tools\test.cmd                                GUT
```

No output line may contain `ERROR`, `SCRIPT ERROR` or `Parse Error`. Read the lines, not only the exit code: GUT skips a test script that has a parse error and still exits with 0.

These runs compile only what they load: the autoloads, everything the main scene uses, and the tests with everything those use. A script that neither the main scene nor a test touches is not checked by anything; give it a test, or run the scene that uses it for one frame with `"%GODOT%" --headless --path game res://test/x.tscn --quit`. `--quit` stops after the first frame, before most per-frame code has run; `--quit-after 300` in its place runs 300 frames.

To parse-check one script: `"%GODOT%" --headless --path game --check-only -s res://graybox/graybox.gd`. That only works for a script that reaches no autoload. `--check-only` compiles the script before the autoloads are registered, so a script that uses `EventBus`, `GameState`, `WorldState` or `SaveSystem`, directly or through a class that does (`Palette` reads `WorldState`), prints `SCRIPT ERROR: Compile Error: Identifier not found: EventBus` although nothing is wrong with it. Check those scripts with `--quit` and `tools\test.cmd` instead.

### GUT in the editor

The plugin is enabled in `project.godot`, so the GUT panel sits in the bottom dock. The panel keeps its settings outside the repository, in `user://gut_temp_directory/gut_editor_config.json`, and runs nothing until that file names a test directory. Once per machine, after the first import (`--import`, or opening the editor once) and with the editor closed, run from the repo root:

```
tools\gut_panel_setup.cmd
```

It adds `res://test/unit` (subdirectories included) to the panel's settings through GUT's own config class and leaves every other setting alone; running it again changes nothing. The same can be done by hand in the panel under Settings, Test Directories. The command line and `tools\test.cmd` do not need it: they read `.gutconfig.json` in this folder, which already points there.

## Regenerate the palette

`core/palette.gd` is generated from `../design/palette.json`. After editing the JSON, from the repo root:

```
powershell -ExecutionPolicy Bypass -File tools\gen_palette_gd.ps1
```

Running it twice produces the same file. Never edit `palette.gd` by hand; add a paired row to the JSON instead (see `design/palette.md`, rule 6).

## Layout

| Folder | Holds |
|--------|-------|
| `core/` | Autoloads `EventBus`, `GameState`, `WorldState`, `SaveSystem`, and the generated `Palette` static class |
| `player/` | Player scene, movement, aim, camera rig (J02) |
| `combat/` | Health, hitbox, hurtbox, damage info, status effects, projectiles (J03, J04) |
| `weapons/`, `skills/` | Weapon and skill data and executors (J04, J05) |
| `items/` | Item data, affixes, loot tables, inventory, equipment (J06) |
| `enemies/`, `enemies/bosses/` | Enemy framework, bestiary, bosses (J07 to J09) |
| `world/`, `world/zones/`, `world/dungeons/` | Zone framework, zones and dungeons (J11 to J14) |
| `quests/`, `npcs/` | Quest system, NPCs, dialogue (J15, J16) |
| `ui/*` | HUD, inventory, character, journal, dialogue, vendor, menus, theme (J18) |
| `graybox/` | The placeholder kit: materials and base scenes |
| `test/` | One test scene per job, and the `unit/` GUT tests. `arena.tscn` is the arena the test scenes instance: ground, walls, pillars, light and the `PlayerSpawn` marker. It has no camera; the scene that instances it brings one. `test_player.tscn` (J02) is the main scene while there is no game, `test_graybox.tscn` (J01) lines up the six size classes |
| `addons/gut/` | GUT 9.7.1 |

Empty folders hold a `.gdkeep` so git keeps them.

## Autoloads

- `EventBus`: every cross-system signal. Add new signals there instead of wiring nodes to each other.
- `GameState`: `phase`, `flags` with `set_flag` / `has_flag` (emits `EventBus.flag_set` the first time a flag is set), `current_zone`.
- `WorldState`: `enum State { DAY, FOG }` and `state`; assigning a new value emits `EventBus.world_state_changed`.
- `SaveSystem`: `save()` and `load()` return `false` until J19.

Autoload scripts carry no `class_name` (it would hide the singleton), and neither do GUT test scripts (`test_*.gd`; GUT finds them by file name). Every other script under `game/`, outside `addons/`, has one. A test scene's own script therefore takes another name: `test/test_player.tscn` runs `test/player_test_scene.gd`.

## Graybox kit (`graybox/`)

Colours never appear inline in scripts: use `Palette.DAY`, `Palette.FOG` or `Palette.role(name, state)`. An accent exists in one state only, and `Palette.role` returns it from that state whichever one is asked for, so `Palette.role(&"ember", WorldState.state)` works by day too. The kit materials are `.tres` files that carry a palette value because resources cannot read a script constant; their roles are:

| Material | Palette role | Use |
|----------|--------------|-----|
| `mat_gray.tres` | day ramp mid `#7A7048` | Every box by default |
| `mat_frost.tres` | fog lichen `#A9B8C4` | Possessed creatures |
| `mat_highlight.tres` | day sun `#E6C878` | Interactables, highlights |
| `mat_rarity_common.tres` | day ramp light `#BFAF7E` | Ground items by rarity (gdd, Loot and equipment) |
| `mat_rarity_fine.tres` | day moss-lit `#AEB055` | |
| `mat_rarity_rare.tres` | day sky `#92B8E3` | |
| `mat_rarity_legendary.tres` | day sun `#E6C878` | |

Scripts reach them as `Graybox.MAT_GRAY`, `Graybox.MAT_FROST` and so on.

- `Graybox` (static): `SizeClass` enum and `SIZES` from the gdd placeholder policy, `make_box(size, material) -> MeshInstance3D`, `make_box_mesh`.
- `box_actor.tscn` / `BoxActor`: body box plus a nose box on the front. The front is -Z, Godot's forward, so `look_at` and `Vector3.FORWARD` agree with the nose. `size_class` picks the size; origin at the feet.
- `box_prop.tscn` / `BoxProp`: `StaticBody3D` on layer 1 (world) with a box mesh and matching collision; `size` sets both; origin at the bottom centre.
- `ground_plane.tscn`: 60 × 60 m plane with collision, top surface at y = 0.

Both actor and prop scripts are `@tool`, so size changes show in the editor. Each node takes its own copy of its mesh and collision shape when it becomes ready, so instances and duplicates (`Node.duplicate()`, Duplicate in the editor) can be resized and retinted one by one.

## Player, aim and camera (`player/`)

`test/test_player.tscn`, the main scene for now, puts the player and the camera rig into the arena with a debug overlay (speed, multiplier, aim point, dodge cooldown, fps). WASD walks, the mouse aims, Space dodges, the wheel zooms, and holding RMB stands in for an attack until J04: it slows the player to 60 %.

| File | Class | What it is |
|------|-------|------------|
| `player.tscn`, `player.gd` | `Player` (`CharacterBody3D`) | The body: capsule, the `box_actor` placeholder as `Visual`, the `Aim` child |
| `aim.gd` | `Aim` (`Node`) | Child of the player; where the mouse points on the ground |
| `camera_rig.tscn`, `camera_rig.gd` | `CameraRig` (`Node3D`) | Stands next to the player in the scene, follows it, carries the `Camera3D` |
| `dodge_request.gd` | `DodgeRequest` (`RefCounted`) | What `Player.dodge_requested` carries; a listener calls `deny()` to stop the dodge |

A scene that holds both wires them to each other in the inspector: `Player.camera_rig` and `CameraRig.target`.

### Movement model

All of it runs in `Player._physics_process`, 60 times a second. The tunables are `@export`s on the player.

1. **Input.** The four move actions become one vector whose length is capped at 1, so a diagonal is no faster than a straight line. The vector is turned by `CameraRig.get_yaw()`, which makes W "up on screen". The result is `move_dir`: unit length on the XZ plane while a key is held, zero otherwise.
2. **Walking.** The wanted velocity is `move_dir` × `move_speed` (6 m/s) × `movement_multiplier`. The horizontal velocity moves toward it in a straight line, at `acceleration` (40 m/s²) while a key is held and at `friction` (30 m/s²) when none is. That is 0.15 s to top speed and 0.2 s to a stop.
3. **Attack slowdown.** `movement_multiplier` is the only coupling to combat. J04 sets it to a skill's multiplier (0.6) while the skill runs and back to 1 afterwards.
4. **Facing.** The body turns toward `aim.aim_dir` at `turn_speed` (20 rad/s, half a turn in 0.16 s). `move_dir` plays no part in it, so the box faces the mouse whichever way it walks.
5. **Gravity and floor.** `gravity` (20 m/s²) pulls while the body is off the floor. It snaps to the floor and takes slopes up to 45° as floor; both are the `CharacterBody3D` defaults (`floor_snap_length` 0.1 m, `floor_max_angle` 45°).
6. **Collision.** A capsule, radius 0.4 m and height 1.8 m, on layer 2 (`player_body`), colliding with layer 1 (`world`) only. `move_and_slide` slides it along whatever it walks into. `wall_min_slide_angle` is 0 in `player.tscn`: with Godot's default of 15° the body stops dead on a wall it meets almost head-on and on a pillar corner it only clips.
7. **Dodge.** `try_dodge()`, called on the `dodge` action, dashes `dodge_distance` (5 m) in `dodge_duration` (0.25 s): along `move_dir`, or along `aim.aim_dir` while no key is held. The dash is ordinary motion, so walls stop it. For its length `is_invulnerable` is true and `can_act` is false. When it ends the body carries on at walking speed where the keys point, or stands still; it does not coast. `dodge_cooldown` (0.8 s) runs from the start of a dash, and `dodge_cooldown_left` counts it down.

Before a dodge starts, the player emits `dodge_requested(request: DodgeRequest)`. A listener that cannot allow it calls `request.deny()`. Nothing listens yet; J04 connects the stamina cost there.

### Aim

`Aim` casts a ray from the active camera through the mouse onto the horizontal plane at the player's feet, every physics frame, just before the player moves (`process_physics_priority` -1 in `player.tscn`). `aim_point` is where the ray lands. `aim_dir` is the unit direction on the XZ plane from the player to it, and it keeps its last value while the ray misses the plane or the mouse is within `min_aim_distance` (0.1 m) of the player. Skills read `player.aim.aim_dir` at the moment they fire.

### Camera rig

The rig's origin is the point the camera looks at. Every rendered frame it closes a share of the gap to its target, `1 - exp(-follow_rate × delta)` with `follow_rate` 8, which adds up to the same motion at any frame rate. At walking speed it trails the player by about 0.7 m. The camera hangs `distance` (18 m) away at `pitch_degrees` (55°) with a 40° field of view and no yaw. The mouse wheel moves `distance` by `zoom_step` (1 m) between `min_distance` (12 m) and `max_distance` (24 m), and the camera eases to it.

The project interpolates physics (`physics/common/physics_interpolation`), so the player is drawn between its physics ticks. The rig is not interpolated (`physics_interpolation_mode` Off in `camera_rig.tscn`); it moves in `_process` and follows `get_global_transform_interpolated()`, the position the player is drawn at. Following `global_position` instead would make the player shake on screen whenever frames and ticks fall out of step. Measured headless with the frame cap at 30, 60 and 144 fps, the distance between the rig and the drawn player varies by less than 0.3 mm while walking.

When something teleports the player (a zone change, a respawn), call `player.reset_physics_interpolation()` and `camera_rig.snap_to_target()` so that neither draws the jump as a glide.

## Collision layers

1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox, 5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox, 8 projectile, 9 interactable, 10 world_item.

## Input actions

`move_up` W, `move_down` S, `move_left` A, `move_right` D (physical keys), `attack_basic` LMB, `skill_1` RMB, `skill_2` 1, `skill_3` 2, `dodge` Space, `interact` E, `inventory` I, `character` C, `journal` J, `pause` Esc, `debug_console` F1, `debug_cycle_weapon` Tab.

## Conventions

See `../plan/README.md`, Conventions. In short: static typing everywhere (`project.godot` makes an untyped declaration a compile error; write `Variant` where anything goes), `snake_case` files, `PascalCase` classes, past-tense signals, no magic numbers (tune through `@export` or `.tres`), composition over inheritance, one test scene per job under `test/`.
