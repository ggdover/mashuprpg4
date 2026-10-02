class_name LightPreset
extends Resource
## What a zone's DirectionalLight3D looks like in one state of the forest. The
## [EnvironmentController] tweens the light from one preset to the other when the state
## changes. The colours are palette roles, held as literal values because a resource cannot
## read a script constant; [code]test/unit/test_environment.gd[/code] checks them against
## [Palette].

## Colour of the light.
@export var color: Color = Color.WHITE
## Strength of the light.
@export_range(0.0, 4.0, 0.01) var energy: float = 1.0
## Angular size of the light in degrees. 0 gives shadows with hard edges; a few degrees
## soften them, the more the further the shadow falls from what casts it.
@export_range(0.0, 10.0, 0.1) var shadow_softness: float = 0.0
