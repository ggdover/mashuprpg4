extends Node
## Saving and loading the whole game as JSON in [code]user://saves/[/code]. Empty until J19.
##
## [method load] shadows the global [code]load()[/code] inside this script only; use
## [code]ResourceLoader.load()[/code] here if a resource ever needs loading.


## Writes the current game to disk. Returns [code]false[/code] until J19 implements it.
func save() -> bool:
	return false


## Restores a game from disk. Returns [code]false[/code] until J19 implements it.
func load() -> bool:
	return false
