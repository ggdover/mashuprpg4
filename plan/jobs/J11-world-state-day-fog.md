# J11: World state, day and fog

**Milestone:** M4 · **Depends on:** J01 · **Unblocks:** J12, J13
**Reads first:** `design/gdd.md` §World, §Presentation; `design/world_act1.md` §Signposts, §Glossary; `design/palette.md` (both states, all roles)

## Goal

The two states of the forest as a system: environment and lighting presets built from the palette, a transition, triggers (scripted and probabilistic), things that only exist in one state, cairns as safe beacons, the horn cue, and the player's light. Everything else in the game asks `WorldState` what state it is.

## Deliverables

- `game/core/world_state.gd` completed (`WorldState` autoload)
- `game/world/environment/env_day.tres`, `env_fog.tres`, `env_cave.tres` (`Environment` resources) and `light_day.tres`, `light_fog.tres` (small resources holding DirectionalLight colour and energy)
- `game/world/environment_controller.gd` (`class_name EnvironmentController`, Node in every zone)
- `game/world/state_visibility.gd` (`class_name StateVisibility`, Node)
- `game/world/cairn.tscn` and `cairn.gd` (`class_name Cairn`)
- `game/world/signpost.tscn` (a box with a `Label3D`, uses StateVisibility)
- `game/player/player_light.gd` (`class_name PlayerLight`, Node with an OmniLight3D)
- `game/test/test_world_state.tscn`
- New `EventBus` signals: `fog_started(reason: StringName)`, `fog_ended`, `horn_sounded`, `cairn_lit(cairn)`

## Spec

**WorldState.** `state` (DAY, FOG) with the setter from J01. `request_fog(reason: StringName)`: switches to FOG unless the current zone is a village, emits `fog_started` and `horn_sounded`. `end_fog()`: switches to DAY, emits `fog_ended`. `on_zone_entered(zone_id, kind)`, with `kind` a `WorldState.ZoneKind` (VILLAGE, OPEN, DUNGEON): villages always end fog; open zones roll `fog_chance_by_phase = {1: 0.0, 2: 0.10, 3: 0.25}` and call `request_fog(&"random")` on success, but never twice in a row for the same zone. Dungeons don't change the state but use their own environment. `fog_scene_active: bool` keeps zone entries from rolling random fog and from ending the fog while a scripted scene runs (J17 sets it).

**Environment presets, from the palette.** Day: sky top `sky`, sky horizon `#B5D2EE`, ambient `ramp.light` at energy 0.5, no fog, DirectionalLight colour `sun`, energy 1.2, angle 45°, shadows on. Fog: `fog_enabled` true, fog colour `ramp.light` (`#99A4B3`), depth fog from 0 to 45 m from the camera, tuned so that a box at 35 m is barely visible and at 50 m invisible while the player's surroundings stay readable, ambient `ramp.mid`, DirectionalLight colour `spirit`, energy 0.35, shadows soft. Cave: ambient `ramp.deepest` at 0.2, no sky, fog colour `ramp.shadow` with visibility 20 m past the player (depth fog from 18 to 38 m from the camera), no directional light. Volumetric fog off by default; leave a toggle.

**EnvironmentController.** Owns the zone's `WorldEnvironment` and `DirectionalLight3D`. On ready it shows the preset of the state; on `world_state_changed` it tweens between presets over 2.5 s (fog colour, density, ambient, light energy and colour). Dungeons pass `force_cave = true`.

**StateVisibility.** `@export var day := true`, `@export var fog := true`. Sets the parent's `visible` and, for any `CollisionShape3D` under the parent, `disabled`. Applied on ready and on state change. Used for day signposts (Sjön, Berget), fog signposts (Norr, Skogen, Ingen väg, Frost), landmarks hidden in fog, and paths that only exist in fog.

**Cairn.** A stack of boxes with an `OmniLight3D` (ember colour) and a tall thin emissive box as the beacon. `lit: bool` persisted in `GameState.zone_state`. When lit and the state is FOG, the beacon is visible through the fog (emissive, `no_fog` material flag or a rendered marker in the HUD later). `is_safe_point`: the respawn system uses the nearest lit cairn or village. `interact(tallow_available)` on an unlit cairn with tallow in the inventory lights it and returns the tallow burnt (J17 wires the quest; the interaction lives here). Emits `cairn_lit`. `WorldState.nearest_lit_cairn(position) -> Cairn` for the bell.

