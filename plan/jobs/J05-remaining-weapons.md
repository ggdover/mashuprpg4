# J05: Remaining weapons and skill sets

**Milestone:** M2 · **Depends on:** J04 · **Unblocks:** J17
**Reads first:** `design/gdd.md` §Weapons and skills; J04 job file (data model)

## Goal

Add axe, mace, crossbow and staff with their basic attacks and three skills each, adding only the mechanics J04's model can't express. After this, all six weapon types and 24 skills exist as data.

## Deliverables

- `game/data/weapons/axe.tres`, `mace.tres`, `crossbow.tres`, `staff.tres`
- `game/data/skills/axe/*.tres`, `mace/*.tres`, `crossbow/*.tres`, `staff/*.tres`
- Extensions to `SkillData` / `SkillExecutor` / `Projectile` listed below
- `game/test/test_weapons.tscn` cycling all six weapons
- A balance table at the bottom of this file, filled in with the numbers used

## Spec

**New mechanics.**

- `SkillData.returning: bool`: a projectile that flies to `range` then returns to the owner, hitting on both legs (axe Throw).
- `SkillData.aoe_radius`: for ARC or SELF shapes, also hit everything within the radius around the impact or the player (mace basic, Ground Slam, Flare).
- `SkillData.reload_time`: after the basic attack, the weapon cannot fire the basic again until it elapses; other skills are allowed (crossbow).
- `SkillData.burst_count` and `burst_interval`: fire the projectile `burst_count` times (Volley).
- `Projectile.homing_strength`: steer toward the nearest hostile hurtbox within 6 m at this rate (staff basic).
- `SkillData.shield_amount`: SELF skill calling `Health.add_shield(amount, duration)` (Ward).
- Mana pool used when `WeaponData.resource == MANA`; the HUD later shows mana instead of stamina for the staff.

**Axe.** Basic: ARC 120°, 2.4 m, 0.5 s, multiplier 1.3, 25% bleed. Cleave: ARC 180°, 1.8 multiplier, knockback 4, cost 25, cooldown 6. Throw: returning projectile, pierce 99, speed 20, range 10 m, 1.2 multiplier per leg, cost 20, cooldown 8. Rage: SELF, 6 s, attack_speed +30%, armor -30%, cost 30, cooldown 15.

**Mace.** Basic: ARC 70°, 2.0 m, 0.55 s, multiplier 1.4, aoe_radius 1.2, 20% stun. Ground Slam: SELF with aoe_radius 3, 1.6 multiplier, applies stun 1.0 s to all hit, cost 30, cooldown 9. Guard Break: ARC 45°, 1.0 multiplier, applies armor_break, cost 15, cooldown 6. Bulwark: SELF, 4 s, damage taken -50% (implement as a temporary `armor` and `frost_resistance` +200 flat, or an interceptor halving damage), move_speed -40%, cost 25, cooldown 14.

**Crossbow.** Basic: PROJECTILE, speed 40, multiplier 1.8, reload_time 0.8. Volley: burst_count 3, burst_interval 0.15, 0.9 each, cost 20, cooldown 6. Net Bolt: projectile applying root 2 s, 0.6 multiplier, cost 15, cooldown 8. Barbed Bolt: 1.2 multiplier with a bleed twice as strong as the base status (make `bleed_heavy.tres`), cost 20, cooldown 7.

**Staff.** Basic (Ember spark): PROJECTILE, speed 14, homing 3, multiplier 0.7, cost 0. Firebrand: projectile, aoe_radius 1.5 on impact, applies burn, 1.3 multiplier, cost 20 mana, cooldown 4. Ward: SELF, shield_amount = 40% of max health, 3 s, cost 30 mana, cooldown 12. Flare: SELF, aoe_radius 4, stun 1.5 s, knockback 5, 0.5 multiplier, cost 35 mana, cooldown 14.

**Placeholder boxes.** Weapon box sizes: sword 0.1 × 0.1 × 0.9, axe 0.25 × 0.1 × 0.7, mace 0.25 × 0.25 × 0.7, bow 0.05 × 1.2 × 0.1, crossbow 0.6 × 0.1 × 0.5, staff 0.08 × 1.6 × 0.08.

## Acceptance criteria

- [ ] All six weapons cycle in the test scene and every one of the 24 skills does something visible
- [ ] Axe Throw returns and hits on the way back
- [ ] Crossbow basic is blocked during reload but Volley is not
- [ ] Staff basic homes toward the nearest dummy and consumes no resource; Ward absorbs before health
- [ ] Mana is used by the staff and stamina by everything else
- [ ] Editor loads clean

## Out of scope

Balance beyond "feels usable". Enemies. HUD.

## Balance table

Fill in when done: weapon, basic DPS against a 0-armor dummy, skill damage per cast, resource per second.

## Deviations

(none yet)
