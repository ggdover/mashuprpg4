extends Node
## Central signal hub: every cross-system event is declared here, so systems never
## wire to each other directly. Later jobs add their signals to this one list.
## Every parameter carries a type; write [code]Variant[/code] where anything goes.
##
## Emit with [code]EventBus.enemy_died.emit(enemy)[/code]; listen with
## [code]EventBus.enemy_died.connect(_on_enemy_died)[/code].

@warning_ignore_start("unused_signal")

## An enemy reached zero health. [param enemy] is the enemy's root node.
signal enemy_died(enemy: Node)
## The player reached zero health.
signal player_died
## The player picked an item up. [param item] stays a Variant until J06 decides what it carries.
signal item_picked_up(item: Variant)
## A quest that is under way changed: it started, an objective moved, it became ready to
## turn in, it completed. The journal redraws on this signal alone.
signal quest_updated(quest_id: StringName)
## A quest was completed and its rewards handed out.
signal quest_completed(quest_id: StringName)
## A quest became active.
signal quest_started(quest_id: StringName)
## One objective of an active quest moved, up or down. [param index] is its place in
## QuestData.objectives.
signal quest_objective_progress(quest_id: StringName, index: int, current: int, target: int)
## The player walked into a QuestTrigger. [param id] is the trigger's marker id.
signal marker_reached(id: StringName)
## A quest or one of its objectives asks for a scripted scene. J17's scene runner plays it.
signal scene_requested(scene_id: StringName)
## The player earned experience: a quest reward, and from J07 on a kill. J10 listens.
signal xp_gained(amount: int)
## GameState set a story flag for the first time.
signal flag_set(flag: StringName)
## WorldState switched state. [param state] is a WorldState.State value.
signal world_state_changed(state: int)
## WorldState.request_fog brought the fog. [param reason] says who asked:
## [code]&"random"[/code] for a roll at zone entry, otherwise a name the caller chose, such
## as the story flag [code]&"FOG_1"[/code].
signal fog_started(reason: StringName)
## WorldState.end_fog took the fog away.
signal fog_ended
## The horn sounds from the village: at every fog start outside a dungeon.
signal horn_sounded
## The player lit a cairn. [param cairn] is the Cairn node.
signal cairn_lit(cairn: Node3D)
## The player entered a zone.
signal zone_entered(zone_id: StringName)
## A dialogue with an NPC opened.
signal dialogue_started(npc_id: StringName)
## A dialogue with an NPC closed.
signal dialogue_ended(npc_id: StringName)

@warning_ignore_restore("unused_signal")
