@echo off
rem Runs the GUT unit tests under res://test/unit headless. Exit code 0 means every test passed.
"C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0..\game" -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit %*
exit /b %ERRORLEVEL%
