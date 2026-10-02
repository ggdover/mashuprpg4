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
| `tools\camera_follow_probe.cmd` | Measures how steadily the camera follows the walking player at 30, 60 and 144 fps, headless; exit code 0 means steady (see Camera rig) |

All five call `C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (the console build, so output lands in the terminal) and pass extra arguments through to Godot.

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

To parse-check one script: `"%GODOT%" --headless --path game --check-only -s res://graybox/graybox.gd`. That only works for a script that reaches no autoload. `--check-only` compiles the script before the autoloads are registered, so a script that uses `EventBus`, `GameState`, `WorldState` or `SaveSystem`, directly or through a class that does (`Palette` reads `WorldState`), prints `SCRIPT ERROR: Compile Error: Identifier not found: EventBus` although nothing is wrong with it. Check those scripts with `--quit` and `tools\test.cmd` instead. A script that Godot runs with `-s`, as the two under `tools/` are, is compiled at that same early moment together with every class it names, so it names no autoload and no project class and loads what it needs by path; `../plan/README.md`, Godot from the command line, says more.

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
- `GameState`: `phase`, `flags` with `set_flag` / `has_flag` (emits `EventBus.flag_set` the first time a flag is set), `current_zone`, and `zone_state` with `add_zone_state` / `has_zone_state`: what a zone remembers while its scene is not loaded, such as its lit cairns.
- `WorldState`: `enum State { DAY, FOG }` and `state`; assigning a new value emits `EventBus.world_state_changed`. `request_fog`, `end_fog` and `on_zone_entered` start and end the fog; World state, below, says how.
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

All of it runs in `Player._physics_process`, 60 times a second. The tunables are `@export`s on the player. A tick of no length, which is what `Engine.time_scale` 0 hands out, changes nothing: the body stands where it is, and a dash that is under way goes on when time does.

1. **Input.** The four move actions become one vector whose length is capped at 1, so a diagonal is no faster than a straight line. The vector is turned by `CameraRig.get_yaw()`, which makes W "up on screen". The result is `move_dir`: unit length on the XZ plane while a key is held, zero otherwise.
2. **Walking.** The wanted velocity is `move_dir` × `move_speed` (6 m/s) × `movement_multiplier`. The horizontal velocity moves toward it in a straight line, at `acceleration` (40 m/s²) while a key is held and at `friction` (30 m/s²) when none is. That is 0.15 s to top speed and 0.2 s to a stop.
3. **Attack slowdown.** `movement_multiplier` is the only coupling to combat. J04 sets it to a skill's multiplier (0.6) while the skill runs and back to 1 afterwards.
4. **Facing.** The body turns toward `aim.aim_dir` at `turn_speed` (20 rad/s, half a turn in 0.16 s). `move_dir` plays no part in it, so the box faces the mouse whichever way it walks.
5. **Gravity and floor.** `gravity` (20 m/s²) pulls while the body is off the floor. It snaps to the floor and takes slopes up to 45° as floor; both are the `CharacterBody3D` defaults (`floor_snap_length` 0.1 m, `floor_max_angle` 45°).
6. **Collision.** A capsule, radius 0.4 m and height 1.8 m, on layer 2 (`player_body`), colliding with layer 1 (`world`) only. `move_and_slide` slides it along whatever it walks into. `wall_min_slide_angle` is 0 in `player.tscn`: with Godot's default of 15° the body stops dead on a wall it meets almost head-on and on a pillar corner it only clips. One case has no slide in it: a round body that meets a corner exactly dead centre has no side to go to and would stand against it for as long as the keys are held. The player then takes one `corner_step` (5 cm) sideways and the slide carries it round. It tells a corner from a wall by looking a step to the side: a wall has the same normal there and is left alone, so walking head-on into a wall still stops the body.
7. **Dodge.** `try_dodge()`, called on the `dodge` action, dashes `dodge_distance` (5 m) in `dodge_duration` (0.25 s): along `move_dir`, or along `aim.aim_dir` while no key is held. The dash is ordinary motion, so walls stop it. For its length `is_invulnerable` is true and `can_act` is false. When it ends the body carries on at walking speed where the keys point, or stands still; it does not coast. `dodge_cooldown` (0.8 s) runs from the start of a dash, and `dodge_cooldown_left` counts it down.

Before a dodge starts, the player emits `dodge_requested(request: DodgeRequest)`. A listener that cannot allow it calls `request.deny()`. Nothing listens yet; J04 connects the stamina cost there.

`move_dir`, `can_act`, `is_dodging` and `dodge_cooldown_left` are read-only, and so are `Aim.aim_point` and `Aim.aim_dir`: writing to one pushes an error and changes nothing.

### Aim

`Aim` casts a ray from the active camera through the mouse onto the horizontal plane at the player's feet, every physics frame, just before the player moves (`process_physics_priority` -1 in `player.tscn`). `aim_point` is where the ray lands. `aim_dir` is the unit direction on the XZ plane from the player to it, and it keeps its last value while the ray misses the plane or the mouse is within `min_aim_distance` (0.1 m) of the player. Skills read `player.aim.aim_dir` at the moment they fire.

