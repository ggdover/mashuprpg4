class_name StateVisibility
extends Node
## Shows its parent in the states of the forest it is told to and hides it in the others.
## Give one to anything that only exists in one state: a day signpost, a fog signpost, a
## landmark the fog swallows, a path that is only there in fog.
##
## What is hidden does not collide either: every CollisionShape3D under the parent is
## disabled while it is not drawn, the parent's own shapes and those further down alike. So
## one StateVisibility on a group hides the whole group, and a group may hold things with a
## StateVisibility of their own: a shape collides only while everything above it is shown.
## Both are set when the node becomes ready and whenever the state changes.

## Whether the parent exists by day.
@export var day := true:
	set(value):
		day = value
		_apply_if_ready()
## Whether the parent exists in fog.
@export var fog := true:
	set(value):
		fog = value
		_apply_if_ready()


func _ready() -> void:
	EventBus.world_state_changed.connect(_on_world_state_changed)
	apply()


## Whether the parent is shown in [param state], a WorldState.State value.
func is_shown_in(state: int) -> bool:
	return fog if state == WorldState.State.FOG else day


## Shows or hides the parent for the current state and switches the collision shapes under
## it to match. The shapes change at the end of the frame, because a state change may arrive
## from inside a physics callback, where a shape must not be switched.
func apply() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		push_warning("StateVisibility '%s' needs a Node3D parent to show and hide." % get_path())
		return
	parent.visible = is_shown_in(WorldState.state)
	for node: Node in parent.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		shape.set_deferred(&"disabled", not shape.is_visible_in_tree())


func _apply_if_ready() -> void:
	if is_node_ready():
		apply()


func _on_world_state_changed(_state: int) -> void:
	apply()
