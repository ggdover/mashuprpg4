# Forest palette (Act 1)

Two palettes for the two states of the forest: **Day (Dagsljus)** and **Fog (Dimma)**. Everything added to the game from here on, environment, characters, props, effects and UI, takes its colours from these tables by role.

Files in this folder:

- `palette.json` is the source of truth. Engine code and tools read this.
- `palette.html` is a visual preview next to the reference images. Regenerate it with `build_palette.ps1` after editing the JSON.

## Where the colours come from

Sampled from the eight reference images in `ref_imgs/`: k-means over about 1.5 million pixels per state, plus averages of small regions for things too small to cluster (berries, spirits, the lantern, the rune carving). Then hand-tuned so the value steps are even and the accents read at game saturation rather than photo saturation.

What the sampling said:

- **Day is warm.** The dominant hue is olive-gold (hue 45 to 50 degrees): moss, needle litter and sunlit bark. The sky is the only cool colour and covers about 7% of pixels.
- **Fog is one cold ramp.** About a quarter of all pixels sit in a blue-slate band (hue around 214 degrees, saturation 0.15 to 0.20) and a third are near black. Under 1% of pixels are saturated at all, and those are spirits, the lantern, the rune carving and berries.

So fog is not a night version of day. It is the same roles pulled toward blue-slate and darkened, with a handful of accents kept saturated on purpose.

## Structure

Roles, not colours. A role is what the colour is for (moss, bark, sky), so an asset authored by role gets its fog version for free.

- **Ramp** (6): the value scale of each state. Paired day/fog.
- **Environment** (12): the things the forest is made of. Paired day/fog.
- **Accents**: what is special about each state. Day has 3, fog has 5. Not paired.
- **UI signals**: picked from the above, no new colours.

## Value ramp (paired)

Six steps from deepest shadow to brightest light. Anything without a strong hue of its own is shaded along this ramp.

| Role    | Day       | Fog       | Use |
|---------|-----------|-----------|-----|
| deepest | `#15130A` | `#0C0D0B` | Deepest shadow: under boulders, tree hollows, cave mouths. Outlines. |
| shadow  | `#2A2612` | `#1F211B` | Shadow side of everything. Default dark for UI panels. |
| dark    | `#463F27` | `#3A3E3D` | Shaded mid-tones: bark in shade, wet ground, dark cloth. |
| mid     | `#7A7048` | `#626C7A` | Neutral mid-tone. Undyed wool, weathered wood, plain stone. |
| light   | `#BFAF7E` | `#99A4B3` | Lit surfaces without a strong hue of their own. |
| bright  | `#EDEAE0` | `#C9D0D8` | Highest highlight. Day: cloud, lichen glare, sun on stone. Fog: the fog ceiling, rime. |

## Environment (paired by role)

| Role      | Day       | Fog       | Use |
|-----------|-----------|-----------|-----|
| canopy    | `#2F3D1F` | `#22271A` | Needle mass of pine and spruce in shade; distant treeline. |
| moss      | `#5C6A36` | `#3E4430` | Forest-floor moss, ferns, blueberry leaves. The default green. |
| moss-lit  | `#AEB055` | `#6E7558` | Moss where light hits it. Day: the yellow-green that sells sunshine. Fog: dew-grey. |
| bark      | `#8A6A4C` | `#58493A` | Trunks at eye height; wooden buildings, fences, signposts. |
| granite   | `#7D7F79` | `#5A6267` | Boulders, runestones, cliff faces, the mountain (berget). |
| lichen    | `#C9D0CE` | `#A9B8C4` | Pale lichen crust on rock. In fog this is rime and frost. |
| soil      | `#A9835A` | `#494B45` | Paths, needle litter, roots, exposed earth. |
| sky       | `#92B8E3` | `#7B8696` | Clear sky. Day horizon lightens to `#B5D2EE`. Fog dusk shifts to violet `#6F6A85`. |
| water     | `#5D8DBE` | `#46525F` | The lake (sjön), tarns, bog pools. |
| lingon    | `#B92A2F` | `#7A3A34` | Lingonberries. Also blood, madder-dyed cloth, and danger. |
| blueberry | `#566A91` | `#4F5C80` | Blueberries with their pale bloom; woad-dyed cloth; cold shadow tint. |
| heather   | `#B487A8` | `#6B5B7A` | Ljung in bloom on rock slabs and bog edges. |

## Accents

### Day

| Role     | Hex       | Use |
|----------|-----------|-----|
| sun      | `#E6C878` | Golden sunlight: beams, rim light, hearth glow. Primary highlight for interactables and UI. |
| sun-core | `#FCF4DF` | Sun disc, lens flare, the hottest point of any light. |
| tallbark | `#C98B56` | Orange upper bark of Scots pine. Warm secondary accent; wood in firelight. |

### Fog

| Role   | Hex       | Use |
|--------|-----------|-----|
| spirit | `#C2DAE8` | Translucent spirit bodies, active runes, the cold light of the fog state. UI highlight in fog. |
| wisp   | `#EAF5FC` | Wisp cores, spirit eyes, hottest highlight in fog. |
| rune   | `#7E4F31` | Rust-ochre carvings in stone, old iron, dried blood. |
| ember  | `#E39A4C` | Lantern, cairn fire, torch. The only warm light in fog: reserve it for safety and for light the player or the village made. |
| dusk   | `#D4A78E` | Peach band at the horizon when the fog rolls in at sunset. |

## UI signals

No new colours. Health and stamina keep their day values in fog so they stay readable; they are the two allowed saturation exceptions in the fog state.

| Signal    | Day       | Fog       | From |
|-----------|-----------|-----------|------|
| text      | `#EDEAE0` | `#C9D0D8` | ramp bright of each state |
| panel     | `#2A2612` | `#1F211B` | ramp shadow of each state, at about 85% opacity |
| highlight | `#E6C878` | `#C2DAE8` | sun in day, spirit in fog: interact prompts, selected item, quest marker |
| health    | `#B92A2F` | `#B92A2F` | day lingon in both states |
| stamina   | `#AEB055` | `#AEB055` | day moss-lit in both states |

Contrast against the panel (WCAG ratio; text needs 4.5, graphics 3.0):

| Signal    | Day  | Fog  |
|-----------|------|------|
| text      | 12.6 | 10.5 |
| highlight | 9.3  | 11.2 |
| stamina   | 6.6  | 7.1  |
| health    | 2.5  | 2.7  |

## Rules for anything new

1. **Pick by role, not by eye.** A wooden door is bark, a cliff is granite, a cloak is a ramp step or a berry colour. If the role exists, use its value in both states.
2. **Fog saturation budget.** In fog, nothing except the fog accents and the two UI exceptions goes above saturation 0.35. If a thing needs to pop in fog, it is a spirit, a light, or a berry.
3. **Warm light means safety.** Ember is the only warm colour in fog. Use it for light the player or the village made: lantern, hearth, torch, cairn fire. Never for enemies.
4. **Cold light means the other world.** Spirit and wisp are for spirits, active runes and the fog-state highlight. Never for ordinary lamps.
5. **Red is a fill, not a font.** Lingon on a panel is about 2.5:1, fine for bars and icons, too low for text. Danger text uses the state highlight with a lingon icon next to it.
6. **No formula for fog.** Lichen, sky and berries do not desaturate the same way, so fog values are hand-picked. The check at the end of `build_palette.ps1` shows how far a simple blend lands from them. When you need a colour that is not here, add a paired row to the JSON rather than inventing one inside an asset.
