# J09: Boss framework and the six act 1 bosses

**Milestone:** M4 · **Depends on:** J07, J08 · **Unblocks:** J17
**Reads first:** `design/quests_act1.md` §Bosses; `design/gdd.md` §Enemies; J07 and J08 job files; J11 job file §Sunlight (for the troll)

## Goal

Bosses as data on top of the enemy framework: phases by health threshold, telegraphed abilities, summons, a boss health bar hook, and the six act 1 bosses with the mechanics the quest doc names, including the troll's sunlight petrification.

## Deliverables

- `game/enemies/bosses/boss_data.gd` (`class_name BossData extends EnemyData`)
- `game/enemies/bosses/boss_base.tscn` and `boss_base.gd` (`class_name Boss extends Enemy`)
- `game/enemies/bosses/telegraph.tscn`: a flat box or ring on the ground showing an ability's area during windup
- `game/enemies/bosses/abilities/` scripts for charge, slam, dive, howl, summon, retreat_heal, sleep, petrify
- `game/data/bosses/great_raven.tres`, `alpha_wolf.tres`, `the_old_one.tres`, `pack_mother.tres`, `the_sleeper.tres`, `the_troll.tres`
- `game/world/sunlight_zone.tscn` and `sunlight_zone.gd`
- `game/ui/hud/boss_bar.tscn` (minimal; J18 restyles)
- `game/test/test_bosses.tscn` with a boss selector
- New `EventBus` signals: `boss_engaged(boss)`, `boss_defeated(boss_id: StringName)`

## Spec

**BossData.** Adds `phases: Array` of `{health_fraction, abilities: Array[BossAbility]}`, `arena_radius` (the boss won't leave it and the player is pushed back at the edge while engaged, optional), `intro_text`, `loot_table` set to the boss table with `min_rarity` RARE.

**BossAbility** (Resource). `id`, `cooldown`, `windup`, `telegraph_shape` and size, `script: GDScript` implementing `execute(boss, target)`. The base ability shows the telegraph for `windup` seconds, then runs `execute`. Abilities are chosen by the boss state machine's `BossAttack` state: pick the ready ability with the highest priority for the current phase.

**Boss scene.** Extends the enemy scene with BOSS size class, a `Label3D` with the name, an emissive highlight when engaged, and the `boss_engaged` and `boss_defeated` signals. The boss bar listens and shows name and health fraction at the top of the screen. `boss_defeated` sets `GameState.set_flag(&"boss_" + id + "_dead")` so zones don't respawn it.

**Great Raven.** Boss raven, flies. Dive: 1 s windup showing a line telegraph, then a fast pass through the player for 20 damage. At 50% health, summon 3 possessed ravens once. Health 300, xp 120.

**Alpha Wolf.** Boss wolf spawned with a pack of 4. Howl every 12 s: pack gets +40% speed for 5 s (telegraph a ring). Lunge: 5 m dash bite, bleed. Health 400, xp 150.

**The Old One.** Boss bear with the rimed aura from J07 permanently. Charge: 0.8 s windup, line telegraph, 10 m dash with knockback 6. Slam: ring telegraph 3 m, 30 damage, stun 1 s. Health 900, xp 300.

**Pack Mother.** Boss wolf in the den. Summon 3 pups (possessed wolves at 50% stats) every 20 s, max 6 alive. At 40% health, once: retreats to the far end of the room and heals 25% over 4 s unless interrupted by 60 damage in that window. Health 700, xp 260.

**The Sleeper.** Boss bear that starts in `Sleep`: idle, no detection, takes double damage until first hit, then wakes with a roar (stun 0.5 s in 3 m) and fights as a bear. At 30% health enrages: +50% attack speed, +30% move speed, frost material pulses. Health 1000, xp 320.

**The Troll.** TROLL size class, 4 m box. Health 2500, damage 40, speed 3.5, xp 800. Abilities: overhead slam (ring 3 m, 60 damage), sweep (ARC 180°, knockback 8), boulder throw at range (projectile, aoe 2 m). Mechanic: the cave mouth zone contains a `SunlightZone` (Area3D) that is only active while `WorldState` is DAY. Inside the cave volume the troll takes 10% damage. When the troll has been inside the sunlight zone for a cumulative 1 s it petrifies: stunned for 4 s, takes triple damage, then recovers and walks back into the shade and won't re-enter sunlight for 8 s unless the player stands in it, which it will charge into. The fight is won by kiting it out, and the quest forces DAY at dawn (J17).

**Test scene.** Arena with a dropdown to spawn any boss at the player's level 8 gear equivalent, a key to force DAY or FOG, and a sunlight zone drawn as a bright floor box.

## Acceptance criteria

- [ ] Each boss shows telegraphs before every ability and the boss bar during the fight
- [ ] Great Raven summons once, Pack Mother retreats once and can be interrupted, The Sleeper takes double damage while asleep
- [ ] The troll takes 10% damage in the cave and triple damage while petrified in sunlight; it leaves sunlight on its own
- [ ] `boss_defeated` sets the flag and the boss does not respawn on re-entering the test scene
- [ ] Boss loot always includes at least one rare
- [ ] Editor loads clean

## Out of scope

Boss placement in zones (J13, J14) and quest hooks (J17).

## Deviations

(none yet)
