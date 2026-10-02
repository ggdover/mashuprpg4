class_name DodgeRequest
extends RefCounted
## What [signal Player.dodge_requested] carries. A signal cannot hand a value back, so a
## listener that has to stop the dodge calls [method deny] on the request instead; the
## player reads [member allowed] once every listener has run.

## Whether the dodge may start. True until a listener denies it.
var allowed: bool = true


## Stops the dodge this request belongs to.
func deny() -> void:
	allowed = false
