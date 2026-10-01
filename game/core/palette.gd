## generated, do not edit
## Source: design/palette.json (mashuprpg4 forest palette, version 1).
## Regenerate from the repo root with:
##   powershell -ExecutionPolicy Bypass -File tools\gen_palette_gd.ps1
##
## Colours by role for the two forest states. Pick by role, never by eye;
## design/palette.md has the rules. Keys are the role names from the JSON.
class_name Palette
extends RefCounted

## Returned by [method role] for a role that exists in neither state.
const MISSING := Color.MAGENTA

## Day (Dagsljus): Sunlit Swedish pine forest. Warm olive-gold ground, orange pine bark, one cool colour: the sky.
const DAY: Dictionary = {
	# Ramp
	"deepest": Color("#15130A"), # Deepest shadow: under boulders, tree hollows, cave mouths. Outlines.
	"shadow": Color("#2A2612"), # Shadow side of everything. Default dark for UI panels.
	"dark": Color("#463F27"), # Shaded mid-tones: bark in shade, wet ground, dark cloth.
	"mid": Color("#7A7048"), # Neutral mid-tone. Undyed wool, weathered wood, plain stone.
	"light": Color("#BFAF7E"), # Lit surfaces without a strong hue of their own.
	"bright": Color("#EDEAE0"), # Highest highlight. Day: cloud, lichen glare, sun on stone. Fog: the fog ceiling, rime.
	# Environment
	"canopy": Color("#2F3D1F"), # Needle mass of pine and spruce in shade; distant treeline.
	"moss": Color("#5C6A36"), # Forest-floor moss, ferns, blueberry leaves. The default green.
	"moss-lit": Color("#AEB055"), # Moss where light hits it. Day: the yellow-green that sells sunshine. Fog: dew-grey.
	"bark": Color("#8A6A4C"), # Trunks at eye height; wooden buildings, fences, signposts.
	"granite": Color("#7D7F79"), # Boulders, runestones, cliff faces, the mountain (berget).
	"lichen": Color("#C9D0CE"), # Pale lichen crust on rock. In fog this is rime and frost.
	"soil": Color("#A9835A"), # Paths, needle litter, roots, exposed earth.
	"sky": Color("#92B8E3"), # Clear sky. Day horizon lightens to #B5D2EE. Fog dusk shifts to violet #6F6A85.
	"water": Color("#5D8DBE"), # The lake (sjön), tarns, bog pools.
	"lingon": Color("#B92A2F"), # Lingonberries. Also blood, madder-dyed cloth, and danger.
	"blueberry": Color("#566A91"), # Blueberries with their pale bloom; woad-dyed cloth; cold shadow tint.
	"heather": Color("#B487A8"), # Ljung in bloom on rock slabs and bog edges.
	# Accents (day only)
	"sun": Color("#E6C878"), # Golden sunlight: beams, rim light, hearth glow. Primary highlight for interactables and UI.
	"sun-core": Color("#FCF4DF"), # Sun disc, lens flare, the hottest point of any light.
	"tallbark": Color("#C98B56"), # Orange upper bark of Scots pine. Warm secondary accent; wood in firelight.
	# UI signals
	"text": Color("#EDEAE0"), # ramp.bright of each state
	"panel": Color("#2A2612"), # ramp.shadow of each state, at about 85% opacity
	"highlight": Color("#E6C878"), # sun in day, spirit in fog: interact prompts, selected item, quest marker
	"health": Color("#B92A2F"), # day lingon in both states so it stays readable; one of two saturation exceptions in fog
	"stamina": Color("#AEB055"), # day moss-lit in both states; the other saturation exception
}

## Fog (Dimma): The same forest with the other world showing through. One cold blue-slate ramp, near-black shadows, and a few saturated accents that are the only colour left.
const FOG: Dictionary = {
	# Ramp
	"deepest": Color("#0C0D0B"), # Deepest shadow: under boulders, tree hollows, cave mouths. Outlines.
	"shadow": Color("#1F211B"), # Shadow side of everything. Default dark for UI panels.
	"dark": Color("#3A3E3D"), # Shaded mid-tones: bark in shade, wet ground, dark cloth.
	"mid": Color("#626C7A"), # Neutral mid-tone. Undyed wool, weathered wood, plain stone.
	"light": Color("#99A4B3"), # Lit surfaces without a strong hue of their own.
	"bright": Color("#C9D0D8"), # Highest highlight. Day: cloud, lichen glare, sun on stone. Fog: the fog ceiling, rime.
	# Environment
	"canopy": Color("#22271A"), # Needle mass of pine and spruce in shade; distant treeline.
	"moss": Color("#3E4430"), # Forest-floor moss, ferns, blueberry leaves. The default green.
	"moss-lit": Color("#6E7558"), # Moss where light hits it. Day: the yellow-green that sells sunshine. Fog: dew-grey.
	"bark": Color("#58493A"), # Trunks at eye height; wooden buildings, fences, signposts.
	"granite": Color("#5A6267"), # Boulders, runestones, cliff faces, the mountain (berget).
	"lichen": Color("#A9B8C4"), # Pale lichen crust on rock. In fog this is rime and frost.
	"soil": Color("#494B45"), # Paths, needle litter, roots, exposed earth.
	"sky": Color("#7B8696"), # Clear sky. Day horizon lightens to #B5D2EE. Fog dusk shifts to violet #6F6A85.
	"water": Color("#46525F"), # The lake (sjön), tarns, bog pools.
	"lingon": Color("#7A3A34"), # Lingonberries. Also blood, madder-dyed cloth, and danger.
	"blueberry": Color("#4F5C80"), # Blueberries with their pale bloom; woad-dyed cloth; cold shadow tint.
	"heather": Color("#6B5B7A"), # Ljung in bloom on rock slabs and bog edges.
	# Accents (fog only)
	"spirit": Color("#C2DAE8"), # Translucent spirit bodies, active runes, the cold light of the fog state. UI highlight in fog.
	"wisp": Color("#EAF5FC"), # Wisp cores, spirit eyes, hottest highlight in fog.
	"rune": Color("#7E4F31"), # Rust-ochre carvings in stone, old iron, dried blood.
	"ember": Color("#E39A4C"), # Lantern, cairn fire, torch. The only warm light in fog: reserve it for safety and for light the player or the village made.
	"dusk": Color("#D4A78E"), # Peach band at the horizon when the fog rolls in at sunset.
	# UI signals
	"text": Color("#C9D0D8"), # ramp.bright of each state
	"panel": Color("#1F211B"), # ramp.shadow of each state, at about 85% opacity
	"highlight": Color("#C2DAE8"), # sun in day, spirit in fog: interact prompts, selected item, quest marker
	"health": Color("#B92A2F"), # day lingon in both states so it stays readable; one of two saturation exceptions in fog
	"stamina": Color("#AEB055"), # day moss-lit in both states; the other saturation exception
}


## The colour of role [param name] in [param state] (a WorldState.State value).
## The accents are not paired: a role that only one state has is returned from that
## state whichever one is asked for, so the fog accents can be read while it is day.
## A role that neither state has returns MISSING and pushes an error.
static func role(name: StringName, state: int) -> Color:
	var in_fog: bool = state == WorldState.State.FOG
	var table: Dictionary = FOG if in_fog else DAY
	if table.has(name):
		return table[name]
	var other: Dictionary = DAY if in_fog else FOG
	if other.has(name):
		return other[name]
	push_error("Palette: unknown role '%s'" % name)
	return MISSING
