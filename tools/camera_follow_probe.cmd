@echo off
rem Measures how steadily the camera rig follows the walking player at 30, 60 and 144 fps, headless. Exit code 0 means steady at all three. game\README.md, Camera rig, says more.
setlocal
set NOT_STEADY=0
for %%F in (30 60 144) do "C:\Users\filip\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --no-header --fixed-fps %%F --path "%~dp0..\game" -s "%~dp0camera_follow_probe.gd" %* || set NOT_STEADY=1
exit /b %NOT_STEADY%
