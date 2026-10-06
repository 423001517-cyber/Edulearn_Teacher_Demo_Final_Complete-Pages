@echo off
rem EduLearn - opens the ADMIN website in Chrome (usually http://localhost:5100).
rem If port 5100 is busy (the website is probably already open in another
rem window), the next free port up to 5109 is used instead.
cd /d "%~dp0apps\admin_web"
title EduLearn - Admin website

set PORT=5100
:findport
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if errorlevel 1 goto portfree
echo Port %PORT% is already in use - is the admin website already open in another window?
set /a PORT+=1
if %PORT% GTR 5109 goto noport
goto findport

:noport
echo.
echo Ports 5100-5109 are all busy. Close the other EduLearn website windows
echo (or restart your computer) and try again.
pause
exit /b 1

:portfree
echo Opening the admin website at http://localhost:%PORT%
call flutter run -d chrome --web-port %PORT%
pause
