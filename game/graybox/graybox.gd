class_name Graybox
extends RefCounted
## The gray-box placeholder kit: size classes, the kit materials and box builders.
## Every placeholder in the game goes through here, so the art pass has one place to swap.

## Placeholder size classes from the gdd placeholder policy.
enum SizeClass { PLAYER, SMALL, MEDIUM, LARGE, BOSS, TROLL }

## Box dimensions (width, height, depth) in metres per size class.
const SIZES: Dictionary = {
	SizeClass.PLAYER: Vector3(0.8, 1.8, 0.8),
	SizeClass.SMALL: Vector3(0.5, 0.5, 0.5),
	SizeClass.MEDIUM: Vector3(1.0, 1.0, 1.0),
	SizeClass.LARGE: Vector3(1.6, 1.6, 1.6),
	SizeClass.BOSS: Vector3(2.5, 2.5, 2.5),
	SizeClass.TROLL: Vector3(4.0, 4.0, 4.0),
}

## Side of a BoxActor nose box as a fraction of its body width.
const NOSE_FRACTION := 0.25
## Height of the nose box centre as a fraction of the body height.
const NOSE_HEIGHT_FRACTION := 0.75

## Palette day ramp mid: the default for every box.
const MAT_GRAY: Material = preload("res://graybox/mat_gray.tres")
## Palette fog lichen: possessed creatures.
const MAT_FROST: Material = preload("res://graybox/mat_frost.tres")
## Palette day sun: interactable and highlighted things.
const MAT_HIGHLIGHT: Material = preload("res://graybox/mat_highlight.tres")
## Rarity tints for ground items (gdd, Loot and equipment): ramp light, moss-lit, sky, sun.
const MAT_RARITY_COMMON: Material = preload("res://graybox/mat_rarity_common.tres")
const MAT_RARITY_FINE: Material = preload("res://graybox/mat_rarity_fine.tres")
const MAT_RARITY_RARE: Material = preload("res://graybox/mat_rarity_rare.tres")
const MAT_RARITY_LEGENDARY: Material = preload("res://graybox/mat_rarity_legendary.tres")


## The body dimensions of [param size_class].
static func size_of(size_class: SizeClass) -> Vector3:
	return SIZES[size_class]


## A BoxMesh of [param size] with [param material].
static func make_box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


## A MeshInstance3D holding a BoxMesh of [param size] with [param material], centred on its origin.
static func make_box(size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = make_box_mesh(size, material)
	return instance
