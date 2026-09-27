@echo off
rem EduLearn - opens the ADMIN website in Chrome (http://localhost:5100).
cd /d "%~dp0apps\admin_web"
title EduLearn - Admin website
call flutter run -d chrome --web-port 5100
pause
