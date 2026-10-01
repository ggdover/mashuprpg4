# J14: Dungeons, the wolf den and the flooded cave

**Milestone:** M4 · **Depends on:** J12, J08 · **Unblocks:** J17
**Reads first:** `design/world_act1.md` §Zones (dungeon rows); `design/quests_act1.md` Q09 and Q11; `design/gdd.md` §Enemies (dungeon rule); J11 (cave preset), J12, J13 job files

## Goal

Two cave dungeons as enclosed gray blockouts with the cave environment, possessed-only spawners that include lost villagers and hunters, a boss room each, a loot chest, and the quest pickups they carry.

## Deliverables

- `game/world/dungeon_base.tscn` extending `zone_base.tscn` with `force_cave`, a `Rooms` node, `BossRoom`, and a `Chest`
- `game/world/interactables/chest.tscn`: opens once per `zone_state`, rolls the boss loot table
- `game/world/dungeons/wolf_den/wolf_den.tscn`
- `game/world/dungeons/flooded_cave/flooded_cave.tscn`
- `game/world/interactables/shallow_water.tscn`: an Area3D applying slow -20% while inside
- `ZoneData` for both updated to the scenes

## Spec

**Dungeon base.** Walls are boxes to full height so the camera never sees outside. Ceiling is not needed with the fixed camera; instead a dark `ColorRect` vignette is not used either, the cave environment handles darkness. Every spawner is set to context DUNGEON. `EnvironmentController.force_cave = true`. The player's light matters here (J11). Entry marker at the mouth, one exit back to the parent zone.

**Wolf den** (item level 12). Four rooms joined by narrow passes: entry cave (4 possessed wolves, 2 lost villagers), the nursery (8 squirrels from above, 3 wolves), a long twisting pass with two lost hunters on ledges the player can't reach directly and 4 foxes that lure, and the lair: `Boss_PackMother` on a raised slab with three pup spawn points named `PupSpawn_1` to `_3`. The chest is behind the lair. The exit is back at the entry. Marker `Exit_Vittror3` on the outside of the den mouth is placed in `frost_line` by J13; the den only needs to emit `zone_entered` on exit like any zone.

**Flooded cave** (item level 14). Entered from the bluff on the lake shore. Three chambers: a wet entry with shallow water boxes (slow area) and 4 lost hunters on dry ledges, a flooded hall where the path zigzags between water pools with 6 possessed foxes and 6 ravens, and the deep chamber with `Boss_TheSleeper` asleep in the middle and, behind it, the marker `Pickup_Lantern` where J17 places the old lady's lantern as a pickup. Chest beside the lantern.

**Chest.** A box that opens on interact, once, rolling the boss loot table at the dungeon's item level and dropping the items on the ground. Records itself in `GameState.zone_state[zone].chests_opened`.

## Acceptance criteria

- [ ] Both dungeons load from their parent zones and return to them at the right entry
- [ ] Only possessed enemies spawn, including humans, regardless of world state
- [ ] The cave preset is applied and the player's light is the main light source
- [ ] Shallow water slows the player and is removed on leaving
- [ ] Boss markers and the lantern marker exist with the exact names
- [ ] The chest opens once and stays open on re-entry
- [ ] Editor loads clean

## Out of scope

Boss behaviour (J09), quest hooks (J17).

## Deviations

(none yet)
