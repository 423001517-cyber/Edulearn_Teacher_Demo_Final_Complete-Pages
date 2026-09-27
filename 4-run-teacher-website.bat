@echo off
rem EduLearn - opens the TEACHER website in Chrome (http://localhost:5050).
cd /d "%~dp0apps\teacher_web"
title EduLearn - Teacher website
call flutter run -d chrome --web-port 5050
pause
