@echo off
rem EduLearn - loads the demo classes, students, teachers and admin.
rem Run it while 2-start-firebase.bat is running.
cd /d "%~dp0tools\seed"
set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
node seed.mjs --reset --project demo-edulearn
echo.
echo Teacher website sign-in: jean@edulearn.test / edulearn123
echo Admin website sign-in:   admin@edulearn.test / edulearn123
pause
