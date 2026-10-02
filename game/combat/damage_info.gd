class_name DamageInfo
extends RefCounted
## One hit on its way to a [Health]: how much damage of each type, who dealt it and what
## else it carries. The attacker builds the packet, critical hit included, and the target's
## Health takes armor and frost resistance off.

## Physical damage before the target's armor.
var physical: float = 0.0
## Frost damage before the target's frost resistance.
var frost: float = 0.0
## The actor that dealt the hit: its root node, or null when nobody did. The actor may be
## freed before the hit lands; what [Health] hands on then names nobody.
var source: Node = null
## Whether the hit is a critical one. The amounts already hold the crit multiplier.
var is_crit: bool = false
## Push on the target in m/s, in world space. J20 applies it.
var knockback: Vector3 = Vector3.ZERO
## Status effects the hit puts on the target if it lands.
var effects: Array[StatusEffectData] = []
## The skill that made the hit. A tick of a status effect carries "status:" and the id of
## the effect here, see [method StatusEffectManager.is_tick].
var skill_id: StringName = &""


## Physical and frost together, before mitigation.
func total() -> float:
	return physical + frost


## A packet with the same content. The copy has its own [member effects] array, so
## changing one packet leaves the other alone. A [member source] that has been freed since
## the packet was built, an archer whose arrow is still in the air, is null in the copy.
func copy() -> DamageInfo:
	var packet := DamageInfo.new()
	packet.physical = physical
	packet.frost = frost
	if is_instance_valid(source):
		packet.source = source
	packet.is_crit = is_crit
	packet.knockback = knockback
	packet.effects = effects.duplicate()
	packet.skill_id = skill_id
	return packet


## Builds the packet for a hit by the owner of [param attacker_stats]. Both base amounts are
## multiplied by [param multiplier] (the skill's), the physical one also by
## 1 + physical_bonus. Then the crit is rolled: with a chance of crit_chance both amounts
## are multiplied by crit_multiplier, which counts as 1 while it is lower, so a crit never
## lowers a hit. Without stats the packet holds the base amounts times the multiplier.
static func from_stats(attacker_stats: StatBlock, base_physical: float, base_frost: float, multiplier: float) -> DamageInfo:
	var packet := DamageInfo.new()
	packet.physical = base_physical * multiplier
	packet.frost = base_frost * multiplier
	if attacker_stats == null:
		return packet
	packet.physical *= 1.0 + attacker_stats.get_stat(StatBlock.PHYSICAL_BONUS)
	packet.is_crit = randf() < attacker_stats.get_stat(StatBlock.CRIT_CHANCE)
	if packet.is_crit:
		var crit_multiplier := maxf(attacker_stats.get_stat(StatBlock.CRIT_MULTIPLIER), 1.0)
		packet.physical *= crit_multiplier
		packet.frost *= crit_multiplier
	return packet
