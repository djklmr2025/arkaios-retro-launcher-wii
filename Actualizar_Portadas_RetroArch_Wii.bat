@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-RetroArchWiiMedia.ps1" -WiiRoot "D:\" -SyncThumbnails -CreatePlaylists -CreateCatalog
pause