### Camera rig

The rig's origin is the point the camera looks at. Every rendered frame it closes a share of the gap to its target, `1 - exp(-follow_rate × delta)` with `follow_rate` 8, which adds up to the same motion at any frame rate. At walking speed it trails the player by about 0.7 m. The camera hangs `distance` (18 m) away at `pitch_degrees` (55°) with a 40° field of view and no yaw. The mouse wheel moves `distance` by `zoom_step` (1 m) between `min_distance` (12 m) and `max_distance` (24 m), and the camera eases to it.

The project interpolates physics (`physics/common/physics_interpolation`), so the player is drawn between its physics ticks. The rig is not interpolated (`physics_interpolation_mode` Off in `camera_rig.tscn`); it moves in `_process` and follows `get_global_transform_interpolated()`, the position the player is drawn at. Following `global_position` instead would make the player shake on screen whenever frames and ticks fall out of step. `tools\camera_follow_probe.cmd` measures it: it walks the player through the test scene headless at 30, 60 and 144 frames per second and prints how much the distance between the rig and the drawn player changes. It changes by 0.01 mm, where a pixel is about 15 mm of ground at the default zoom; a rig chasing the physics ticks would vary by 3.7 mm at 144 fps. The probe sets each frame rate with Godot's `--fixed-fps`, which gives every frame the same length of game time whatever the machine is doing, so it prints the same figures on every run.

When something teleports the player (a zone change, a respawn), set its position and then call `player.reset_physics_interpolation()` and `camera_rig.snap_to_target()`, so that neither draws the jump as a glide. That works from anywhere in a frame, and when the player walks or dashes on through the teleport the rig follows where it is drawn, as on any other frame. The engine works out what `get_global_transform_interpolated()` returns after a frame's physics ticks and ahead of every `_process`. After a jump made later in the frame it is still the old place, although the frame draws the player at the new one, so for the rest of such a frame the rig follows `global_position`. After a snap made in a physics tick, or ahead of one in an input event, it does not: the engine works out the drawn position after the snap, and `global_position` is up to a tick of travel ahead of that while the player moves.

## World state: day and fog (`core/world_state.gd`, `world/`)

The forest has two states, and everything asks `WorldState` which one it is. `test/test_world_state.tscn` shows the whole system in the arena: `tools\run.cmd res://test/test_world_state.tscn`. F brings the fog and G ends it, P steps the story phase, L toggles the lantern flag, O, V and U walk the player into an open zone, a village and a dungeon, and E lights the cairn the player stands at. The overlay shows what the world state makes of it, and the scene prints the horn until J18 has a toast for it.

| File | Class | What it is |
|------|-------|------------|
| `core/world_state.gd` | `WorldState` (autoload) | The state, and what starts and ends the fog |
| `world/environment_controller.gd` | `EnvironmentController` (`Node`) | One in every zone: shows the day, fog or cave look and tweens between them |
| `world/environment/` | `Environment`, `LightPreset` | The looks: `env_day`, `env_fog`, `env_cave`, `light_day` and `light_fog` (`.tres`), and `light_preset.gd` |
| `world/state_visibility.gd` | `StateVisibility` (`Node`) | Child of anything that exists in one state only |
| `world/signpost.tscn`, `signpost.gd` | `Signpost` (`Node3D`) | A post with a text and a `StateVisibility` of its own |
| `world/cairn.tscn`, `cairn.gd` | `Cairn` (`Node3D`) | A stone waypoint; once lit, a beacon in fog and a safe point |
| `player/player_light.gd` | `PlayerLight` (`Node3D`) | The player's ember light, a child of the player |

### What starts and ends the fog

- `WorldState.request_fog(reason)` brings the fog, emits `EventBus.fog_started(reason)` and, outside a dungeon, `EventBus.horn_sounded`. It does nothing in a village and nothing while it is fog already, and returns whether the fog started.
- `WorldState.end_fog()` brings the day back and emits `EventBus.fog_ended`.
- `WorldState.on_zone_entered(zone_id, kind)` is what the zone manager (J12) calls once the player stands in a new zone; `kind` is a `WorldState.ZoneKind`. A `VILLAGE` ends the fog. An `OPEN` zone rolls `fog_chance_by_phase` (0, 10 and 25 % in phases 1 to 3) and on success asks for fog with the reason `&"random"`. An entry into a zone whose last entry brought fog that way does not roll, so no zone gets random fog twice in a row. A `DUNGEON` changes nothing. `WorldState.zone_kind` keeps the kind; it is `OPEN` until a zone has been entered.
- While `WorldState.fog_scene_active` is set (J17 sets it around a scripted scene), entering a zone neither rolls for fog nor ends it. `request_fog` and `end_fog` still do as they are told, so the scene starts and ends its own fog.
- Assigning `WorldState.state` switches the state with `world_state_changed` alone: no fog signals, no horn. A loaded save and a debug key do that.

