@echo off
rem Runs the game (main scene res://test/test_player.tscn) without the editor. Extra arguments are passed to Godot.
"C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0..\game" %*
