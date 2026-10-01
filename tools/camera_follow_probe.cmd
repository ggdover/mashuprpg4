@echo off
rem Measures how steadily the camera rig follows the walking player at 30, 60 and 144 fps, headless. Exit code 0 means steady. game\README.md, Camera rig, says more.
"C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0..\game" -s "%~dp0camera_follow_probe.gd" %*
exit /b %ERRORLEVEL%
