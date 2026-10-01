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
## A quest's objective progress changed.
signal quest_updated(quest_id: StringName)
## A quest was turned in and completed.
signal quest_completed(quest_id: StringName)
## GameState set a story flag for the first time.
signal flag_set(flag: StringName)
## WorldState switched state. [param state] is a WorldState.State value.
signal world_state_changed(state: int)
## The player entered a zone.
signal zone_entered(zone_id: StringName)
## A dialogue with an NPC opened.
signal dialogue_started(npc_id: StringName)
## A dialogue with an NPC closed.
signal dialogue_ended(npc_id: StringName)

@warning_ignore_restore("unused_signal")
