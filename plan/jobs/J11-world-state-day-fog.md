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

**WorldState.** `state` (DAY, FOG) with the setter from J01. `request_fog(reason: StringName)`: switches to FOG unless the current zone is a village, emits `fog_started` and `horn_sounded`. `end_fog()`: switches to DAY, emits `fog_ended`. `on_zone_entered(zone)`: villages always end fog; open zones roll `fog_chance_by_phase = {1: 0.0, 2: 0.10, 3: 0.25}` and call `request_fog(&"random")` on success, but never twice in a row for the same zone. Dungeons don't change the state but use their own environment. `fog_scene_active: bool` blocks random fog ending while a scripted scene runs (J17 sets it).

**Environment presets, from the palette.** Day: sky top `sky`, sky horizon `#B5D2EE`, ambient `ramp.light` at energy 0.5, no fog, DirectionalLight colour `sun`, energy 1.2, angle 45°, shadows on. Fog: `fog_enabled` true, fog colour `ramp.light` (`#99A4B3`), density tuned so that a box at 35 m is barely visible and at 50 m invisible, ambient `ramp.mid`, DirectionalLight colour `spirit`, energy 0.35, shadows soft. Cave: ambient `ramp.deepest` at 0.2, no sky, fog colour `ramp.shadow` with visibility 20 m, no directional light. Volumetric fog off by default; leave a toggle.

**EnvironmentController.** Owns the zone's `WorldEnvironment` and `DirectionalLight3D`. On ready and on `world_state_changed`, tweens between presets over 2.5 s (fog colour, density, ambient, light energy and colour). Dungeons pass `force_cave = true`.

**StateVisibility.** `@export var day := true`, `@export var fog := true`. Sets the parent's `visible` and, for any `CollisionShape3D` children of the parent, `disabled`. Applied on ready and on state change. Used for day signposts (Sjön, Berget), fog signposts (Norr, Skogen, Ingen väg, Frost), landmarks hidden in fog, and paths that only exist in fog.

**Cairn.** A stack of boxes with an `OmniLight3D` (ember colour) and a tall thin emissive box as the beacon. `lit: bool` persisted in `GameState.zone_state`. When lit and the state is FOG, the beacon is visible through the fog (emissive, `no_fog` material flag or a rendered marker in the HUD later). `is_safe_point`: the respawn system uses the nearest lit cairn or village. `interact` on an unlit cairn with tallow in the inventory lights it (J17 wires the quest; the interaction lives here). Emits `cairn_lit`. `WorldState.nearest_lit_cairn(position) -> Cairn` for the bell.

**Player light.** OmniLight3D on the player, range 6 m by default, 12 m when `GameState.has_flag(&"has_lantern")`, colour ember. Only enabled in FOG and in caves so the day scene isn't affected.

**Horn.** `horn_sounded` is emitted on every fog start except inside dungeons. J18 shows the text; here, print it.

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

- J12 calls `WorldState.on_zone_entered(zone)` after placing the player.
- J17 calls `request_fog(&"FOG_1")` and friends and sets `fog_scene_active` around scripted scenes.
- J18 renders a bell indicator toward `nearest_lit_cairn` when `has_bell` is set.

## Deviations

(none yet)
