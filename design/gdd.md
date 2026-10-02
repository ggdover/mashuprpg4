# Game design document (graybox milestone)

Working title: mashuprpg4. Genre: action RPG. Engine: Godot 4.7 (GDScript).
Scope of this document: act 1, playable with placeholder gray boxes. Final art, animation, audio and act 2 are out of scope.

Companion docs: `world_act1.md` (story, world, zones), `quests_act1.md` (quest data), `palette.md` (colours), and the execution plan in `../plan/`.

## Pillars

1. **The forest in two states.** Same places, day and fog. Fog is rare and event-triggered. It changes the enemies, the light, and the way home.
2. **A normal villager who keeps asking.** No chosen one. Quests come from the old lady and from the player's own curiosity. Everyone else treats the fog like weather.
3. **Kill, loot, level.** Open zones and cave dungeons full of mobs. Every quest is a kill, a boss, or reach-find-bring.

## Presentation

- 3D, fixed-angle top-down camera (pitch about 55 degrees, yaw fixed, follows the player, no rotation). Everything is a gray box until the art pass.
- The palette in `palette.json` drives lighting, environment and UI. Boxes stay gray; state and category are shown by light, small tints and labels.

## Controls

| Input | Action |
|-------|--------|
| W A S D | Move, relative to the camera |
| Mouse | Aim. The character faces the aim point at all times |
| LMB | Basic attack of the equipped weapon |
| RMB, 1, 2 | Weapon skills (three per weapon) |
| Space | Dodge: short dash with invulnerability frames |
| E | Interact, pick up, talk |
| I | Inventory and equipment |
| C | Character sheet |
| J | Journal |
| Esc | Pause |

Attack while moving is allowed. Movement speed is multiplied by 0.6 while any attack or skill is active. Attack direction is the aim direction and is independent of movement direction.

## Combat

Stats: max health, max stamina, max mana (staff only), armor, physical damage bonus, frost resistance, crit chance, crit multiplier, move speed, attack speed.

Damage types: physical and frost. Possessed enemies deal part of their damage as frost. The winter coat (phase 3 reward) gives frost resistance, which is what makes act 2 survivable.

Initial formulas, all tunable in data:

- Hit damage = weapon base damage × skill multiplier × (1 + physical damage bonus) × crit multiplier if crit.
- Armor: incoming physical × 100 / (100 + armor). Frost resistance works the same way against frost.
- Attack speed scales attack animation time and skill cooldowns.
- Stamina regenerates when no skill has been used for 1 s. Mana regenerates slowly always.

Hit detection: melee uses an arc or box hitbox in front of the aim direction, active for a few frames. Ranged uses projectiles. All actors have hurtboxes. Dodge grants invulnerability frames.

Status effects: bleed (damage over time), slow, stun, root, armor break, frostbite (slow plus damage over time), burn (damage over time).

Death: the player respawns at the last village or lit cairn. Enemies drop loot and grant XP.

## Weapons and skills

Six weapon types. Each has a basic attack on LMB and three skills on RMB, 1 and 2. Skills unlock at character levels 1, 4 and 8. Melee and ranged skills cost stamina; staff skills cost mana. Names are placeholders.

| Weapon | Basic (LMB) | RMB, level 1 | Skill 1, level 4 | Skill 2, level 8 |
|--------|-------------|--------------|------------------|------------------|
| Sword | 3-hit slash combo, 90° arc, fast | Lunge: dash 4 m then stab | Whirl: 360° spin, two hits | Parry: 0.5 s window, negates one hit and stuns the attacker |
| Axe | Wide chop, 120° arc, slow, bleed chance | Cleave: 180° heavy hit with knockback | Throw: returning axe projectile that pierces | Rage: 6 s of +30% attack speed and -30% armor |
| Mace | Overhead smash, small area, stun chance | Ground Slam: 3 m area knockdown | Guard Break: single hit, target armor -50% for 6 s | Bulwark: 4 s of -50% damage taken and -40% move speed |
| Bow | Arrow, hold to charge up to 2×, pierces at full charge | Multishot: fan of three arrows | Piercing Shot: passes through every enemy in line | Kite: backstep 3 m and fire instantly |
| Crossbow | Bolt, high damage, 0.8 s reload | Volley: three bolts in 0.5 s | Net Bolt: roots the target for 2 s | Barbed Bolt: heavy bleed |
| Staff | Ember spark: slow projectile, slight homing | Firebrand: fire projectile with burn and small area | Ward: 3 s shield that absorbs damage | Flare: 4 m area stun for 1.5 s with knockback |

## Loot and equipment

Slots: weapon, head, chest, hands, feet, ring, ring, amulet. No off-hand slot in the graybox.

Rarities and their UI colours from the palette: common (ramp light `#BFAF7E`), fine (moss-lit `#AEB055`), rare (sky `#92B8E3`), legendary (sun `#E6C878`).

