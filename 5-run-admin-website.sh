#!/usr/bin/env bash
# EduLearn - opens the ADMIN website in Chrome (usually http://localhost:5100).
# If port 5100 is busy (the website is probably already open in another
# terminal), the next free port up to 5109 is used instead.
cd "$(dirname "$0")/apps/admin_web" || exit 1
in_use() {
  if command -v lsof >/dev/null 2>&1; then lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; fi
}
PORT=5100
while in_use "$PORT"; do
  echo "Port $PORT is already in use - is the admin website already open in another terminal?"
  PORT=$((PORT + 1))
  if [ "$PORT" -gt 5109 ]; then
    echo "Ports 5100-5109 are all busy. Close the other EduLearn website terminals and try again."
    exit 1
  fi
done
echo "Opening the admin website at http://localhost:$PORT"
flutter run -d chrome --web-port "$PORT"
