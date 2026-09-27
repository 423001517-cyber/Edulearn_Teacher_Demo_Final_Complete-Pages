#!/usr/bin/env bash
# EduLearn - opens the ADMIN website in Chrome (http://localhost:5100).
cd "$(dirname "$0")/apps/admin_web" && flutter run -d chrome --web-port 5100