**Player light.** OmniLight3D on the player, range 6 m by default, 12 m when `GameState.has_flag(&"has_lantern")`, colour ember. Only enabled in FOG and in caves so the day scene isn't affected.

**Horn.** `horn_sounded` is emitted on every fog start except inside dungeons. J18 shows the text; here, the test scene prints it.

**Neutral animals.** Nothing to do: J07 already listens to `world_state_changed`.

**Test scene.** Arena with an EnvironmentController, day and fog signposts on the same post, two cairns (one lit), a landmark box hidden in fog, a fog-only path of boxes, keys for `request_fog`, `end_fog`, phase, and a lantern flag toggle. Screenshot both states next to `design/palette.html` and adjust the presets until the day scene reads warm and the fog scene reads blue-slate.

## Acceptance criteria

- [ ] Switching state tweens the environment over 2.5 s and the two looks match the palette moods
- [ ] Day and fog signposts swap; the landmark hides and the fog path appears
- [ ] A lit cairn's beacon is visible from 50 m in fog while an unlit one is not
- [ ] Random fog never triggers in villages and follows the per-phase chance in open zones
- [ ] Player light is off by day, 6 m in fog, 12 m with the lantern flag
- [ ] Editor loads clean

## Out of scope

Zone loading (J12), spawner reactions (J07), HUD indicators (J18).

## Notes for later jobs

