class_name QuestTestNpc
extends Node3D
## A stand-in NPC for the quest test scene: a box with an NPC id. J16 brings the real NPCs
## and the dialogue box, which puts the same questions to QuestManager.

## The id quests know the NPC by. The test chain's giver and turn-in NPC is "test_npc".
@export var npc_id: StringName = &"test_npc"


## What a talk does while there is no dialogue: the NPC takes every delivery and turn-in
## the player has for it, then the player accepts every quest the NPC offers.
func talk() -> void:
	for quest: QuestData in QuestManager.turn_ins_for_npc(npc_id):
		QuestManager.try_turn_in(quest.id, npc_id)
	for quest: QuestData in QuestManager.available_for_npc(npc_id):
		QuestManager.start(quest.id)
