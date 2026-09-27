@echo off
rem EduLearn - one-time setup. Double-click this file.
cd /d "%~dp0"
echo === EduLearn setup - run this once ===
echo.
where flutter >nul 2>nul || (echo Flutter is not installed or not on PATH. See START_HERE.md & pause & exit /b 1)
where node >nul 2>nul || (echo Node.js is not installed. See START_HERE.md & pause & exit /b 1)
where java >nul 2>nul || (echo Java 21 is not installed. See START_HERE.md & pause & exit /b 1)

echo [1/5] Installing the Firebase command-line tools...
call npm install -g firebase-tools || goto :fail

echo [2/5] Getting Flutter packages for the teacher and admin websites...
call flutter pub get || goto :fail

echo [3/5] Installing and building the Cloud Functions...
pushd firebase\functions
call npm install || (popd & goto :fail)
call npm run build || (popd & goto :fail)
popd

echo [4/5] Installing the demo data tool...
pushd tools\seed
call npm install || (popd & goto :fail)
popd

echo [5/5] Adding the android, ios, windows, macos and linux folders...
call "%~dp0add-platform-folders.bat" nopause || goto :fail

echo.
echo Setup finished. Next: double-click 2-start-firebase.bat
pause
exit /b 0

:fail
echo.
echo Setup stopped because of the error above.
pause
exit /b 1
