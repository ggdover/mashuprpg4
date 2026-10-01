extends Node
## Which of the two forest states is active. J11 adds the triggers, the presets and the rest.

## The two states of the forest. Values are what [signal EventBus.world_state_changed] carries.
enum State { DAY, FOG }

## The active state. Assigning a different value emits [signal EventBus.world_state_changed];
## assigning the same value again does nothing.
var state: State = State.DAY:
	set(value):
		if value == state:
			return
		state = value
		EventBus.world_state_changed.emit(state)
