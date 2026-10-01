# J07: Enemy framework and AI

**Milestone:** M2 · **Depends on:** J03, J04 · **Unblocks:** J08, J13
**Reads first:** `design/gdd.md` §Enemies, §World (spawn rules), §Placeholder policy; J03 and J04 job files; J06 job file §LootDropper (call it if merged, stub it if not)

## Goal

A data-driven enemy: one base scene that reads an `EnemyData` resource and behaves as a neutral animal or a possessed creature, navigates, detects, attacks with the same hitboxes and projectiles the player uses, dies, drops loot and grants XP. Plus a spawner that honours day, fog and dungeon rules and applies elite modifiers.

## Deliverables

- `game/enemies/enemy_data.gd` (`class_name EnemyData`, `Resource`)
- `game/enemies/enemy_base.tscn` and `enemy_base.gd` (`class_name Enemy`, `CharacterBody3D`)
- `game/enemies/ai/` state machine: `ai_state_machine.gd` and one script per state
- `game/enemies/enemy_attacker.gd`: a reduced `SkillExecutor` for enemies
- `game/enemies/elite_modifier.gd` and `game/data/elites/rimed.tres`, `hulking.tres`, `swift.tres`, `pack_leader.tres`
- `game/world/spawner.tscn` and `spawner.gd` (`class_name Spawner`)
- `game/data/enemies/test_dummy_neutral.tres`, `test_dummy_possessed.tres` (J08 authors the real roster)
- `game/test/test_enemies.tscn`
- GUT tests in `game/test/unit/test_ai.gd`
- New `EventBus` signals: `xp_gained(amount: int)`, `enemy_spawned(enemy)`

## Spec

**EnemyData.** `id`, `display_name`, `animal` enum BOAR, WOLF, BEAR, RAVEN, SQUIRREL, FOX, HUMAN, TROLL, `category` enum NEUTRAL, POSSESSED, `size_class`, `base_stats: Dictionary` (the StatBlock keys), `detection_radius` (0 for neutral), `alert_radius` (ravens), `attack: SkillData`, `attack_range`, `attack_cooldown`, `keep_distance` (ranged enemies hold this range), `flies: bool` (ignores the nav mesh, hovers at 2 m), `flee_from_fog: bool`, `xp`, `item_level`, `loot_table: LootTable`, `contexts` flags DAY, FOG, DUNGEON, `frost_share` (possessed 0.3), `leash_distance` 30.

**Enemy scene.** Layer 3, mask 1 and 2. Children: `Health`, `StatusEffectManager`, `Hurtbox` (layer 5), `NavigationAgent3D`, `EnemyAttacker`, `AIStateMachine`, graybox `box_actor` with a `Label3D` name above. On ready: duplicate the StatBlock from `base_stats`, set faction ENEMY for possessed and NEUTRAL_ANIMAL for neutral, apply material (gray for neutral, frost for possessed).

**States.** `Idle` (wander within 6 m of spawn every 2 to 5 s), `Chase` (nav to target, repath every 0.3 s; fliers move straight), `Attack` (face target, fire `attack` through `EnemyAttacker`, wait `attack_cooldown`), `Flee` (move away from the fog source or the player for neutral animals; despawn when 40 m from the player), `Return` (walk back to spawn when leashed, heal to full), `Dead`. Transitions: possessed enter `Chase` when the player is within `detection_radius` and a raycast on layer 1 from eye height reaches the player; neutral enter `Chase` only after taking damage from the player; both go to `Attack` within `attack_range`, back to `Chase` outside it, to `Return` past `leash_distance`, to `Dead` on `Health.died`. Ravens that detect the player call `alert(radius)` on every enemy within `alert_radius`, which puts possessed ones into `Chase`. When `WorldState` changes to FOG, every enemy with `flee_from_fog` goes to `Flee`.

**Attacks.** `EnemyAttacker` runs a `SkillData` the same way J04 does but without input, cooldown slots, or resources. Melee arcs use `MeleeHitbox` on layer 7; projectiles use `Projectile` with the enemy faction. Damage packets are built from the enemy's StatBlock with `frost_share`. Windup: 0.4 s before the hit during which the box's nose tints highlight, so the player can read it.

**Death.** Stop movement, disable hurtbox, shrink tween 0.4 s, call `LootDropper.drop(loot_table, item_level, position)`, emit `EventBus.xp_gained(xp)` and `EventBus.enemy_died(self)`, free after 1 s. `Enemy` exposes `data`, `zone_id`, `is_elite` for quest counting.

**Elite modifiers.** An `ElitePreset` resource: `id`, `name_suffix`, `stat_modifiers`, `scale`, `aura: StatusEffectData` applied to the player within `aura_radius` (rimed applies slow), `buff_allies: StatusEffectData` within 8 m (pack leader). Applied at spawn with a 15% chance for possessed only. Rimed: frost aura 4 m, +20% health. Hulking: scale 1.5, +100% health, -20% speed. Swift: +40% move and attack speed, -20% health. Pack leader: allies +15% damage.

**Spawner.** `@export var roster: Array[EnemyData]` split by category at runtime, `count`, `radius`, `respawn_seconds`, `active_contexts`. On zone ready and on `world_state_changed`: compute the wanted population. DAY: `count` enemies, of which the possessed share is 0.2, 0.5 or 0.8 by `GameState.phase`. FOG: `count` possessed only, humans allowed if the roster has them. DUNGEON: possessed only, always. Neutral enemies flee and despawn when fog starts; the spawner then fills with possessed. Don't spawn within 15 m of the player. Respawn dead enemies after `respawn_seconds` while the player is in the zone and further than 25 m from the spawner.

**Test scene.** Arena, player, three spawners with the two test dummies, a key toggling `WorldState` DAY and FOG, a key setting `GameState.phase`. Shows neutral animals ignoring the player until hit, possessed charging on sight, ravens alerting, neutral fleeing at fog start.

**Tests.** Detection needs both radius and line of sight, neutral doesn't chase until damaged, leash returns, spawner population math per phase and state.

## Acceptance criteria

- [ ] A neutral dummy ignores the player, retaliates when hit, and flees when fog starts
- [ ] A possessed dummy chases on detection, attacks with a readable windup, and leashes past 30 m
- [ ] Death drops loot (or logs the roll if J06 isn't merged) and emits `enemy_died` and `xp_gained`
- [ ] Spawner respects the possessed share per phase in DAY and spawns only possessed in FOG
- [ ] About 15% of possessed spawns are elites with visible scale or tint and a name suffix
- [ ] GUT tests pass, editor loads clean

## Out of scope

Real animals and stats (J08), bosses (J09), zones (J12, J13).

## Notes for later jobs

- J08 fills `EnemyData` for every animal and adds animal-specific states (charge, lure, swoop) as extra state scripts.
- J09 subclasses `Enemy` for bosses.
- J15 counts kills by listening to `enemy_died` and reading `enemy.data.id`, `animal`, `category`, and `zone_id`.

## Deviations

(none yet)
