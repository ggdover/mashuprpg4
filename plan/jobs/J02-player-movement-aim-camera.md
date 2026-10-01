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

**Dodge.** On `dodge`: dash 5 m over 0.25 s in `move_dir`, or in `aim_dir` when standing still. `is_invulnerable := true` for the dash. Cooldown 0.8 s. Exposes `can_act` false during the dash. Stamina cost is wired in J04 through the `dodge_requested(request: DodgeRequest)` signal: a listener that cannot allow the dodge calls `request.deny()`; for now nothing listens, so it is always allowed.

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

- J04 reads `player.aim.aim_dir` at the moment a skill fires and sets `movement_multiplier` for the skill's duration.
- J18's HUD replaces the debug overlay; do not build UI here.
- J04 wires the dodge's stamina cost: connect to `Player.dodge_requested(request: DodgeRequest)`, try to spend, and call `request.deny()` when the pool is short. The signal fires only when a dodge is otherwise ready, so a dodge that is running or cooling down costs nothing. No document gives the cost a number yet.
- `Player.is_invulnerable` is true for the length of the dash and `Player.can_act` is false. The job that gives the player its `Health` node (J03 builds the node, J04 is the first job with both in hand) copies `is_invulnerable` to `Health.invulnerable`.
- `Player.visual` is the `BoxActor`; its `nose` is where J04 attaches the weapon box.
- `test/arena.tscn` has no camera and no actors. A test scene instances the arena, `player.tscn` and `camera_rig.tscn`, points `Player.camera_rig` and `CameraRig.target` at each other, and puts the player on `Arena/PlayerSpawn`. `test_player.tscn` with `player_test_scene.gd` is the pattern. A test scene's script is not named `test_*.gd`: that pattern belongs to the GUT tests.
- Whatever teleports the player (J12's zone change, J20's respawn) sets its position, then calls `player.reset_physics_interpolation()` and `camera_rig.snap_to_target()`; otherwise the jump is drawn as a glide. The player turns back to the mouse within a fraction of a second, so the facing an entry marker gives it only holds for the first frames.
- The main scene is `test/test_player.tscn` until J12 makes `main.tscn` the main scene.
- J20's camera shake belongs in `CameraRig._place_camera()`, which sets the camera's place under the rig every frame. An offset written to the camera from anywhere else is overwritten on the next frame.
- After a change to the rig (J20's shake), `tools\camera_follow_probe.cmd` measures again whether the follow is still steady at 30, 60 and 144 fps.
- GUT tests that need physics step with `await get_tree().physics_frame` and count the frames themselves; `wait_physics_frames(n)` can let n + 1 ticks run. A test that needs the mouse or the active camera puts its nodes in a `SubViewport` and places the mouse with `push_input`: the root viewport takes its mouse from the display, which a test cannot place in a window, and headless it is a 64 × 64 window. `test/unit/test_player.gd` shows the first, `test_player_scene.gd` the second.
- `--quit` stops after one frame, before most per-frame code has run. `--quit-after 300` runs a scene for 300 frames; both READMEs list it.

## Deviations

- **`dodge_requested` carries a `DodgeRequest`, because a signal cannot return a value.** The spec had the signal return whether the dodge was allowed. `Player.dodge_requested(request: DodgeRequest)` hands every listener a small object (`player/dodge_request.gd`); a listener that has to stop the dodge calls `request.deny()`, and the player reads `request.allowed` after the emit. Nothing listens yet, so a dodge is always allowed. The spec sentence above was corrected.
- **`Player.try_dodge() -> bool` is public.** The `dodge` action calls it from `_unhandled_input`, so a UI that consumes Space also swallows the dodge. Tests start a dash through it, and so can a debug console or a scripted scene.
- **The cooldown runs from the start of a dash.** That is what "cannot be chained faster than every 0.8 s" asks for: 0.25 s of dash, then 0.55 s before the next one.
- **A dash does not coast.** When it ends, the horizontal velocity is set to the walking velocity for the keys held at that moment, zero if none. Left at dash speed (20 m/s), friction would carry the body another 6.7 m. The last physics step of a dash is scaled to the time that is left, so the distance is 5 m at any tick rate.
- **`Input.get_vector` does the normalising.** It caps the length of the move vector at 1, which for keys is the same as normalising, and it cancels opposite keys.
- **The whole body turns, not only the box.** `Player` rotates about Y toward `aim_dir`, so `-global_basis.z` is the facing for every later job. The capsule is round, so turning it changes no collision.
- **Aim details the spec leaves open.** The camera is the viewport's active `Camera3D`, so `Aim` needs no reference to the rig. `aim_dir` starts as the player's facing. A mouse within `min_aim_distance` (0.1 m, `@export`) of the player keeps the previous direction; right on top of the player it would flip at every twitch. `Aim` has `process_physics_priority = -1` in `player.tscn`, so it runs before the player in each tick and the player turns toward a direction measured in that tick. `Aim.update_from_ray(origin, normal)` is public so that tests can aim without a camera.
- **`Player.camera_rig` and `CameraRig.target` are `@export` node references**, set in the scene that holds both. Without a rig the player walks with yaw 0.
- **The follow closes `1 - exp(-rate × delta)` of the gap per frame, not `rate × delta`.** "Lerps at rate 8" taken literally closes a different share of the gap at each frame rate, and the criterion asks for the same follow at 30, 60 and 144 fps. With the exponential form the gap after any stretch of time is the same however the time is cut into frames.
- **The rig is not physics-interpolated, and it follows the position the player is drawn at.** J01 turned physics interpolation on, so the player is drawn between its 60 physics ticks. `camera_rig.tscn` sets `physics_interpolation_mode` to Off and the rig moves in `_process` toward `target.get_global_transform_interpolated()`. A rig that chased `global_position` would make the player shake on screen whenever frames and ticks fall out of step: by 5 mm or more at 144 fps, against about 0.1 mm this way.
- **Zoom eases.** A wheel notch moves the wanted distance by `zoom_step` (1 m, `@export`) between 12 and 24 m, and the camera closes on it with the same weight as the follow. `CameraRig.snap_to_target()` jumps both without gliding; the rig calls it when it becomes ready, and teleports should. Pitch, distance, the two limits and the follow rate are `@export`s; the 40° field of view is set on the `Camera3D` in `camera_rig.tscn`.
- **`wall_min_slide_angle` is 0 on the player.** With Godot's default of 15° the body stops dead on a wall it meets within 15° of head-on, and on a pillar corner it only clips (its axis up to 10 cm outside the pillar's edge). With 0 it slides at the part of its speed that runs along the surface, at every angle, which is what "slides along them" asks for. Probed under Jolt: no shake against a flat wall, a turned wall or an inner corner.
- **The body steps off a corner it meets dead centre.** Walking W+D from the arena's spawn leads straight at a pillar that sits on the diagonal, and the capsule met its corner with a normal exactly opposite to the walk: nothing to slide along, so it stood there for as long as the keys were held, and so did a dash. The spec does not mention the case, but it is the first thing a diagonal walk in the test scene runs into, and round-number coordinates in hand-built zones will repeat it. `Player._step_off_corner()` takes one sideways step of `corner_step` (5 cm, `@export`) when the body is stopped dead centre by a surface whose normal is different a step to the side. A wall has the same normal there and gets no step, so a wall met head-on stops the body without any creep. Near misses are left to the ordinary slide.
- **Snap to floor and the 45° slope limit are the `CharacterBody3D` defaults** (`floor_snap_length` 0.1 m, `floor_max_angle` 45°), so `player.tscn` does not write them; `test_player.gd` pins both. `gravity`, `turn_speed` and the dodge's distance, duration and cooldown are `@export`s next to the three the spec names.
- **Extra read-only members on `Player`:** `is_dodging`, `dodge_cooldown_left` (the overlay shows it, J18's HUD will), `aim` and `visual`. Every read-only property of `Player` and `Aim` is a getter over a private variable plus a setter that pushes an error. GDScript has no read-only keyword, and a property with only a getter swallows an assignment without a word, which would hide a later job writing to `can_act`. No GUT test covers the refusal: it prints an `ERROR` line, and the gate counts those in the GUT output as failures. A probe confirmed each write is refused and reported.
- **The arena lost its stopgap camera and its six display actors** (the J01 review left both to this job). A second current camera would compete with the rig's in every test scene, and inert boxes with noses would stand among J07's enemies. Both moved, unchanged, into `test/test_graybox.tscn`, which instances the arena and is now the graybox kit's own test scene.
- **The main scene is `res://test/test_player.tscn`.** The arena alone shows nothing without a camera, and M1's checkpoint is "walk and aim a box in an arena", so that is what `tools\run.cmd` starts. The `--quit` check now compiles the player scripts as well. `game/README.md` and the comment in `tools/run.cmd` say so. J12 moves the main scene on to `main.tscn`.
- **The test scene's script is `test/player_test_scene.gd` (`PlayerTestScene`), not `test_player.gd`.** `test_*.gd` is the GUT name pattern, and by convention those scripts carry no `class_name`. It places the player on the arena's `PlayerSpawn`, sets `movement_multiplier` from `skill_1`, and writes the overlay. The overlay takes its text colour and outline from `Palette` and adds one line naming the keys.
- **GUT tests were added although the job lists none:** `test/unit/test_player.gd`, `test_aim.gd`, `test_camera_rig.gd` and `test_player_scene.gd`, 51 tests. Nobody can look at the test scene from the command line, so the acceptance criteria are checked as numbers on real physics frames. Each behaviour was also broken on purpose once to see its test fail.
- **Two lines were added to `plan/README.md` and `game/README.md`:** the convention that a test scene's script is not named `test_*.gd`, and `--quit-after N` in the command-line cheat sheet, because `--quit` stops after one frame and per-frame code has hardly run by then.
- **`tools/camera_follow_probe.gd` and `tools/camera_follow_probe.cmd` were added.** The camera criterion says to test with the fps cap, which takes eyes. The probe does it with numbers: it runs the test scene headless in the real main loop, holds W, caps the frame rate at 30, 60 and 144, and prints how much the distance between the rig and the drawn player changes, next to what a rig chasing the physics ticks would have done. Exit code 0 means the distance held within 2 mm at all three. It is not a GUT test because it depends on real frame times, and a stall on a busy machine would fail the suite.
- **`game/player/.gdkeep` was removed;** the folder is no longer empty.
- **J01's open review note on the arena camera is marked done** in `plan/jobs/J01-project-skeleton.md`, so nobody takes it for open. Its other two notes (palette drift guard, `tools/test.cmd` exit code) are untouched.
- **Scenes written for 4.7.** The new `.tscn` files have no `load_steps` in their header (4.7 no longer writes it) and name their scripts by UID as well as by path. A load-and-save round trip through `ResourceSaver` reproduces them apart from the generated ids.
- **Checked headless, not by eye.** Same speed on a diagonal, facing independent of the walk, the turn rate, the 60 % slowdown, the dash's distance, duration and cooldown, the wall stopping a dash, sliding along walls and around pillars, and W being up on screen are GUT tests on real physics frames. The mouse test puts the mouse over a ground point in the test scene and finds the aim point and the player's nose there. For the camera, `tools\camera_follow_probe.cmd` gave, over several runs, a distance between the rig and the drawn player that varied by 0.03 to 0.6 mm at the three frame caps (a pixel is about 15 mm of ground at the default zoom), and a GUT test checks at the same three rates that every frame the rig lands where following the drawn position puts it. All scripts compile with every default-level GDScript warning raised to an error, and the headless editor opens each new scene without a message. What is left for a person with the editor: the feel of the speeds, and one look at the Output panel.
