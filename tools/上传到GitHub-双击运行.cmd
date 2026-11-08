@echo off
setlocal EnableExtensions
set "HDM_ZIP=%USERPROFILE%\Downloads\headless-desktop-manager-v4.4.2.zip"
set "HDM_EXTRACT=%TEMP%\hdm-upload-v4.4.2"
if not exist "%HDM_ZIP%" (
  echo ERROR: Download headless-desktop-manager-v4.4.2.zip into your Downloads folder.
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\headless-desktop-manager-v4.4.2.zip') -DestinationPath (Join-Path $env:TEMP 'hdm-upload-v4.4.2') -Force"
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%HDM_EXTRACT%\headless-desktop-manager\tools\publish-windows.ps1"
exit /b %ERRORLEVEL%
