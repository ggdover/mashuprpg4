class_name QuestInventory
extends RefCounted
## What the quest system needs from the player's inventory: how many of an item the player
## holds, taking items for a delivery, and putting reward items and silver in.
##
## This class is a stand-in that keeps plain counts in memory, and QuestManager.inventory
## holds one of it from the start. J06 builds the real Inventory. The job that has both
## (J16) writes a subclass that overrides the four methods to go through that Inventory,
## emits [signal changed] whenever it changes, and assigns one to QuestManager.inventory.

## What the player holds changed. COLLECT objectives follow it.
signal changed

## Silver handed out by quests. The stand-in only keeps the sum.
var silver: int = 0

## How many of each item id the stand-in holds.
var _counts: Dictionary[StringName, int] = {}


## How many of [param item_id] the player holds.
func count_of(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


## Puts [param count] of [param item_id] in. Returns whether they went in; a full inventory
## is the reason they might not.
func add(item_id: StringName, count: int = 1) -> bool:
	if count <= 0:
		return false
	_counts[item_id] = count_of(item_id) + count
	changed.emit()
	return true


## Takes [param count] of [param item_id] out. Takes nothing and returns [code]false[/code]
## when the player holds fewer.
func remove(item_id: StringName, count: int = 1) -> bool:
	if count <= 0 or count_of(item_id) < count:
		return false
	_counts[item_id] = count_of(item_id) - count
	changed.emit()
	return true


## Gives the player [param amount] silver.
func add_silver(amount: int) -> void:
	silver += amount
