@echo off
rem EduLearn - starts Firebase on your computer (login, database, files, functions).
rem KEEP THIS WINDOW OPEN while you use the websites. Stop it with Ctrl+C
rem (that also saves the demo data for next time).
cd /d "%~dp0"
title EduLearn - Firebase (keep this window open)

pushd firebase\functions
call npm run build || (popd & pause & exit /b 1)
popd

set IMPORT=
if exist ".emulator-data\firebase-export-metadata.json" set IMPORT=--import=.emulator-data
rem Loading the Cloud Functions can take longer than Firebase's default 10 s
rem on Windows (antivirus scans node_modules the first time) - allow 60 s.
set FUNCTIONS_DISCOVERY_TIMEOUT=60
rem Only what the apps use (the websites themselves are served by Flutter).
call firebase emulators:start --project demo-edulearn --only auth,firestore,functions,storage %IMPORT% --export-on-exit=.emulator-data
pause
