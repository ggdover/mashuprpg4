# Quests: act 1

Every quest is one of three types: **kill** (N mobs of a type in a zone), **boss** (kill a named enemy), **fetch** (reach a zone, find or collect N items, bring them to an NPC). Story beats attach to turn-ins and to scripted scenes triggered by completion. Numbers are starting values for tuning.

Flags set by quests are listed so the world state and dialogue can react to them.

## Main quests

| Id | Name | Phase | Type | Objective | Zone | Turn-in | Story beat at completion | Rewards | Sets flags / triggers |
|----|------|-------|------|-----------|------|---------|--------------------------|---------|-----------------------|
| Q01 | Foxes at the henhouse | 1 | kill | Kill 5 possessed foxes at the village edge | Tjärnäs edge | Fisherman | Villagers call them oknytt and blame the fog | XP, silver | `q01_done` |
| Q02 | Goldieflowers for the old lady | 1 | fetch | Collect 10 goldieflowers | Fairmeadow | Old lady | Her ritual shows white, and something walking under it. Player notices frost on the north face of the stones | XP, 2 brew | `q02_done`, unlocks old lady dialogue tier 1 |
| Q03 | The roost | 1 | boss | Kill 12 possessed ravens and the Great Raven | Hunting woods crag | Fisherman | The fog has been watching since the ravens came | XP, guaranteed fine item | `q03_done` |
| Q04 | Boar meat for the store | 1 | kill, then scripted | Kill 8 boars, then on the path home: fog, kill the wolf pack and the Alpha Wolf | Hunting woods, forest path | Storehouse keeper | First conversation with the vittror: bells, voices, a plea for help | XP, rare item, silver | On 8 boars: `FOG_1` when the player enters the path home. On Alpha dead: scene `vittror_1`, then `phase_2` |
| Q05 | The runes in Fairmeadow | 2 | fetch | Clear the packs at the four runestones and take 4 rubbings | Fairmeadow far end | Old lady | The founders' pact with those below; the cold has walked south once before | XP, silver | `q05_done` |
| Q06 | Bells in the fog | 2 | kill | Go to the crossroads cairn; in fog, kill 15 possessed wolves hunting the herd | Crossroads | Auto, scene | Second conversation. Trust. The bell | XP, **the bell** | `FOG_2` on reaching the cairn; scene `vittror_2` on completion; `has_bell` |
| Q07 | The cairn path | 2 | kill | Clear the six cairn groups on the north shore path (two held by elite bears) and light each cairn | North shore | Auto | The path north is walkable in fog | XP, fine item | `cairns_lit`, unlocks Norrby travel |
| Q08 | The Old One of Berget | 2 | boss, then fetch | Reach Norrby, kill The Old One, loot the unmelting shard, bring it to the old lady | Norrby outskirts | Old lady | This cold isn't from here. Norrby mentions something big in the cave | XP, rare item | `q08_done`, Norrby dialogue tier 2 |
| Q09 | The wolf den | 2 | boss (dungeon) | Clear the Wolf den and kill the Pack Mother | Frost line | Auto, scene | Third conversation on exiting into fog: the cold followed them, it takes what dies in it, their road runs under Berget | XP, rare item | `FOG_3` on exit; scene `vittror_3`; `phase_3` |
| Q10 | Pelts for the north | 3 | kill, then fetch | Kill 6 neutral wolves and 2 neutral bears, bring the hides to the tanner. Possessed hides are ruined | Any open zone | Tanner | The village helps with the coat while mocking the reason | **Winter coat** (chest, frost resistance) | `coat_done` |
| Q11 | The lantern | 3 | boss (dungeon), then fetch | Clear the Flooded cave, kill The Sleeper, find the old lady's lantern, bring it back | Flooded cave | Old lady | She refits it and hands it over | **The lantern** (light radius in fog and caves) | `lantern_done`, `has_lantern` |
| Q12 | The watchers on the cliffs | 3 | kill | Kill 20 possessed ravens on the approach to Berget | Berget approach | Auto | The fog stops seeing you come | XP, silver | `q12_done`, unlocks Q13 |
| Q13 | Berget's mouth | 3 | boss | Kill the Troll at the cave mouth at dawn by dragging it into sunlight | Berget approach | Auto | Farewell scene the night before at the last fence. Enter the cave. End of act 1 | XP, legendary item | Scene `farewell` before start; `act1_troll_dead` when the troll dies (enables the cave exit); `act1_complete` on entering the cave |

Q10 and Q11 can be done in either order. Q12 requires both.

## Repeatable hunts

| Id | Name | Type | Objective | Turn-in | Reward |
|----|------|------|-----------|---------|--------|
| R1 | Boar meat for the storehouse | kill | 8 boars, bring the meat | Storehouse keeper | Silver, XP |
| R2 | Wolf pelts for the tanner | kill | 6 wolves, bring the pelts | Tanner | Silver, XP |
| R3 | Foxes at the henhouse | kill | 5 possessed foxes | Fisherman | Silver, XP |

Repeatables are available from phase 1 and reset on turn-in. They are the "routine mission" that fog can interrupt.

## Bosses

| Boss | Base | Zone | Quest | Mechanic |
|------|------|------|-------|----------|
| Great Raven | raven, boss size | Hunting woods crag | Q03 | Dives, summons 3 ravens at 50% health |
| Alpha Wolf | wolf, boss size | Forest path, fog | Q04 | Pack of 4, howl buffs pack speed, lunges |
| The Old One | bear, boss size | Norrby outskirts | Q08 | Charge, ground slam, rimed aura |
| Pack Mother | wolf, boss size | Wolf den | Q09 | Summons pups, retreats to heal once |
| The Sleeper | bear, boss size | Flooded cave | Q11 | Starts asleep, wakes on damage, enrages at 30% |
| The Troll | troll, 4 m | Berget cave mouth | Q13 | Immune inside the cave; petrifies for 4 s when standing in sunlight at the mouth, taking triple damage |

## Scripted scenes

| Scene | Trigger | Content |
|-------|---------|---------|
| `first_fog_village` | After Q01 turn-in, next time the player is in Tjärnäs | Horn, villagers go inside, no danger. Teaches the custom |
| `vittror_1` | Alpha Wolf dead in Q04 | Bells, then voices. Text and spirit-light markers. Plea for help |
| `vittror_2` | Q06 complete | Trust. The bell is given |
| `vittror_3` | Exiting the Wolf den after Q09 | The cold followed them. The road under Berget. Something in the cave |
| `farewell` | Accepting Q13 | Night, the last fence, the lantern. The headman doesn't come |

## Flags used elsewhere

`phase_2` and `phase_3` change the possessed spawn ratio and the fog-on-zone-entry probability. `cairns_lit` unlocks fast travel between lit cairns if that feature is built. `has_bell` enables the cairn indicator in fog. `has_lantern` widens the player's light in fog and caves. `act1_troll_dead` enables the cave exit at Berget's mouth. `act1_complete` ends the graybox build.
