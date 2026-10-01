# J02: Player movement, aim and camera

**Milestone:** M1 · **Depends on:** J01 · **Unblocks:** J04
**Reads first:** `design/gdd.md` §Presentation, §Controls; `plan/README.md` §Conventions

## Goal

A gray box the player moves with WASD relative to the camera, that always faces the mouse, can move slower while "attacking", can dodge, and is followed by a fixed-angle camera. This is the feel of the whole game, so tune it.

## Deliverables

- `game/player/player.tscn` and `player.gd` (`class_name Player`, `CharacterBody3D`)
- `game/player/aim.gd` (`class_name Aim`, child Node)
- `game/player/camera_rig.tscn` and `camera_rig.gd` (`class_name CameraRig`)
- `game/test/test_player.tscn` with a debug overlay
- Section in `game/README.md` on the movement model

## Spec

**Body.** `CharacterBody3D` on layer 2, colliding with layer 1. CapsuleShape3D radius 0.4, height 1.8. Visual is the graybox `box_actor` with size class PLAYER. Gravity 20 m/s², snap to floor, max slope 45°.

**Movement.** Read the four move actions into a `Vector2`, normalise, rotate by the camera's yaw so W is "up on screen", and drive `velocity` on the XZ plane. `@export var move_speed := 6.0`, `@export var acceleration := 40.0`, `@export var friction := 30.0`. A public `movement_multiplier: float = 1.0` scales the target speed; J04 sets it to 0.6 while attacking. Public read-only `move_dir: Vector3`.

**Aim.** The `Aim` node projects the mouse each physics frame: `camera.project_ray_origin(mouse)` and `project_ray_normal(mouse)` intersected with `Plane(Vector3.UP, player.global_position.y)`. Exposes `aim_point: Vector3` and `aim_dir: Vector3` (XZ, normalised, falls back to the last valid direction). The player rotates toward `aim_dir` at 20 rad/s. Facing never depends on `move_dir`.

**Attack-while-moving hook.** `movement_multiplier` is the only coupling. Until J04 exists, holding `skill_1` in the test scene sets it to 0.6 so the feel can be judged now.

**Dodge.** On `dodge`: dash 5 m over 0.25 s in `move_dir`, or in `aim_dir` when standing still. `is_invulnerable := true` for the dash. Cooldown 0.8 s. Exposes `can_act` false during the dash. Stamina cost is wired in J04 through `dodge_requested` signal returning whether it was allowed; for now always allowed.

**Camera rig.** A `Node3D` in the scene, not a child of the player. Each frame it lerps its position to the player at rate 8. Child `Camera3D` at pitch 55°, distance 18 m, FOV 40, yaw fixed at 0. Mouse wheel zooms between 12 and 24 m. Expose `get_yaw()` for the movement code.

**Debug overlay.** A `CanvasLayer` with a `Label` showing speed, multiplier, aim point, dodge cooldown, fps. Only in the test scene.

## Acceptance criteria

- [ ] Diagonal movement is the same speed as cardinal movement
- [ ] The box faces the mouse while moving in any other direction, with no snapping
- [ ] Holding RMB slows movement to 60% and releases cleanly
- [ ] Dodge covers about 5 m, cannot be chained faster than every 0.8 s, and passes through nothing it shouldn't
- [ ] Camera follows without jitter at 30, 60 and 144 fps (test with the fps cap in project settings)
- [ ] Walking into walls and pillars slides along them
- [ ] Editor loads with no errors or warnings

## Out of scope

Stats, stamina, damage, weapons. Any animation beyond rotation.

## Notes for later jobs

- J04 reads `aim_dir` at the moment a skill fires and sets `movement_multiplier` for the skill's duration.
- J18's HUD replaces the debug overlay; do not build UI here.

## Deviations

(none yet)
