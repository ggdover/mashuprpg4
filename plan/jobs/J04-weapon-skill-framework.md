# J04: Weapon and skill framework (sword and bow)

**Milestone:** M2 · **Depends on:** J02, J03 · **Unblocks:** J05, J07
**Reads first:** `design/gdd.md` §Controls, §Combat, §Weapons and skills; J02 and J03 job files for the hooks they expose

## Goal

A data-driven weapon and skill system: equip a weapon, get its basic attack and three skills on LMB, RMB, 1 and 2, with cooldowns, resource costs, level gating, attack-while-moving slowdown, melee arcs and projectiles. Prove it with one melee weapon (sword) and one ranged weapon (bow).

## Deliverables

- `game/weapons/weapon_data.gd` (`class_name WeaponData`, `Resource`)
- `game/skills/skill_data.gd` (`class_name SkillData`, `Resource`)
- `game/skills/skill_executor.gd` (`class_name SkillExecutor`, Node on the player)
- `game/combat/projectiles/projectile.tscn` and `projectile.gd`
- `game/combat/melee_hitbox.tscn` (arc-capable Hitbox)
- `game/data/weapons/sword.tres`, `bow.tres` and `game/data/skills/sword/*.tres`, `bow/*.tres`
- `Player.equip_weapon(weapon: WeaponData)` and `Player.level: int` (debug-settable until J10)
- `game/test/test_weapons.tscn`
- GUT tests in `game/test/unit/test_skills.gd`

## Spec

**WeaponData.** `id`, `display_name`, `type` enum SWORD, AXE, MACE, BOW, CROSSBOW, STAFF, `base_damage_min/max`, `attack_time` (seconds for the basic attack), `resource` enum STAMINA, MANA, `basic: SkillData`, `skills: Array[SkillData]` of size 3, `placeholder_size: Vector3` for the box attached to the player's nose.

**SkillData.** `id`, `display_name`, `unlock_level` (1, 4 or 8), `cost`, `cooldown`, `duration` (how long the skill occupies the actor), `movement_multiplier` (default 0.6), `damage_multiplier`, `frost_share` (0 to 1 of damage dealt as frost), `shape` enum ARC, BOX, PROJECTILE, SELF, DASH, `arc_angle`, `range`, `box_size`, `projectile_scene`, `projectile_speed`, `projectile_count`, `spread_angle`, `pierce`, `charge_max_time` (0 = no charge), `charge_max_multiplier`, `dash_distance`, `effects_on_hit: Array[StatusEffectData]`, `effect_chance`, `self_effect: StatusEffectData`, `knockback`, `combo: Array[SkillData]` for follow-up steps, `combo_window` (0.4 s).

**SkillExecutor.** Holds the equipped weapon and four slots. On input: checks `can_act`, `unlock_level <= player.level`, cooldown ready, `ResourcePool.try_spend(cost)`. On fire: snapshot `aim_dir`, set `player.movement_multiplier = skill.movement_multiplier` for `duration`, then resolve by shape. ARC: activate a `MeleeHitbox` in front of the player for 0.15 s that only accepts hurtboxes within `arc_angle` of the snapshot direction and within `range`. BOX: same with a box. PROJECTILE: spawn `projectile_count` projectiles fanned over `spread_angle`. SELF: apply `self_effect`. DASH: move the player `dash_distance` along the snapshot direction over `duration` with collision. Combos: if `combo` is non-empty, a repeated press within `combo_window` after the step ends fires the next step; otherwise reset. Charge: while the input is held up to `charge_max_time`, release fires with a damage multiplier lerped to `charge_max_multiplier`; at full charge set `pierce` to 99. Emits `skill_fired(slot)`, `cooldown_changed(slot, remaining, total)`, `combo_step(step)`.

**Damage packets.** Built with `DamageInfo.from_stats(player_stats, weapon roll × damage_multiplier, ...)` and split by `frost_share`. Apply `effects_on_hit` with `effect_chance`.

**Projectile.** Area3D on layer 8 moving along its forward at `speed`, lifetime 3 s, ignores its owner, hits hostile hurtboxes, decrements `pierce` per hit, frees when it hits world (layer 1). `homing_strength` field for J05.

**Sword data.** Basic: three ARC steps of 90° and 2.2 m, multipliers 1.0, 1.0, 1.4, each 0.3 s, movement 0.6. Lunge: DASH 4 m over 0.2 s then an ARC 60° hit at 1.6 multiplier, cost 20, cooldown 5. Whirl: two ARC 360° hits over 0.6 s, 0.8 each, cost 25, cooldown 7. Parry: SELF, 0.5 s window registering a `Health.interceptor` that cancels the next hit and applies stun to the attacker, cost 10, cooldown 6.

**Bow data.** Basic: PROJECTILE, charge up to 1.0 s, multiplier 1.0 to 2.0, speed 30. Multishot: 3 projectiles over 30°, 0.7 each, cost 15, cooldown 4. Piercing Shot: pierce 99, 1.5 multiplier, cost 20, cooldown 6. Kite: DASH 3 m backwards (opposite of aim) then an instant arrow, cost 15, cooldown 5.

**Test scene.** Player, dummies from J03, `debug_cycle_weapon` cycles sword and bow, keys set `player.level` to 1, 4, 8. Overlay shows the four slots with cooldown and lock state.

**Tests.** Cooldown gating, resource gating, unlock gating, combo advances then resets, arc angle test with a fake hurtbox at 30° and 120°.

## Acceptance criteria

- [ ] Sword three-hit combo chains on repeated clicks and resets after the window
- [ ] Attacking slows movement to 60% for exactly the skill duration
- [ ] Skills fire toward the mouse regardless of movement direction
- [ ] Locked skills show as locked at level 1 and unlock at 4 and 8
- [ ] Bow arrows pierce only at full charge, Multishot fans three, Piercing Shot passes through all dummies in a line
- [ ] Parry cancels one hit inside its window and stuns the attacker's dummy
- [ ] GUT tests pass, editor loads clean

## Out of scope

Axe, mace, crossbow, staff (J05). Enemies. HUD.

## Notes for later jobs

- J07 enemies reuse `SkillExecutor` in a reduced form for their attacks, or at least `MeleeHitbox` and `Projectile`.
- J18 binds the HUD skill bar to `cooldown_changed`.

## Deviations

(none yet)
