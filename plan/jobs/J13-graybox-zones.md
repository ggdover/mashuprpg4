# J13: Graybox zones

**Milestone:** M4 · **Depends on:** J12, J07, J08 · **Unblocks:** J17
**Reads first:** `design/world_act1.md` §Zones, §Connections, §Signposts; `design/quests_act1.md` (which markers each quest needs); J11, J12 job files

## Goal

The eight open-world zones of act 1 as walkable gray blockouts with navigation, spawners configured from the bestiary, exits, day and fog nodes, cairns, and named markers for every quest hook. After this job the whole act 1 map can be walked end to end.

## Deliverables

- `game/world/zones/<id>/<id>.tscn` for `tjarnas`, `lake_shore`, `fairmeadow`, `hunting_woods`, `crossroads`, `norrby`, `frost_line`, `berget_approach`, each built from `zone_base.tscn`
- `ZoneData` files updated to point at them
- Baked navigation meshes
- `game/world/interactables/pickup_node.tscn` (a box that yields an item on interact and respawns on zone reload; used for goldieflowers)
- A top-down screenshot of each zone saved to `plan/zones/<id>.png` for reference

## Conventions for all zones

- Ground is a flat plane with a few raised slabs; no terrain sculpting. Trees are 0.6 × 6 × 0.6 pillars in clusters, rocks are 1 to 3 m boxes, buildings are 4 to 8 m boxes, water is a flat blue-tinted box the player cannot enter.
- Every exit is a `zone_exit` with a label. Every entry is a Marker3D named after the exit on the other side.
- Quest markers are Marker3D nodes under a `QuestMarkers` node, named exactly as listed below so J17 can find them with `find_child`.
- Spawner item levels come from the `ZoneData`; rosters come from `game/data/enemies/`.
- Signposts and landmarks use `StateVisibility` as J11 describes.

## Zone specs

**Tjärnäs** (village, safe, item level 1, 110 × 110 m). Lake along the south edge with a shore, boats as boxes, and the horn post. Twelve houses, a longhouse, the storehouse, smithy, tannery, henhouse on the east edge, and the old lady's cottage at the north-east where the last fence meets the trees. NPC markers under `NpcMarkers`: `old_lady`, `storehouse_keeper`, `tanner`, `smith`, `fisherman`, `headman`. Exits: west to `lake_shore`, north to `fairmeadow`, east to `hunting_woods`. Quest markers: `Q01_Henhouse` (a small spawner of 5 possessed foxes activated by the quest), `Scene_FirstFog`, `Scene_Farewell` (at the last fence). No spawners otherwise.

**Lake shore** (open, item level 2, 160 × 90 m). Reeds along the water, a bluff at the west end with the `flooded_cave` entrance exit, a fishing spot. Spawners: boars neutral and possessed (2 × 4), foxes (3), ravens (4). Exit east to `tjarnas`.

**Fairmeadow** (open, item level 3, 180 × 120 m). Open meadow with scattered rocks whose north faces carry frost-tinted boxes. Twelve goldieflower `pickup_node`s spread across the meadow. At the far north end, four runestones (2 m boxes with a `Label3D` rune text) each with a spawner group of 4 possessed wolves and 6 squirrels around it, named `Rune_1` to `Rune_4` with their spawners `RuneGroup_1` to `_4`. Ambient spawners: squirrels from above along the paths, boars neutral. Exits south to `tjarnas`.

**Hunting woods** (open, item level 5, 220 × 160 m). Dense pillar forest with clearings. Boar sounder spawners (3 × 4, neutral and possessed by phase), wolves (2 packs), foxes. A crag in the north-east: a raised slab with a ramp and a raven spawner (12) and the marker `Boss_GreatRaven`. A distinct "path home" corridor from the west clearing toward the Tjärnäs exit with markers `Q04_FogTrigger` (an Area3D trigger) and `Q04_WolfSpawn` and `Scene_Vittror1` (a clearing with six spirit-light marker positions). Exits west to `tjarnas`, north to `crossroads`.

**Crossroads and north shore** (open, item level 7, 260 × 140 m). A signpost cluster at the crossroads: day signs Sjön and Berget, fog signs Norr, Skogen, Ingen väg and Frost, placed as J11 describes. The crossroads cairn `Cairn_Crossroads` with marker `Q06_HerdArea` and a spawner group `Q06_Wolves` (activated by the quest, 15 wolves in waves of 5). A shore path north with six cairns `Cairn_1` to `Cairn_6`, each with a spawner group `CairnGroup_1` to `_6` (possessed wolves and foxes; groups 3 and 5 include an elite bear). A fog-only path of boxes leading to a dead end labelled Ingen väg. Exits south to `hunting_woods`, north to `norrby`.

**Norrby** (village, semi-safe, item level 9, 80 × 80 m). Five houses, a well, a small shore. NPC markers `norrby_headwoman`, `norrby_villager_1`, `norrby_villager_2`. The outskirts to the east hold `Boss_TheOldOne` on a slab with a ring of rocks. Villages are safe, so the boss area is a separate spawner region outside the safe volume. Exits south to `crossroads`, north to `frost_line`.

**Frost line** (open, item level 12, 200 × 140 m). Ground patches tinted frost, dead pillar trees, no neutral spawners at all. Possessed wolves, bears, ravens, foxes, and lost villagers in fog. The `wolf_den` entrance exit in a rock face to the north-east. Marker `Scene_Vittror3` outside the den entrance. Exits south to `norrby`, north to `berget_approach`.

**Berget approach** (open, item level 15, 180 × 200 m). A climbing path with switchbacks up to the cave mouth. Raven spawners along the cliffs totalling 20 with the marker `Q12_RavenArea`. The cave mouth: a large opening in a rock wall with a `SunlightZone` (from J09) covering the apron in front of it and a `CaveVolume` Area3D just inside where the troll takes reduced damage. Marker `Boss_Troll` inside the cave volume, `Q13_DawnTrigger` at the top of the path, and the `zone_exit` into the cave labelled "Berget" that stays disabled until `act1_troll_dead` (J17 enables it). Exits south to `frost_line`.

## Acceptance criteria

- [ ] All eight zones load from the main scene through the debug zone list and through their exits
- [ ] Navigation works everywhere the player can walk; enemies path around buildings and rocks
- [ ] Every marker named above exists with that exact name
- [ ] Spawners spawn the right rosters and switch correctly when fog is forced
- [ ] The full route Tjärnäs → Hunting woods → Crossroads → Norrby → Frost line → Berget approach can be walked without getting stuck
- [ ] Screenshots saved, editor loads clean

## Out of scope

Dungeons (J14), quest logic (J17), NPC scenes (J16, markers only here).

## Deviations

(none yet)