Item generation: base item by slot and item level, then affixes rolled by rarity (common 0, fine 1, rare 2, legendary 3) from a small pool: +physical damage, +health, +armor, +frost resistance, +move speed, +attack speed, +crit chance, +stamina. Item level comes from the zone or enemy tier.

Drops: every enemy has a loot table with rarity weights. Bosses guarantee at least one rare. Ground items are small boxes tinted by rarity with a label; E picks them up. Silver is picked up automatically.

Currency: silver. The storehouse keeper in Tjärnäs buys and sells; the smith sells weapons.

Inventory: a grid (8 by 6). Consumables and materials stack (goldieflowers, boar meat, pelts, tallow). Quest items live in a separate tab and never drop.

Consumables: brew (heals over 3 s, from the old lady or the storehouse).

## Progression

XP from kills and quest turn-ins. Levels 1 to 20 cover act 1. Each level raises base health and stamina and grants one stat point to put in health, damage, armor or speed. Weapon skills unlock at levels 1, 4 and 8 regardless of weapon, so switching weapons never loses progress.

## Enemies

Categories:

- **Neutral animals** only fight back when attacked, and flee when fog comes.
- **Possessed animals** attack on detection.
- **Possessed humans** appear only in fog and in dungeons. Melee "lost villager" and ranged "lost hunter" with a bow.

Roster: boar, wolf, bear, raven, squirrel, fox, plus the two possessed humans. Every animal exists in a neutral and a possessed variant.

Where they spawn:

- Day: neutral and possessed animals. The share of possessed rises with story progress (phase 1 about 20%, phase 2 about 50%, phase 3 about 80%).
- Fog: possessed animals and possessed humans only.
- Dungeons: possessed only, humans always allowed.

Detection: possessed detection radius 12 m. Ravens 20 m, and a raven that spots the player alerts everything within 15 m. Neutral animals ignore the player until hit.

Elite modifiers, applied at random to possessed spawns: rimed (frost aura that slows nearby players), hulking (size and health up), swift (speed up), pack leader (buffs allies in 8 m).

Bosses, in order: Great Raven, Alpha Wolf, The Old One (bear), Pack Mother (wolf), The Sleeper (bear), The Troll. The troll turns to stone in sunlight, so the fight is at the cave mouth at dawn and is won by dragging it into the light.

## World

Two states: **Day** and **Fog**. Fog is triggered by story events (quest flags) and by zone entry with a probability that rises per phase, so the village's worry that fog is getting more frequent is real. Fog ends when the player enters a village or when the scripted scene that started it resolves.

In fog:

- Only possessed creatures spawn.
- Visibility distance drops. Environment and lighting switch to the fog preset from the palette.
- Fog-only nodes appear (alternate signposts reading Norr, Skogen, Ingen väg, Frost; extra paths) and some day-only landmarks hide, so the way home is genuinely harder to find.
- Lit cairns are visible from far away. The bell (phase 2 reward) points to the nearest cairn. The lantern (phase 3 reward) widens the player's light radius.
- The horn sounds from the village at fog start.

Zones in act 1 (details in `world_act1.md`): Tjärnäs, Lake shore, Fairmeadow, Hunting woods, Crossroads and north shore, Norrby, Frost line, Berget approach. Dungeons: Wolf den, Flooded cave.

## Quests

Three types only: kill mobs, kill boss, reach-find-bring. Story beats attach to turn-ins and to scripted scenes triggered by completion. Repeatable hunts keep the loop fed between story quests. Data in `quests_act1.md`.

## NPCs

The old lady (edge of Tjärnäs; quest giver and lore, stays behind), storehouse keeper (vendor, repeatable meat), tanner (pelts, winter coat), smith (weapons vendor), fisherman (rumor, horn), headman (dismissal), Norrby headwoman and two villagers. The vittror are voices in fog at scripted points, shown as spirit-light markers, never as models.

## UI

HUD: health, stamina or mana, skill bar (LMB, RMB, 1, 2), quest tracker, fog indicator. Screens: inventory and equipment, character sheet, journal, dialogue box, vendor, pause and settings, main menu. All colours from the palette's UI signals for the current state.

## Placeholder policy

- Gray boxes only: BoxMesh with a StandardMaterial3D in ramp mid gray. Size classes: player 0.8 × 1.8 m, small animal 0.5 m, medium 1.0 m, large 1.6 m, boss 2.5 m, troll 4 m.
- Facing is shown by a smaller "nose" box on the front.
- Category cues: possessed creatures get a frost tint (`#A9B8C4`) and a label. Interactables get an outline in the state highlight colour. Ground items are 0.3 m boxes tinted by rarity.
- No textures, models, or skeletal animation. Simple tweens only: attack lunge, hit flash, death shrink.

## Out of scope for the graybox milestone

Final art, animation, audio, act 2, controller support, localisation, multiplayer.