### The three looks

| | Day | Fog | Cave |
|---|-----|-----|------|
| Background | sky: top day `sky`, horizon `#B5D2EE` | the same sky, covered by the fog | fog `deepest`, no sky |
| Ambient light | day `light` at 0.5 | fog `mid` at 1 | fog `deepest` at 0.2 |
| Fog | none | fog `light`, 0 to 45 m, curve 0.8 | fog `shadow`, 18 to 38 m |
| Directional light | `sun` at 1.2, hard shadows | `spirit` at 0.35, soft shadows | none |

The fog is Godot's depth fog, which is measured from the camera, and the camera hangs 18 m from the player. In the fog look it covers a third of what stands at the bottom of the screen, 43 % of the player and two thirds of what stands at the top; a box 35 m from the camera is 90 % gone and from 45 m on nothing is left. Exponential fog thick enough to hide a box at 50 m would cover three quarters of everything around the player. The cave fog begins at the default camera distance and is complete 20 m further; in a cave it is the player's light that decides what is seen.

The presets hold literal palette values, because a resource cannot read a script constant. `test/unit/test_environment.gd` checks every one against `Palette`, as `test_graybox.gd` does for the kit materials.

`EnvironmentController` owns the zone's `WorldEnvironment` and `DirectionalLight3D`. Point its `world_environment` and `sun` exports at the two a scene has, as the test scene does with the arena's; left empty, it makes its own, with the sun 45° above the horizon. When it becomes ready it shows the look of the state at once. On `world_state_changed` it tweens to the other look over `transition_seconds` (2.5): the fog's colour, density, reach and cover of the sky, the ambient colour and energy, and the sun's colour, energy and shadow softness. A transition that is interrupted goes on from where it stands. `force_cave` shows the cave look in both states and switches the sun off; dungeons set it. `volumetric_fog` (off) adds volumetric fog to the fog and cave looks. The presets are never written to: the `WorldEnvironment` gets a copy. `show_state(seconds)` brings the look up to date by hand.

### Things that exist in one state

`StateVisibility` has two flags, `day` and `fog`. When it becomes ready and at every change of state it sets its parent's `visible` and disables every `CollisionShape3D` under the parent that is not drawn, so what is hidden can be walked through. One node on a group covers the whole group, and a group may hold things with a `StateVisibility` of their own: a shape collides only while everything above it is shown. The shapes switch at the end of the frame. `Signpost` exports `text`, `day` and `fog`; a day and a fog signpost on the same spot read as one post whose sign changes.

### Cairns

A `Cairn` is a stack of three boxes with a fire (an ember `OmniLight3D`) and a beacon, a 10 m box that shows ember whatever light falls on it and whose material takes no fog, so a lit cairn is seen from as far as the camera sees. Both show only while `lit`.

- `lit` (export) is what the cairn shows. `light()` is the event: it lights the cairn, remembers it in `GameState.zone_state` (zone id, then `"cairns_lit"`, then the `cairn_id`, which is the node name unless set) and emits `EventBus.cairn_lit(cairn)`.
- `interact(tallow_available) -> int` is what E does: it lights an unlit cairn when the tallow covers `tallow_cost` (1) and returns the tallow burnt, which the caller takes out of the inventory. `get_prompt()` and the `InteractArea` (`Area3D` on layer 9) are there for J06's interactor.
- A remembered cairn comes back lit, when it becomes ready and again when `EventBus.zone_entered` names its zone, without emitting `cairn_lit`.
- `is_safe_point` is true while lit (J20 respawns there). `WorldState.nearest_lit_cairn(position)` returns the nearest lit cairn in the scene tree, or null (J18's bell).

### Player light

`PlayerLight` hangs 2.5 m above the player's feet in `player.tscn` and makes its own `OmniLight3D` in ember. It is out by day and burns in fog and in a dungeon (`WorldState.zone_kind`), reaching `base_range` (6 m), or `lantern_range` (12 m) once the `has_lantern` flag is set. It reads the state, the kind of zone and the flag every frame, so a loaded save or a debug command needs no signal to reach it.

## Collision layers

1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox, 5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox, 8 projectile, 9 interactable, 10 world_item.

## Input actions

`move_up` W, `move_down` S, `move_left` A, `move_right` D (physical keys), `attack_basic` LMB, `skill_1` RMB, `skill_2` 1, `skill_3` 2, `dodge` Space, `interact` E, `inventory` I, `character` C, `journal` J, `pause` Esc, `debug_console` F1, `debug_cycle_weapon` Tab.

## Conventions

See `../plan/README.md`, Conventions. In short: static typing everywhere (`project.godot` makes an untyped declaration a compile error; write `Variant` where anything goes), `snake_case` files, `PascalCase` classes, past-tense signals, no magic numbers (tune through `@export` or `.tres`), composition over inheritance, one test scene per job under `test/`.
