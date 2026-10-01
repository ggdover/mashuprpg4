# J08: Act 1 bestiary

**Milestone:** M2 · **Depends on:** J07 · **Unblocks:** J09, J13, J14
**Reads first:** `design/gdd.md` §Enemies; `design/world_act1.md` §The frost and the possessed; J07 job file

## Goal

Every act 1 enemy as data and behaviour: six animals in neutral and possessed variants, two possessed humans, with the behaviours that make them read differently in a fight.

## Deliverables

- `game/data/enemies/<animal>_neutral.tres` and `<animal>_possessed.tres` for boar, wolf, bear, raven, squirrel, fox
- `game/data/enemies/lost_villager.tres`, `lost_hunter.tres`
- `game/data/skills/enemies/*.tres` for every enemy attack
- Extra AI states under `game/enemies/ai/`: `charge.gd`, `circle.gd`, `swoop.gd`, `drop_in.gd`, `lure.gd`, `hold_range.gd`
- `game/test/test_zoo.tscn`: one spawner per enemy type with labels
- The stat table at the bottom of this file filled in

## Spec

**Scaling.** All base stats are for item level 1. Spawners pass the zone's item level; `Enemy` multiplies health and damage by `1 + 0.12 * (item_level - 1)`. XP scales the same way.

**Boar.** MEDIUM. Neutral: wanders in groups of 3 to 5 (spawner `count` 4), only retaliates. Possessed: `charge.gd` state: when 6 to 12 m from the target, 0.6 s windup facing it, then a straight dash at 14 m/s for 8 m with a BOX hitbox, knockback 5, then 1 s recovery. Basic attack otherwise a short ARC gore. Health 60, damage 8, xp 10.

**Wolf.** MEDIUM. Always in packs of 3 to 5. `circle.gd`: pack members pick offset targets around the player at 4 m (evenly spaced angles), and only one lunges at a time (a shared token on the pack, released after the attack). Lunge: DASH 3 m plus ARC bite, bleed 20%. Neutral wolves keep distance from the player and only engage if attacked. Health 45, damage 7, speed 7, xp 12.

**Bear.** LARGE. Slow, heavy. ARC swipe 2.5 m with knockback 3, and a slam every third attack: SELF with aoe_radius 2.5 and stun 1 s. Neutral bears retaliate hard and don't leash easily (leash 45 m). Health 200, damage 18, speed 4.5, xp 40. Elite candidates in the cairn path.

**Raven.** SMALL, `flies`. Hovers at 3 m and circles. `swoop.gd`: every 3 s dives through the player with a small BOX hitbox for 5 damage and climbs back. Detection 20 m and alerts within 15 m as in J07. Neutral ravens just fly away when approached. Health 20, xp 6. Possessed only in practice, but keep the neutral variant for daytime ambience.

**Squirrel.** SMALL, fast, low health, comes in 6 to 10. `drop_in.gd`: spawn hidden 6 m up above the player's path (spawner flag `spawn_from_above`), fall in over 0.3 s when the player passes underneath, then swarm with tiny ARC bites at 2 per second. Health 10, damage 3, speed 8, xp 3. Neutral squirrels are decorative and flee.

**Fox.** SMALL, quick. Possessed: `lure.gd`: when it detects the player it moves away to keep 8 m, stopping to look back, for up to 15 s or 40 m, drawing the player off the path, then turns and attacks with hit-and-run (bite, retreat 5 m, repeat). In fog this is the enemy that gets you lost. Neutral foxes flee. Health 30, damage 6, speed 8, xp 8.

**Lost villager.** MEDIUM, HUMAN, POSSESSED, contexts FOG and DUNGEON only. Melee with an axe ARC 100°, slow 0.7 s attacks, 20% frostbite. Health 90, damage 12, speed 5, xp 20. Label reads "lost villager", no name.

**Lost hunter.** MEDIUM, HUMAN, POSSESSED, FOG and DUNGEON only. `hold_range.gd`: keeps 8 m from the player, fires a bow projectile every 1.5 s, retreats when the player closes within 4 m. Health 70, damage 10, speed 5.5, xp 22.

**Possessed frost.** Every possessed attack has `frost_share` 0.3. Possessed placeholders use the frost material and the label suffix from J07.

**Spawn contexts.** Neutral variants: DAY only. Possessed animals: DAY, FOG, DUNGEON. Humans: FOG, DUNGEON.

**Test scene.** A zoo of spawners, one per data file, each in its own pen with a label, plus a fog toggle. Used to tune feel: every enemy should be recognisable by movement alone in gray boxes.

## Acceptance criteria

- [ ] All 14 data files load and spawn through the J07 spawner
- [ ] Boar charge, wolf circling with one lunge at a time, raven swoop, squirrel drop-in, fox lure and hunter range-holding are all visibly different
- [ ] Neutral variants never spawn in FOG or DUNGEON contexts; humans never spawn in DAY
- [ ] Item level scaling raises health and damage by the formula
- [ ] Editor loads clean

## Out of scope

Bosses (J09). Zone placement (J13).

## Stat table

Fill in when tuned: enemy, health, damage, speed, detection, xp, notes.

## Deviations

(none yet)
