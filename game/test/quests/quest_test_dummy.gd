class_name QuestTestDummy
extends Node3D
## A stand-in enemy for the quest test scene: a box that goes down when the player
## interacts with it and announces that on enemy_died, the way J07's Enemy will. It stands
## up again when its Respawn timer runs out, so the scene never runs short of dummies.
##
## It carries what the quest system reads from an enemy: [member data] with the id, and
## [member zone_id].

## The id in the dummy's data. Quest A counts "test_dummy".
@export var enemy_id: StringName = &"test_dummy"
## The name over the box.
@export var label_text := "Test dummy"

## Stands in for J07's EnemyData.
var data := Data.new()
## The zone the dummy stands in. Left empty, the zone the player is in counts.
var zone_id: StringName = &""

@onready var _label: Label3D = $Label
@onready var _respawn: Timer = $Respawn


func _ready() -> void:
	data.id = enemy_id
	_label.text = label_text
	_respawn.timeout.connect(show)


## Whether the dummy stands. One that is down waits for its respawn.
func is_alive() -> bool:
	return visible


## Knocks the dummy down and announces its death.
func die() -> void:
	if not is_alive():
		return
	hide()
	_respawn.start()
	EventBus.enemy_died.emit(self)


## What a kill objective reads of an enemy's data, as far as the test chain needs it.
class Data:
	extends RefCounted

	var id: StringName = &""
