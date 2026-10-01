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


func test_role_falls_back_to_fog_for_fog_only_roles() -> void:
	assert_eq(Palette.role(&"ember", WorldState.State.DAY), Palette.FOG["ember"])


func test_every_role_resolves_in_both_states() -> void:
	for state: int in [WorldState.State.DAY, WorldState.State.FOG]:
		for table: Dictionary in [Palette.DAY, Palette.FOG]:
			for role_name: String in table:
				assert_ne(Palette.role(role_name, state), Palette.MISSING, "%s in state %d" % [role_name, state])
