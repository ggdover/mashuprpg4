@echo off
rem Opens the mashuprpg4 project in the Godot editor. Extra arguments are passed to Godot.
"C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0..\game" --editor %*
