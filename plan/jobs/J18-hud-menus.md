# J18: HUD and menus

**Milestone:** M3 · **Depends on:** J03, J04, J06, J10, J15 · **Unblocks:** J22
**Reads first:** `design/gdd.md` §UI, §Controls; `design/palette.md` §UI signals and rules 3 to 5; J04 (cooldown signals), J11 (fog and bell signals), J15 (quest signals)

## Goal

The in-game HUD, the menus, and a palette-driven theme that swaps with the world state, so every screen from earlier jobs looks like one game.

## Deliverables

- `game/ui/theme/theme_builder.gd`: builds two `Theme` resources from `Palette.DAY` and `Palette.FOG` at startup (or a tool script that writes `theme_day.tres` and `theme_fog.tres`)
- `game/ui/hud/hud.tscn` with: health bar, stamina or mana bar, skill bar, xp bar, silver, quest tracker, interaction prompt, fog indicator and horn toast, bell indicator, boss bar (restyle of J09's), toasts
- `game/ui/menus/main_menu.tscn`, `pause_menu.tscn`, `settings.tscn`
- Restyle passes on the inventory (J06), character sheet (J10), journal (J15), dialogue and vendor (J16) to use the theme
- `game/test/test_hud.tscn`

## Spec

**Theme.** Text uses the state's `text`, panels the state's `panel` at 85% opacity, focus and selection the state's `highlight`. Health is fixed `health`, stamina `stamina`, mana uses `blueberry` day value. Rarity colours as the gdd maps them. Fonts: the default font at 16 px body, 22 px headings. `Main` swaps the HUD root's theme on `world_state_changed` with a 0.5 s crossfade of a full-screen tint so the change reads as the fog rolling in.

**HUD.** Bottom-left: health and stamina bars with numbers; the stamina bar becomes mana when a staff is equipped. Bottom-centre: four skill slots labelled LMB, RMB, 1, 2 with the skill name, a radial or vertical cooldown fill from `cooldown_changed`, a lock icon below the unlock level, and a grey-out when the resource is short. Bottom: xp bar with level. Top-right: silver and the quest tracker showing the most recent active quest's objectives "3 / 8". Centre: the interaction prompt from `Interactor`. Top-centre: the boss bar. Top-left: fog indicator (a small label "Fog" in `spirit`) and the horn toast "The horn sounds from Tjärnäs" for 4 s on `horn_sounded`. Bell indicator: when `has_bell` and state is FOG, an arrow at the screen edge toward `WorldState.nearest_lit_cairn` with the distance. Toasts stack at the top: "New question", "Quest complete: name", "Level up".

**Red is a fill, not a font.** Per the palette rules, never render text in the health colour; danger text uses `highlight` with a red bar or icon beside it.

**Menus.** Main menu: New game, Continue (disabled until J19 provides a save), Settings, Quit. Pause: Resume, Settings, Quit to menu; pauses the tree. Settings: rebind every action from J01 through `InputMap` with a listen-for-key control, fps cap (60, 120, unlimited), fullscreen toggle, master volume slider that stores a value for later audio work.

**Restyle.** Each earlier screen gets the theme and consistent panel layout. Don't change their behaviour.

## Acceptance criteria

- [ ] Every HUD element updates live from its signal in the test scene
- [ ] Theme swaps on fog with a visible crossfade and all screens follow
- [ ] Rebinding a key in settings takes effect immediately and persists in `user://settings.cfg`
- [ ] No text anywhere is drawn in the health colour
- [ ] Editor loads clean

## Out of scope

Audio. Save and Continue (J19). Combat feedback effects (J20).

## Deviations

(none yet)
