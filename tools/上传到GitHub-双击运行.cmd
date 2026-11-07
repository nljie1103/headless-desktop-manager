@echo off
setlocal
set "HDM_ZIP=%USERPROFILE%\Downloads\headless-desktop-manager-v0.1.1.zip"
set "HDM_EXTRACT=%TEMP%\hdm-upload-v0.1.1"
if not exist "%HDM_ZIP%" (
  echo ERROR: File not found: "%HDM_ZIP%"
  echo Download the v0.1.1 ZIP to the Windows Downloads folder.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\headless-desktop-manager-v0.1.1.zip') -DestinationPath (Join-Path $env:TEMP 'hdm-upload-v0.1.1') -Force"
if errorlevel 1 (
  echo ERROR: Unzip failed.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%HDM_EXTRACT%\headless-desktop-manager\tools\publish-windows.ps1"
if errorlevel 1 (
  echo Upload was not completed successfully.
  pause
  exit /b 1
)
echo Upload process finished.
pause
endlocal
