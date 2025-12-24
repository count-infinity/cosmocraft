@echo off
echo Starting Cosmocraft Server and Client...
echo.

:: Start the server in headless mode (background)
start "Cosmocraft Server" "C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" res://server/main.tscn

:: Wait a moment for server to start
timeout /t 2 /nobreak >nul

:: Start the client with GUI
start "Cosmocraft Client" "C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "C:\develop\Cosmocraft" res://client/main.tscn

echo Server and Client started!
echo Close this window or press any key to exit.
pause >nul
