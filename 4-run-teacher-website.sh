#!/usr/bin/env bash
# EduLearn - opens the TEACHER website in Chrome (http://localhost:5050).
cd "$(dirname "$0")/apps/teacher_web" && flutter run -d chrome --web-port 5050
