@echo off
rem EduLearn - opens the TEACHER website in Chrome (usually http://localhost:5050).
rem If port 5050 is busy (the website is probably already open in another
rem window), the next free port up to 5059 is used instead.
cd /d "%~dp0apps\teacher_web"
title EduLearn - Teacher website

set PORT=5050
:findport
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if errorlevel 1 goto portfree
echo Port %PORT% is already in use - is the teacher website already open in another window?
set /a PORT+=1
if %PORT% GTR 5059 goto noport
goto findport

:noport
echo.
echo Ports 5050-5059 are all busy. Close the other EduLearn website windows
echo (or restart your computer) and try again.
pause
exit /b 1

:portfree
echo Opening the teacher website at http://localhost:%PORT%
call flutter run -d chrome --web-port %PORT%
pause
