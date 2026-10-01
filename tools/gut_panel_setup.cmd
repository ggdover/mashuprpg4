@echo off
rem Points the GUT editor panel at res://test/unit. Run once per machine with the editor closed; game\README.md says why.
"C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0..\game" -s "%~dp0gut_panel_setup.gd" %*
exit /b %ERRORLEVEL%
