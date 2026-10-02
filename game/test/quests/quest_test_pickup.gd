class_name QuestTestPickup
extends Node3D
## A stand-in ground item for the quest test scene: a small box that goes into the quest
## system's inventory when the player interacts with it, and can be dropped again. J06
## brings the real world items.

## The id of the item. Quest B collects "test_item".
@export var item_id: StringName = &"test_item"
## Side of the box in metres: the gdd's size for a ground item.
@export var box_side := 0.3


func _ready() -> void:
	var box := Graybox.make_box(Vector3.ONE * box_side, Graybox.MAT_RARITY_COMMON)
	box.position.y = box_side * 0.5
	add_child(box)


## Whether the item lies on the ground. One that was picked up waits to be dropped.
func is_on_ground() -> bool:
	return visible


## Takes the item off the ground and puts it into the inventory.
func pick_up() -> void:
	if not is_on_ground():
		return
	hide()
	QuestManager.inventory.add(item_id, 1)


## Puts the item back on the ground at [param place]. The caller takes it out of the inventory.
func drop_at(place: Vector3) -> void:
	global_position = place
	show()
