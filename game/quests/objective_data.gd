class_name ObjectiveData
extends Resource
## One objective of a quest: what counts toward it, and how many times. QuestManager does
## the counting; its class comment has the rules.
##
## [member type] picks the rule and the filters narrow it. A filter that is left empty, or
## on ANY, lets everything through.

## What an objective counts.
enum Type {
	## Enemies that die and pass every filter that is set: [member enemy_id],
	## [member enemy_animal], [member enemy_category] and [member zone_id].
	KILL,
	## The boss [member boss_id] being defeated.
	BOSS,
	## How many of [member item_id] the player holds. It follows the inventory, so it goes
	## down again when items leave it.
	COLLECT,
	## The player walking into the quest trigger [member marker_id], or entering the zone
	## [member zone_id].
	REACH,
	## Handing [member target_count] of [member item_id] to the NPC [member npc_id], who
	## keeps them.
	DELIVER,
	## Cairns being lit, in the zone [member zone_id] when one is set.
	LIGHT_CAIRNS,
}

## The animals an enemy can be, for [member enemy_animal]. The values are those of
## EnemyData's animal enum (J07) and have to stay equal to them; ANY leaves the filter off.
enum Animal { ANY = -1, BOAR, WOLF, BEAR, RAVEN, SQUIRREL, FOX, HUMAN, TROLL }

## The kinds of enemy, for [member enemy_category]. The values are those of EnemyData's
## category enum (J07) and have to stay equal to them; ANY leaves the filter off.
enum Category { ANY = -1, NEUTRAL, POSSESSED }

## The rule this objective follows.
@export var type: Type = Type.KILL
## The line the journal shows, "Kill possessed foxes" for one. The count is added to it.
@export var description: String = ""
## How many it takes. An objective that is a single event, such as BOSS or REACH, keeps 1.
@export var target_count: int = 1

@export_group("Filters")
## KILL: the id of the enemy's EnemyData.
@export var enemy_id: StringName = &""
## KILL: the enemy's animal.
@export var enemy_animal: Animal = Animal.ANY
## KILL: neutral or possessed.
@export var enemy_category: Category = Category.ANY
## KILL and LIGHT_CAIRNS: the zone it has to happen in. REACH: the zone to enter.
@export var zone_id: StringName = &""
## BOSS: the id that boss_defeated carries.
@export var boss_id: StringName = &""
## COLLECT and DELIVER: the item.
@export var item_id: StringName = &""
## REACH: the marker id of the QuestTrigger to walk into.
@export var marker_id: StringName = &""
## DELIVER: the NPC who takes the items.
@export var npc_id: StringName = &""

@export_group("Order and hooks")
## The objective stays out of the journal, and counts nothing, until the objective before
## it in the list is finished. Set it on every objective but the first to put them in order.
@export var hidden_until_previous: bool = false
## A story flag set the moment this objective finishes, once per run of the quest.
@export var on_complete_flag: StringName = &""
## A scripted scene asked for through scene_requested the moment this objective finishes,
## once per run of the quest.
@export var on_complete_scene: StringName = &""


## How many it takes to finish the objective: [member target_count], and never under 1.
func get_target() -> int:
	return maxi(target_count, 1)


## What the objective lacks to ever be finished, as a sentence, or an empty string when it
## is sound: the filter its type cannot do without.
func get_problem() -> String:
	match type:
		Type.BOSS:
			if boss_id == &"":
				return "a BOSS objective needs boss_id"
		Type.COLLECT:
			if item_id == &"":
				return "a COLLECT objective needs item_id"
		Type.REACH:
			if marker_id == &"" and zone_id == &"":
				return "a REACH objective needs marker_id or zone_id"
		Type.DELIVER:
			if item_id == &"" or npc_id == &"":
				return "a DELIVER objective needs item_id and npc_id"
	return ""