- J12 calls `WorldState.on_zone_entered(zone_id, kind)` after placing the player. `kind` is a `WorldState.ZoneKind` (VILLAGE, OPEN, DUNGEON, the three kinds J12's `ZoneData` names): type `ZoneData.kind` with it, or cast. Until the first call `WorldState.zone_kind` is OPEN.
- J12: `GameState.zone_state` exists, with `add_zone_state(zone_id, key, entry)` and `has_zone_state(zone_id, key, entry)`. Cairns keep their ids under the key `Cairn.ZONE_STATE_KEY` (`&"cairns_lit"`); add `bosses_dead` and `chests_opened` the same way. A cairn restores itself, when it becomes ready (under `GameState.current_zone`) and again when `EventBus.zone_entered` names the zone, so a zone does not have to apply its lit cairns, and the order in which the zone manager sets `current_zone` and adds the zone to the tree does not matter.
- J12, J13, J14: an `EnvironmentController` is a plain `Node` with `environment_controller.gd`; there is no scene for it. Left alone it makes the zone's `WorldEnvironment` and sun itself, so a zone holds neither, or points the controller's `world_environment` and `sun` exports at its own. A second `WorldEnvironment` or sun in the tree would compete with it. Dungeons set `force_cave` on the node in their scene.
- J13: put a `StateVisibility` (a `Node` with `state_visibility.gd`, flags `day` and `fog`) under the thing to show and hide, or under a `Node3D` that groups several; every collision shape below is switched with it. `signpost.tscn` exports `text`, `day` and `fog`. `cairn.tscn` exports `lit`; the node name is the id it is remembered under (`Cairn_Crossroads`, `Cairn_1`), so keep the names unique within a zone.
- J14: the player's light burns while `WorldState.zone_kind` is DUNGEON, which the zone manager's `on_zone_entered` sets; `force_cave` only changes the environment.
- J06, J13, J17: the cairn does not know the inventory. Whoever handles E at a cairn counts the item `Cairn.TALLOW_ITEM_ID` (`&"tallow"`), calls `cairn.interact(count)` and removes the number it returns; `test/world_state_test_scene.gd` does it with a counter. `cairn.get_prompt()` is the prompt text, and `InteractArea` is an `Area3D` on layer 9 for the interactor to find; adapt both to the interactor's protocol when J06 is merged. `cairn.light()` lights a cairn without tallow.
- J17 calls `request_fog(&"FOG_1")` and friends and sets `fog_scene_active` around scripted scenes. `request_fog` returns whether the fog started. It refuses in a village, so `first_fog_village`, which plays in Tjärnäs, cannot use it as it stands: see the open question in Deviations. For the `farewell` night, give the zone's `EnvironmentController` a darker `LightPreset` as `fog_light` and call `show_state(seconds)`.
- J18 renders a bell indicator toward `nearest_lit_cairn` when `has_bell` is set; it returns null when no cairn in the loaded zone is lit. `horn_sounded` is the cue for the horn toast; only the J11 test scene prints the text. `fog_started(reason)` and `fog_ended` come from `request_fog` and `end_fog` alone; an indicator that must follow every change listens to `world_state_changed`.
- J19: assigning `WorldState.state` emits `world_state_changed` and nothing else, which is what a load wants. `GameState.zone_state` is a Dictionary of Dictionaries of Arrays of ids and goes to JSON as it is.
- J20: a lit cairn has `is_safe_point` true; all cairns are in the group `WorldState.CAIRN_GROUP`.
- J21: `test/unit/test_world_state.gd` already covers `on_zone_entered` in villages and the chance per phase.

## Deviations

World state:

- **`on_zone_entered(zone_id: StringName, kind: WorldState.ZoneKind)`, not `on_zone_entered(zone)`.** No zone class exists before J12, so `WorldState` defines `ZoneKind { VILLAGE, OPEN, DUNGEON }` and keeps the last kind in `zone_kind` (OPEN until a zone is entered, so a scene without zones can have fog). The spec sentence and the J12 note were corrected.
- **`request_fog` returns whether the fog started and does nothing while it is fog already**: no second `fog_started`, no second horn. `end_fog` does nothing by day.
- **"Never twice in a row for the same zone" is counted per zone.** An entry into a zone whose last entry rolled fog does not roll; the entry after that rolls again. Walking into an open zone while it is fog rolls nothing and uses nothing up.
- **`fog_scene_active` stops zone entries from rolling fog and from ending it**; `request_fog` and `end_fog` stay usable, so a scripted scene starts and ends its own fog. The spec sentence ("blocks random fog ending") was reworded to say so.
- **`WorldState.rng` is public** so that tests seed the fog roll; `RANDOM_REASON` and `CAIRN_GROUP` are constants there.
- **The horn text is printed by the test scene, not by `WorldState`.** An autoload that prints would fill every test log, and the game's output once J18 shows the toast. The spec sentence was corrected.

Presets and controller:

- **Depth fog, not a density.** Godot measures fog from the camera, which hangs 18 m from the player. Exponential fog that hides a box at 50 m (density 0.078) covers 75 % of everything around the player; a render showed the arena washed out. `env_fog.tres` uses depth fog from 0 to 45 m with curve 0.8: 43 % on the player, 90 % at 35 m, everything from 45 m. The spec sentence was corrected.
- **Cave "visibility 20 m" is 20 m past the player**: depth fog from 18 m, the default camera distance, to 38 m. Counted from the camera it would hide the player. The cave takes `deepest` and `shadow` from the fog ramp, so that the ember of the player's light is the only warm colour.
- **Values the spec leaves open.** Fog ambient energy 1. The day and the fog preset carry the same sky (top `sky`, horizon and ground horizon `#B5D2EE`, ground bottom day `canopy`), which the fog covers through `fog_sky_affect`. Sky reflections are off in all three presets, so the shade is lit by the ambient colour alone. "Shadows soft" is a light angle of 3° (`LightPreset.shadow_softness`). Volumetric fog, when toggled on, takes albedo and density from the presets.
- **`world/environment/light_preset.gd` (`LightPreset`) was added**: the class behind `light_day.tres` and `light_fog.tres` (colour, energy, shadow softness).
- **On ready the controller shows the look of the state at once.** Nothing is on screen to tween from. The spec sentence was corrected.
- **The transition runs in `_process`, without a `Tween` object.** The tests step it with exact times (half-way after 1.25 s, done at 2.5 s), as J02's camera tests do, so they do not depend on how busy the machine is.
- **The tween covers more than the spec lists**: the fog's reach and its cover of the sky, the shadow softness, and the volumetric density as well. A look without fog borrows the fog colour of the other end, so only the amount changes on the way, and an interrupted transition goes on from where it stands.
- **The controller takes over a `WorldEnvironment` and a sun it is pointed at, or makes its own.** The arena has both; a zone can leave the two exports empty. Either way it switches the sun's shadows on. `show_state(seconds)` is public.

Things in the world:

- **`StateVisibility` disables every collision shape under the parent that is not drawn, not only the parent's own children.** One node then covers a group of boxes, and nested ones combine. The shapes switch at the end of the frame, because a state change can arrive inside a physics callback. The spec sentence was corrected.
- **`world/signpost.gd` (`Signpost`) was added**, with `text`, `day` and `fog` exports; without a script every instance would need editable children to set its text and flags.
- **`Cairn.interact(tallow_available: int) -> int`.** No inventory exists before J06, so the caller counts the tallow and removes what the call returns. `light()` lights a cairn without tallow; `get_prompt()` and the `InteractArea` on layer 9 are ready for J06's interactor.
- **Fire and beacon show whenever the cairn is lit, by day too.** The beacon is unshaded ember with `disable_fog` rather than emissive: the same picture, and the sun adds nothing to it.
- **`GameState.zone_state`, `add_zone_state` and `has_zone_state` were added here.** J12 specifies the dictionary, but the cairn needs it first; the helpers take the list's key, so J12 adds `bosses_dead` and `chests_opened` without new code. A cairn restores itself on ready and on `zone_entered`.
- **`cairn_lit(cairn: Node3D)`** names the engine class, as `enemy_died(enemy: Node)` does, so the bus names no project class.
- **`PlayerLight` is a `Node3D` that makes its `OmniLight3D`, and it reads the state, the kind of zone and the flag every frame** instead of waiting for signals: a loaded save sets flags without `flag_set`, and the kind of zone has no signal. "In caves" is `WorldState.zone_kind == DUNGEON`. Energy 3, attenuation 0.6, 2.5 m above the feet and no shadows (the player's own box would shade the ground) were tuned on renders. `player.tscn` gained the node.

Test scene, tests and documents:

- **The test scene has four keys more than the spec names**: O, V and U walk the player into an open zone, a village and a dungeon (the zone entry rules, the cave look and the light in a cave would otherwise have nothing to show them), and E lights the cairn in reach with the scene's one tallow. Its script is `test/world_state_test_scene.gd` (`WorldStateTestScene`).
- **GUT tests were added although the job lists none**: `test_world_state.gd`, `test_environment.gd`, `test_state_visibility.gd`, `test_cairn.gd`, `test_player_light.gd` and `test_world_state_scene.gd`, 94 tests. Nobody can look at the test scene from the command line, so the acceptance criteria are checked as numbers; the chance per phase is measured over 10 000 seeded zone entries. Eight behaviours were broken on purpose once to see their tests fail.
- **J01's open review note on palette drift is closed.** `test_environment.gd` checks every colour in the five presets against `Palette`, and `test_graybox.gd` gained two tests that do the same for the seven kit materials and the arena's sun and environment. The note in `plan/jobs/J01-project-skeleton.md` is marked done.
- **`game/README.md` gained a section, World state: day and fog**, and its `GameState` and `WorldState` lines under Autoloads were extended.
- **The looks were tuned and checked on rendered frames, not only headless.** Scratch probes outside the repository ran the test scene in a window and saved screenshots. Day: mean colour `#7A6226`, hue 43°, every pixel warm (the day references in `ref_imgs/` average hue 43° to 58°). Fog: mean `#7A7F84`, hue 211°, 79 % of the pixels cool (the fog references average hue 194° to 235°). The fog measured in a picture at 11, 18, 26, 35, 45 and 50 m from the camera was 22, 44, 68, 90, 100 and 100 %, which is what the formula in `test_environment.gd` gives. A lit cairn 50 m away showed its beacon in pure ember `#E39A4C`; an unlit one was the colour of the fog. The player walked through the place of the landmark in fog and was stopped by it by day. What is left for a person: whether the two looks please the eye next to `design/palette.html`.
- **Every script compiles with each default-level GDScript warning raised to an error**, checked with a temporary `override.cfg`, and the headless editor opens the three new scenes without a message.

Open question for J17 and the user:

- **`request_fog` refuses in a village, as the spec says, but `first_fog_village` plays in Tjärnäs with 20 s of fog** (J17), and `design/world_act1.md` gives Norrby, a village, "fog most days". With the code as it stands a scene in a village sets `fog_scene_active`, assigns `WorldState.state = WorldState.State.FOG`, emits `EventBus.horn_sounded` itself and ends with `end_fog()`. If scripted fog in a village is wanted as a rule, let `request_fog` pass in a village while `fog_scene_active` is set; whether Norrby should count as a village for the fog is J13's call when it writes the zone data.
