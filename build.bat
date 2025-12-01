@echo off
ml64 animation.asm /link /subsystem:windows /entry:WinMain kernel32.lib user32.lib gdi32.lib
pause
