class_name QuestRewards
extends Resource
## What completing a quest pays. QuestManager.complete() hands it out.

## Experience, announced on xp_gained.
@export var xp: int = 0
## Silver put into the inventory.
@export var silver: int = 0
## Ids of the items put into the inventory, one each. Name an id twice for two of it.
@export var item_ids: Array[StringName] = []
## Story flags set through GameState.
@export var flags: Array[StringName] = []
