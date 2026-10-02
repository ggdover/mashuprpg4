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
- **Wiring an actor.** The actor's root script holds the stat block, takes its own copy when it becomes ready (`stats = stats.duplicate()`, or a `StatBlock.new()` whose `base` is assigned from data; assigning `base` copies the dictionary) and hands that one copy to every component: `health.stats`, `status.stats`, and `stats` of each `ResourcePool`. `Hurtbox`, `StatusEffectManager` and `DebugDamageNumbers` find the `Health` through their `health_path`. `test/combat_dummy.tscn` with `combat_dummy.gd` is the pattern. Take stat keys from the constants (`StatBlock.MAX_HEALTH` and so on): a block answers for any key, so a misspelt one reads as 0 without a word. A percent is a fraction: -0.4 is -40 %.
- **Factions.** The enum is `Factions.Faction`; the class in `faction.gd` is `Factions`. `Hurtbox.faction` and `Hitbox.faction` set layer and mask themselves, when the faction is assigned and when the node becomes ready: hurtboxes sit on layer 4 (player) or 5 (enemies and neutral animals), hitboxes on 6 or 7 and look at the other side's hurtbox layer. A script that needs another mask sets it after the node is ready. `Factions.is_hostile(attacker, target)` is the rule the hitbox asks: the player and everything else hit each other, nothing else does.
- **Hitboxes.** Give a `Hitbox` a collision shape and a `damage_info`, then set `active`. The first hits land on the physics tick after the activation, one tick later still when the hitbox is added to the tree and activated between two ticks, so keep it active for three ticks (0.05 s) or longer; J04's 0.15 s is plenty. `hurtbox_hit(hurtbox)` fires for every hurtbox that is handed the hit, whether or not its `Health` then takes it; a listener that sets `active = false` ends the hits of that tick, which is what a spent projectile wants. J04's `MeleeHitbox` extends `Hitbox` and overrides `_can_hit(hurtbox)` for the arc, asking the base first. One packet serves every target, because `Health` works on a copy.
- **Damage packets.** `DamageInfo.from_stats(stats, base_physical, base_frost, multiplier)` rolls the crit; set `source` (the attacker's root node), `skill_id`, `knockback` and `effects` on the packet afterwards. `Health.damaged(info, final_amount)` hands listeners the packet as the interceptors left it, before mitigation, and the amount after it. `info.source` is null when the attacker has been freed in the meantime. Knockback is carried and not applied; J20 does that.
- **Interceptors.** `health.interceptors.append(callable)` with `func(info: DamageInfo) -> bool`: change `info.physical` and `info.frost` in place to modify the hit, return true to cancel it. They also see the damage ticks of status effects; a Parry that should let those through asks `StatusEffectManager.is_tick(info)`. An interceptor may erase itself from the array while it runs.
- **Status effects.** Call `status.apply(effect, source)`, or put the effect into `DamageInfo.effects`: the manager applies those when the hit lands, and not when it is dodged, parried or lethal. `id` is the identity of an effect, so J05's `bleed_heavy.tres` needs an id of its own. `effect_applied` fires on every application, `effect_removed` once when the effect is gone. Death ends every effect. Ticks do nothing while `Health.invulnerable` is set.
- **`can_move`, `can_act` and move speed (J04, J07).** The manager only answers; nothing stops an actor yet. The job that gives the player its `StatusEffectManager` makes `Player` stand while `can_move` is false and denies `dodge_requested` then, checks `can_act` before a skill, and walks at `stats.get_stat(StatBlock.MOVE_SPEED)` in place of `Player.move_speed`; until it does, slow and frostbite change a number and nothing else. `Player.is_invulnerable` goes into `Health.invulnerable`, as the J02 notes say.
- **Pools.** A `ResourcePool` node is stamina by default. A mana pool sets `stat_key = &"max_mana"`, `regen_rate = 4` and `regen_delay = 0`, as the `Mana` node in `test/test_combat.tscn` does. `try_spend(0)` succeeds and does not hold the regeneration back.
- **Clocks.** Shields, pools and status effects run on physics ticks through a public `advance(delta)`. A GUT test calls it itself, tick by tick, and so tests four seconds of bleeding without waiting four seconds; `test/unit/test_status.gd` shows how.
- **J06.** `stats.add_modifier(&"equip:" + slot, stat, flat, percent)` once per modifier, any number of them under one source, also several on one stat; `remove_source` on unequip. `StatusEffectData` has no field that heals; the brew needs one.
- **J10.** Change base values with `stats.set_base(stat, value)`, which announces the change; writing into `stats.base` directly does not. The character sheet's breakdown by source needs a read accessor on `StatBlock` (`_modifiers` maps each source to its `{stat, flat, percent}` entries). `Health` keeps its missing fraction when max_health grows; `heal(health.maximum)` refills it.
- **J18, J19.** `Health.health_changed(current, maximum)` and `ResourcePool.changed(current, maximum)` drive the bars; `Health.shield` is readable and has no signal. `current` is read-only on both, so J19 adds what it needs to restore them from a save.
- **J20.** `combat/debug_damage_numbers.gd` and the `DamageNumbers` node in `test/combat_dummy.tscn` are what `damage_numbers.tscn` replaces. `Health.revive()` is the respawn: full health, no shields, and `died` can fire again. `damaged` carries `info.is_crit`.
- **Test dummies.** `test/combat_dummy.tscn` takes `display_name`, `faction` and `stats`; its `health`, `status` and `hurtbox` are public. The body is on layer 3 (enemy_body), not on the world layer, so J04's projectiles do not take it for a wall and the player walks through it as through an enemy. A dead dummy stays dead until something calls `health.revive()`.

## Deviations

- **`faction.gd` declares `class_name Factions`; the enum keeps the name `Faction`.** With a class and an enum of one name, `Faction` inside the script means the class, and a caller's `Faction.Faction` argument does not compile against it (tried in 4.7.2). The class also holds the four layer numbers and `is_hostile`.
- **`StatBlock.base` takes a copy of the dictionary it is assigned.** In 4.7 `Resource.duplicate()` shares the dictionary with the original, so "duplicate the resource per actor" alone left every actor writing into one `base`. Next to it: `set_base` (emits `stats_changed`), `get_base`, `has_source`, a constant per key and `KEYS`.
- **The percent multiplier stops at 0.** Modifiers that add up to less than -100 % (slow, frostbite and Bulwark together) stop a stat at zero and do not flip its sign.
- **Mitigation counts a defence or an amount below zero as zero.** The formula divides by 100 + armor, and a hit must not heal.
- **`from_stats`, where the spec is silent:** physical_bonus raises the physical part only, the crit multiplies both parts, and a crit multiplier under 1 counts as 1, so a block without the stat does not turn a crit into a hit for nothing.
- **Interceptors are `func(info: DamageInfo) -> bool`:** true cancels the hit, changing the packet modifies it. `Health` hands them and `damaged` a copy (`DamageInfo.copy()`), so one packet serves every target; a `source` that has been freed is null in the copy.
- **`final_amount` is the hit after armor and frost resistance, whether a shield or the health took it.** `damaged` and `health_changed` go out for every hit that lands, also one a shield absorbs whole, and their second parameter is `maximum` because `max` is a global function.
- **The dead take neither hits nor healing, and `Health.revive()` was added.** The test scene needs it for its dummies, J20 for the respawn. `maximum`, `shield` and `is_dead` are readable next to `current`, all read-only.
- **Shields stand side by side, each with its own clock; the one that ends first is used up first.** One summed pool would let a small long shield keep a large short one alive.
- **A hitbox hits on the physics tick after its activation, never in the same one.** It reads what the engine found overlapping in its last step; a hitbox that is moved and activated in one go would otherwise hit what stood at its old place.
- **`hits_once_per_activation` off means once per entry, not once per tick.** `Hitbox` also has `faction`, `hurtbox_hit(hurtbox)` and an overridable `_can_hit(hurtbox)`.
- **`ResourcePool` regenerates by two exports, `regen_rate` and `regen_delay`,** with the stamina values as defaults; a mana pool sets 4 and 0. It keeps its share when its maximum changes, as `Health` does, and spending nothing does not hold the regeneration back.
- **Stack rules of the seven effects, which the spec leaves open:** bleed INDEPENDENT, burn STACK_DURATION, the other five REFRESH, so that armor break and the two slows never stack with themselves.
- **Effects travel with hits through `Health.damaged`.** The manager applies the `DamageInfo.effects` of every hit that lands, so a dodged, parried or lethal hit applies none; death ends every effect. `effect_applied` goes out for every application, `effect_removed` once.
- **Ticks fall on multiples of `tick_interval` from the first application, the last one as the effect ends** (bleed: 8 in 4 s); a refresh does not shift them. A tick goes through `take_damage` with `skill_id` `status:<id>`, so it is mitigated, shielded, intercepted, and lost while the actor is invulnerable.
- **More on the manager than the spec lists:** `apply(effect, source)`, `remove`, `clear`, `has_effect`, `get_effect_ids`, `get_stacks`, `get_time_left`, `source_key` and `is_tick`.
- **Clocks run on physics ticks through a public `advance(delta)`** on `Health`, `ResourcePool` and `StatusEffectManager`. Tests call it themselves, and a tick of no length (`Engine.time_scale` 0) moves nothing.
- **The debug numbers are a node, `combat/debug_damage_numbers.gd` (`DebugDamageNumbers`),** placed above the actor. Physical is `text` and frost `spirit`, the pair J20 names, by the larger part of the packet; a crit gets a "!".
- **The test scene has a fixed camera and no player.** F, G, C and E hit (physical, frost, certain crit, enemy faction), 1 to 7 apply the effects, H heals and revives, I toggles invulnerability; B, X and M (shield, spend stamina, spend mana) were added for the shield and stamina criteria.
- **The dummy is a scene of its own, `test/combat_dummy.tscn` with `combat_dummy.gd` (`CombatDummy`),** because J04 and J10 build on "dummies from J03". Its box prop is on layer 3, enemy_body.
- **Two GUT files beyond the three listed:** `test_resource_pool.gd`, and `test_combat_scene.gd`, which presses the test scene's keys and measures its layout. Seventeen behaviours were broken on purpose, one or a few at a time, to see their tests fail.
- **`design/gdd.md` lists burn among the status effects now.** Its weapons table already had Firebrand apply it.
- **`game/README.md` gained two rows in its layout table, and `game/combat/.gdkeep` was removed.**
- **Checked headless, not by eye.** The six criteria are GUT tests, hitboxes on real physics frames and the clocks tick by tick; the scene's keys were also sent through `Input.parse_input_event` in a scratch run. Warnings raised to errors, the headless editor on both new scenes and a `ResourceSaver` round trip of the new files were clean; left for a person are how the labels read at their size and one look at the Output panel.
