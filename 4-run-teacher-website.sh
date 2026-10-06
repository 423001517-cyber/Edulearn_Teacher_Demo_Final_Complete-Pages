#!/usr/bin/env bash
# EduLearn - opens the TEACHER website in Chrome (usually http://localhost:5050).
# If port 5050 is busy (the website is probably already open in another
# terminal), the next free port up to 5059 is used instead.
cd "$(dirname "$0")/apps/teacher_web" || exit 1
in_use() {
  if command -v lsof >/dev/null 2>&1; then lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; fi
}
PORT=5050
while in_use "$PORT"; do
  echo "Port $PORT is already in use - is the teacher website already open in another terminal?"
  PORT=$((PORT + 1))
  if [ "$PORT" -gt 5059 ]; then
    echo "Ports 5050-5059 are all busy. Close the other EduLearn website terminals and try again."
    exit 1
  fi
done
echo "Opening the teacher website at http://localhost:$PORT"
flutter run -d chrome --web-port "$PORT"
