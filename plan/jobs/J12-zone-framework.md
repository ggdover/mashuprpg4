# J12: Zone framework, transitions and world map

**Milestone:** M4 · **Depends on:** J01, J11 · **Unblocks:** J13, J14, J19
**Reads first:** `design/world_act1.md` §Zones (table and connections); `design/gdd.md` §World; J11 job file

## Goal

Zones as data plus a base scene, a main scene that keeps the player and camera alive while zones swap under them, exits that move the player between zones, entry markers, per-zone state that persists in memory, and the act 1 world graph as data.

## Deliverables

- `game/world/zone_data.gd` (`class_name ZoneData`, `Resource`)
- `game/data/zones/*.tres`: one per act 1 zone and dungeon, ten in total, with connections
- `game/world/zone_base.tscn` and `zone.gd` (`class_name Zone`)
- `game/world/zone_exit.tscn` and `zone_exit.gd`
- `game/core/zone_manager.gd` (`ZoneManager` autoload)
- `game/main.tscn` and `main.gd`: player, camera rig, HUD layer, current zone container. Set as the project's main scene
- `game/test/zones/test_zone_a.tscn`, `test_zone_b.tscn` linked to each other
- `game/ui/menus/debug_zone_list.tscn`: a list of zones to teleport to (used by J22)

## Spec

**ZoneData.** `id`, `display_name`, `kind` enum VILLAGE, OPEN, DUNGEON, `is_safe`, `item_level`, `scene: PackedScene`, `exits: Array` of `{exit_id, target_zone_id, target_entry_id}`, `parent_zone_id` for dungeons, `default_entry_id`.

**Zone scene.** Root `Node3D` with `zone.gd`. Required children: `Ground`, `NavigationRegion3D` (baked), `Spawners`, `Exits`, `Entries` (Marker3D children named by entry id), `StateNodes` (things using StateVisibility), `EnvironmentController`. Optional: `Cairns`, `Bosses` (spawn markers with a boss id and the flag check), `Interactables`. On ready the zone reads its `ZoneData`, tells the spawners the item level and context, and applies `GameState.zone_state[id]` (lit cairns, dead bosses, opened chests).

**Exits.** `zone_exit.tscn` is an Area3D on layer 9 with `exit_id`. On player entry it asks `ZoneManager.change_zone(target_zone_id, target_entry_id)`. Show as a flat box with a `Label3D` reading the target's display name. Dungeon entrances are the same node with a different label.

**ZoneManager.** `change_zone(zone_id, entry_id)`: fade to black over 0.3 s (a `ColorRect` in the HUD layer), free the current zone, instance the new one under `Main/ZoneContainer`, place the player at the entry marker facing its forward, set `GameState.current_zone`, emit `zone_entered`, call `WorldState.on_zone_entered`, fade in. Guard against re-entry during a transition. `current_zone: Zone` accessor.

**Main scene.** `Main` holds the persistent `Player`, `CameraRig`, `HUD` CanvasLayer (empty until J18), the fade rect, and `ZoneContainer`. On start it loads the zone named in `GameState.start_zone` (default `tjarnas` once J13 exists; the test zone until then).

**Zone state.** `GameState.zone_state: Dictionary` keyed by zone id holding `{cairns_lit: Array, bosses_dead: Array, chests_opened: Array}`. Zones read it on ready and write it through helpers on `GameState`.

**World data.** Author the ten `ZoneData` files with ids: `tjarnas`, `lake_shore`, `fairmeadow`, `hunting_woods`, `crossroads`, `norrby`, `frost_line`, `berget_approach`, `wolf_den`, `flooded_cave`, with exits matching the connections in `world_act1.md`. Scenes point at the J13 and J14 scenes when they exist; until then at the test zones.

**Test.** Two small zones with an exit each way and different ground colours. Walk between them ten times without leaks (check the remote scene tree) and confirm the player keeps inventory and health across the swap.

## Acceptance criteria

- [ ] Walking into an exit moves the player to the other zone at the right entry, facing the right way, with a fade
- [ ] Player state persists across zones; the old zone is freed
- [ ] `zone_entered` fires and `WorldState.on_zone_entered` runs (fog chance applies on open zones)
- [ ] The debug zone list teleports to any zone by id
- [ ] All ten `ZoneData` files load and their exits reference existing ids
- [ ] Editor loads clean

## Out of scope

Real zone layouts (J13), dungeons (J14), saving (J19).

## Notes for later jobs

- J13 and J14 build scenes from `zone_base.tscn` and set them in the `ZoneData`.
- J19 serialises `GameState.zone_state` and `current_zone`.

## Deviations

(none yet)
