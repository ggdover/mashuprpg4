# J06: Items, inventory, equipment and loot generation

**Milestone:** M3 · **Depends on:** J03 · **Unblocks:** J10, J16, J18, J19
**Reads first:** `design/gdd.md` §Loot and equipment, §Placeholder policy; `design/quests_act1.md` (quest items and rewards); `design/palette.md` §UI signals

## Goal

A full loot system: base items and affixes as data, generated item instances with rarity, loot tables, an inventory grid, eight equipment slots that feed the stat block, ground drops with pickup, and a working inventory and equipment screen.

## Deliverables

- `game/items/item_data.gd`, `affix_data.gd`, `item_instance.gd`, `item_generator.gd`, `loot_table.gd`, `inventory.gd`, `equipment.gd`
- `game/items/world_item.tscn` and `world_item.gd`
- `game/items/loot_dropper.gd` (static helper: roll a table and spawn world items at a position)
- `game/player/interactor.gd`: nearest interactable within 2 m, prompt text, `interact` action
- `game/data/items/*.tres` (about 30 bases), `game/data/affixes/*.tres` (8), `game/data/loot/*.tres` (a default table, an elite table, a boss table)
- `game/ui/inventory/inventory_screen.tscn` with grid, equipment slots, tooltip
- `game/test/test_loot.tscn`
- GUT tests in `game/test/unit/test_items.gd`

## Spec

**ItemData** (base definition). `id`, `display_name`, `slot` enum WEAPON, HEAD, CHEST, HANDS, FEET, RING, AMULET, CONSUMABLE, MATERIAL, QUEST, `weapon: WeaponData` (weapons only), `implicit_modifiers: Array` of `{stat, flat, percent}`, `item_level_min/max`, `stack_max` (1 for gear), `allowed_rarities`, `sell_value`, `use_effect: StatusEffectData` (consumables), `unique: bool` (never rolls affixes, fixed stats).

**AffixData.** `id`, `display_name`, `is_prefix`, `stat`, `is_percent`, `tiers: Array` of `{min_item_level, value_min, value_max}`, `allowed_slots`, `weight`.

**ItemInstance.** Serialisable to and from a `Dictionary`: `uid`, `base_id`, `rarity` enum COMMON, FINE, RARE, LEGENDARY, `item_level`, `affixes: Array` of `{id, value}`, `count`. Helpers `display_name()` (prefix + base + suffix), `all_modifiers()` (implicit plus affixes), `rarity_color()` from the palette mapping in the gdd.

**ItemGenerator.** `generate(base: ItemData, item_level: int, rarity) -> ItemInstance`: pick affix count by rarity (0, 1, 2, 3), draw affixes by weight without repeats, at most one prefix and two suffixes, pick the highest tier whose `min_item_level` fits, roll the value. `roll_rarity(weights)` helper. Uniques ignore all of this.

**LootTable.** `entries: Array` of `{base_id or slot, weight, count_min, count_max}`, `rarity_weights: Dictionary`, `min_rarity`, `silver_min/max`, `drop_chance`. `roll(item_level) -> Dictionary` with `items: Array[ItemInstance]` and `silver: int`. Boss table has `min_rarity = RARE` and `drop_chance = 1`.

**Inventory.** 48 slots plus a quest tab. `add(instance) -> bool` (stacks first, then first empty), `remove`, `move(from, to)`, `split`, `silver: int`. Quest items go to the quest tab and cannot be dropped or sold. Emits `changed`.

**Equipment.** Eight slots. `equip(instance)` validates the slot, swaps the previous item back into the inventory, applies `all_modifiers()` to the player's StatBlock under source `&"equip:" + slot`, and for WEAPON calls `Player.equip_weapon`. `unequip(slot)`. Emits `changed`.

**World items.** `world_item.tscn`: 0.3 m box tinted by rarity, `Label3D` with the display name, Area3D on layer 10. Silver is a separate small box that auto-picks up on player contact. `Interactor` finds the nearest item and shows "E: pick up <name>"; picking up calls `Inventory.add` and emits `EventBus.item_picked_up`. Full inventory leaves the item on the ground with a message.

**LootDropper.** `drop(table: LootTable, item_level: int, position: Vector3)` spawns each item scattered within 1 m. J07 calls it on enemy death.

**Data to author.** Weapons: each of the six types at item levels 1, 5, 10, 15. Armor: two bases per slot (light and heavy naming). Rings and amulets: one base each. Consumables: brew. Materials: boar meat, wolf pelt, bear hide, tallow, goldieflower, ruined hide. Quest: rune rubbing, unmelting shard, the old lady's lantern. Uniques: winter coat (chest, frost_resistance +60 flat, max_health +10%), the bell (QUEST, referenced by flag), the lantern (QUEST). Affixes: physical_bonus, max_health, armor, frost_resistance, move_speed, attack_speed, crit_chance, max_stamina.

**Inventory screen.** Toggled by `inventory`. Left: 8 equipment slots as boxes with the item name. Right: 8 × 6 grid. Click to select, click a slot to move, double-click to equip or use, right-click to drop. Tooltip on hover: name in rarity colour, item level, every modifier line, sell value. Use the palette UI signals through `Palette.role` for text, panel and highlight of the current world state. Keep it plain; J18 restyles.

**Tests.** Rarity roll distribution within 5% of weights over 10 000 rolls, affix count per rarity, no duplicate affixes, tier selection by item level, stacking to `stack_max`, equip rejects wrong slot, equip then unequip leaves StatBlock unchanged.

## Acceptance criteria

- [ ] Killing a dummy in the test scene (via a debug key) drops items and silver that can be picked up
- [ ] Equipping a weapon changes the player's attacks; equipping armor changes stats visibly in the tooltip and in the StatBlock
- [ ] Rarity colours match the gdd mapping
- [ ] Quest items cannot be dropped or sold
- [ ] GUT tests pass, editor loads clean

## Out of scope

Vendors (J16). Character sheet (J10). HUD restyle (J18). Save format (J19), but keep `ItemInstance.to_dict()` and `from_dict()` working.

## Notes for later jobs

- J07 calls `LootDropper.drop` with the enemy's table and item level from `EnemyData`.
- J19 serialises `Inventory` and `Equipment` through `ItemInstance.to_dict()`.

## Deviations

(none yet)
