extends SceneTree
## Points the GUT editor panel at res://test/unit on this machine.
## Run it through tools\gut_panel_setup.cmd while the editor is closed.
##
## The panel keeps its settings in user://gut_temp_directory/gut_editor_config.json, outside
## the repository, and runs nothing while that file names no test directory. This loads the
## file with GUT's own config class, adds the directory and writes it back, so every other
## panel setting stays as it was. Running it again changes nothing.

## The directory the panel has to know: the one game/.gutconfig.json gives the command line.
const TEST_DIR := "res://test/unit"

const EXIT_OK := 0
const EXIT_FAILED := 1

## What the process exits with. It stays EXIT_FAILED when the setup stops on an error.
var _exit_code := EXIT_FAILED


func _initialize() -> void:
	if _set_up_panel():
		_exit_code = EXIT_OK


## Ends the run on the first frame whatever happened in [method _initialize], so that an
## error there cannot leave a headless Godot running.
func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


## Adds the test directory to the panel's config file. Returns false when it could not.
func _set_up_panel() -> bool:
	var version_conversion: GDScript = load("res://addons/gut/version_conversion.gd")
	if version_conversion.call("error_if_not_all_classes_imported"):
		print("GUT panel: nothing written. Import the project first: open the editor once,"
				+ " or run Godot with --headless --import.")
		return false

	# GUT's scripts are untyped and loaded by path, so their members are reached by name.
	# gut_loader goes first, as in GUT's own entry points: it keeps GDScript warnings off GUT.
	load("res://addons/gut/gut_loader.gd")
	var globals: GDScript = load("res://addons/gut/gui/editor_globals.gd")
	var config_script: GDScript = load("res://addons/gut/gut_config.gd")

	var path: String = globals.get("editor_run_gut_config_path")
	var file := ProjectSettings.globalize_path(path)
	globals.call("create_temp_directory")

	var config: RefCounted = config_script.new()
	config.call("load_options", path)
	var options: Dictionary = config.get("options")

	var changed := false
	for key: String in ["configured_dirs", "dirs"]:
		var dirs: Array = options[key]
		if not _lists_test_dir(dirs):
			dirs.append(TEST_DIR)
			changed = true
	if not options["include_subdirs"]:
		options["include_subdirs"] = true
		changed = true

	var what := "test directory %s (subdirectories included)" % TEST_DIR
	if not changed:
		print("GUT panel: %s was already set in %s" % [what, file])
		return true

	var result: Error = config.call("write_options", path)
	if result != OK:
		push_error("GUT panel: could not write %s (%s)" % [file, error_string(result)])
		return false
	print("GUT panel: %s written to %s" % [what, file])
	return true


## Whether [param dirs] holds the test directory, with or without a trailing slash.
func _lists_test_dir(dirs: Array) -> bool:
	for dir: Variant in dirs:
		if str(dir).trim_suffix("/") == TEST_DIR:
			return true
	return false
