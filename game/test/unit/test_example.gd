extends GutTest
## J01 example test: the generated palette loads and holds the roles the kit needs.


func test_day_has_moss() -> void:
	assert_true(Palette.DAY.has("moss"), "Palette.DAY has the moss role")


func test_fog_has_moss() -> void:
	assert_true(Palette.FOG.has("moss"), "Palette.FOG has the moss role")


func test_role_reads_the_requested_state() -> void:
	assert_eq(Palette.role(&"moss", WorldState.State.FOG), Palette.FOG["moss"])


func test_role_falls_back_to_day_for_day_only_roles() -> void:
	assert_eq(Palette.role(&"sun", WorldState.State.FOG), Palette.DAY["sun"])
