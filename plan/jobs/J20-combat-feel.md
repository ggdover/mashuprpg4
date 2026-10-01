# J20: Combat feel and feedback

**Milestone:** M2 · **Depends on:** J03, J04 · **Unblocks:** J22
**Reads first:** `design/gdd.md` §Placeholder policy (what feedback is allowed with gray boxes); J03 (damage signals), J04 (skill signals)

## Goal

Make gray-box combat feel good without art: hit stop, hit flash, knockback, camera shake, damage numbers, attack lunges, telegraph readability, death feedback. All of it driven by signals, none of it needing models.

## Deliverables

- `game/combat/feedback/hit_flash.gd`: tints a box's material to `highlight` for 0.08 s on `damaged`
- `game/combat/feedback/hit_stop.gd`: freezes both attacker and victim for 40 to 80 ms on a hit, scaled by damage
- `game/combat/feedback/damage_numbers.tscn`: replaces J03's debug labels; physical in `text`, frost in `spirit`, crits larger with a pop, healing in `stamina`
- `CameraRig.shake(strength, duration)` and calls on player hits taken, crits dealt, boss slams
- Attack lunge: the player and enemy boxes tween 0.3 m forward on melee attacks and the nose box scales briefly, so attacks read even without animation
- Knockback applied through `DamageInfo.knockback` on `CharacterBody3D` velocity with a 0.15 s decay
- Death: enemies shrink and fall over (rotate 90° while shrinking), player death fades to `deepest` and respawns at the nearest safe point after 2 s
- Low-health vignette using the state `panel` colour at the screen edges below 25% health
- `game/test/test_feel.tscn` with sliders for hit stop, shake and flash to tune live

## Spec

Keep every effect small and readable. Hit stop must not affect the camera or the UI. Shake never exceeds 0.3 m and always decays. Damage numbers stack upward when several hits land in a frame. Frost hits add a brief frost tint to the victim. Telegraphs from J09 get a 0.2 s "flash to highlight" right before impact.

## Acceptance criteria

- [ ] Hitting a dummy shows flash, number, hit stop and a lunge; crits are clearly different
- [ ] Taking a hit shakes the camera slightly and the low-health vignette appears under 25%
- [ ] Player death respawns at the nearest safe point with full health
- [ ] Sliders in the test scene change the feel live and the chosen values are written back into the feedback scripts as defaults
- [ ] Editor loads clean

## Out of scope

Audio, particles beyond simple box bursts, animation.

## Deviations

(none yet)
