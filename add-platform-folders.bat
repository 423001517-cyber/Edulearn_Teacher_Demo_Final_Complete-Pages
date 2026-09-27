@echo off
rem EduLearn - adds the android, ios, windows, macos and linux folders (plus
rem Flutter's usual .idea / .metadata files) to the teacher and admin apps,
rem made by YOUR Flutter version. Code in lib\, web\ and test\ is kept as is.
cd /d "%~dp0"
where flutter >nul 2>nul || (echo Flutter is not installed or not on PATH. See START_HERE.md & pause & exit /b 1)

echo Adding platform folders to the teacher website...
pushd apps\teacher_web
call flutter create . --org ph.edulearn --project-name teacher_web --platforms=android,ios,web,windows,macos,linux || (popd & goto :fail)
popd

echo.
echo Adding platform folders to the admin website...
pushd apps\admin_web
call flutter create . --org ph.edulearn --project-name admin_web --platforms=android,ios,web,windows,macos,linux || (popd & goto :fail)
popd

echo.
echo Done. apps\teacher_web and apps\admin_web now have android, ios, windows, macos and linux folders.
if not "%1"=="nopause" pause
exit /b 0

:fail
echo.
echo Stopped because of the error above.
if not "%1"=="nopause" pause
exit /b 1
