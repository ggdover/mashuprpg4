# J03: Stats, health and damage pipeline

**Milestone:** M2 · **Depends on:** J01 · **Unblocks:** J04, J06, J07, J10, J20
**Reads first:** `design/gdd.md` §Combat; `plan/README.md` §Conventions

## Goal

Everything that can be hurt shares one pipeline: a stat block with modifiers, a health node, hitboxes and hurtboxes, a damage packet, resource pools, and status effects. Player and enemies both use it unchanged.

## Deliverables

- `game/combat/stat_block.gd` (`class_name StatBlock`, `Resource`)
- `game/combat/damage_info.gd` (`class_name DamageInfo`, `RefCounted`)
- `game/combat/health.gd` (`class_name Health`, Node)
- `game/combat/resource_pool.gd` (`class_name ResourcePool`, Node) for stamina and mana
- `game/combat/hurtbox.gd` and `hitbox.gd` (`Area3D` subclasses)
- `game/combat/status/status_effect_data.gd` (`Resource`) and `status_effect_manager.gd` (Node), plus `.tres` for bleed, slow, stun, root, armor_break, frostbite, burn under `game/data/status/`
- `game/combat/faction.gd` with `enum Faction { PLAYER, ENEMY, NEUTRAL_ANIMAL }`
- `game/test/test_combat.tscn` with dummies and a damage tester
- GUT tests in `game/test/unit/test_stat_block.gd`, `test_damage.gd`, `test_status.gd`

## Spec

**StatBlock.** Keys as `StringName`: `max_health, max_stamina, max_mana, armor, physical_bonus, frost_resistance, crit_chance, crit_multiplier, move_speed, attack_speed`. `base: Dictionary`. Modifiers are stored per source: `add_modifier(source: StringName, stat: StringName, flat: float, percent: float)`, `remove_source(source)`. `get_stat(stat) = (base + sum flat) * (1 + sum percent)`. Emits `stats_changed`. Duplicate the resource per actor at runtime so instances don't share state.

**DamageInfo.** `physical: float`, `frost: float`, `source: Node`, `is_crit: bool`, `knockback: Vector3`, `effects: Array[StatusEffectData]`, `skill_id: StringName`. Helper `total()`.

**Health.** Reads `max_health` from the actor's StatBlock and tracks it when stats change (keep the same missing fraction). `take_damage(info)`: return early if `invulnerable`; run interceptors first (an array of Callables that can cancel or modify, used by Parry and Ward later); mitigate physical by armor and frost by frost resistance with the formulas in the gdd; apply; emit `damaged(info, final_amount)` and `health_changed(current, max)`; on zero emit `died` once. `heal(amount)`. `add_shield(amount, duration)` for a temporary absorb pool consumed before health.

**Mitigation.** `physical * 100 / (100 + armor)`, `frost * 100 / (100 + frost_resistance)`. Crit is rolled by the attacker before building the packet: `randf() < crit_chance` then multiply by `crit_multiplier`. Provide `DamageInfo.from_stats(attacker_stats, base_physical, base_frost, multiplier)` that does the roll and applies `physical_bonus`.

**Hurtbox / Hitbox.** Hurtbox is an Area3D on layer 4 or 5 by faction, with `@export var health_path` and a `faction` property. Hitbox is an Area3D on layer 6 or 7 with `mask` set to the opposite faction's hurtbox layer, a `damage_info` template, `active: bool` and `hits_once_per_activation: bool` with a set of already-hit hurtboxes cleared on activation. When active and overlapping a hurtbox of a hostile faction, it calls `hurtbox.receive(info)`. NEUTRAL_ANIMAL hurtboxes accept player hits; enemy hitboxes ignore them.

**ResourcePool.** `@export var stat_key` (max_stamina or max_mana), `current`, `try_spend(amount) -> bool`, regen rules from the gdd: stamina regenerates at 20/s after 1 s without spending, mana at 4/s always. Emits `changed(current, max)`.

**Status effects.** `StatusEffectData`: `id`, `duration`, `tick_interval`, `modifiers: Array` of `{stat, flat, percent}`, `dot_physical`, `dot_frost` per tick, `stun: bool`, `root: bool`, `stack_rule` enum REFRESH, STACK_DURATION, INDEPENDENT. `StatusEffectManager` applies effects to its actor's StatBlock under source `&"status:" + id`, ticks damage through Health, exposes `can_move` (false when stunned or rooted) and `can_act` (false when stunned), emits `effect_applied(id)` and `effect_removed(id)`. Data values: bleed 4 s, 3 physical per 0.5 s; slow 3 s, move_speed -40%; stun 1.5 s; root 2 s; armor_break 6 s, armor -50%; frostbite 4 s, move_speed -30% and 2 frost per 0.5 s; burn 3 s, 4 physical per 0.5 s.

**Debug numbers.** On `damaged`, spawn a `Label3D` above the actor with the amount, tinted by type, drifting up for 0.6 s. J20 replaces this.

**Test scene.** Three dummies (box props with StatBlock, Health, Hurtbox, StatusEffectManager, a health bar made of a scaled box). Keys spawn a hitbox in front of a marker, apply each status, heal, toggle invulnerability. Numbers and status labels visible.

**Tests.** Modifier math, source removal, armor formula at 0 and 100 armor, crit multiplier bounds, shield absorbs before health, stun blocks `can_act`, stack rules.

## Acceptance criteria

- [ ] A hitbox hits each hurtbox once per activation
- [ ] Armor and frost resistance reduce the right damage types by the formula
- [ ] Shields absorb first and expire
- [ ] All seven status effects apply, tick, expire, and remove their modifiers
- [ ] Stamina regen pauses for 1 s after spending
- [ ] All GUT tests pass, editor loads clean

## Out of scope

Weapons, skills, enemies, UI beyond debug labels.

## Notes for later jobs

- J04 uses `Health.interceptors` for Parry and `add_shield` for Ward.
- J07 gives enemies the same nodes; nothing here is player-specific.

## Deviations

(none yet)
