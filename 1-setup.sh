#!/usr/bin/env bash
# EduLearn - one-time setup. Run:  ./1-setup.sh
set -e
cd "$(dirname "$0")"
echo "=== EduLearn setup - run this once ==="
for tool in flutter node java; do
  command -v "$tool" >/dev/null || { echo "$tool is not installed or not on PATH. See START_HERE.md"; exit 1; }
done
echo "[1/5] Installing the Firebase command-line tools..."
command -v firebase >/dev/null || npm install -g firebase-tools
echo "[2/5] Getting Flutter packages for the teacher and admin websites..."
flutter pub get
echo "[3/5] Installing and building the Cloud Functions..."
(cd firebase/functions && npm install && npm run build)
echo "[4/5] Installing the demo data tool..."
(cd tools/seed && npm install)
echo "[5/5] Adding the android, ios, windows, macos and linux folders..."
./add-platform-folders.sh
echo
echo "Setup finished. Next: ./2-start-firebase.sh"
