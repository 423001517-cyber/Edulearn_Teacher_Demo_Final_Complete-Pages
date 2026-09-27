#!/usr/bin/env bash
# EduLearn - starts Firebase on your computer. KEEP THIS TERMINAL OPEN.
# Stop with Ctrl+C (that also saves the demo data for next time).
set -e
cd "$(dirname "$0")"
(cd firebase/functions && npm run build)
IMPORT=""
[ -f .emulator-data/firebase-export-metadata.json ] && IMPORT="--import=.emulator-data"
# Only what the apps use (the websites themselves are served by Flutter).
firebase emulators:start --project demo-edulearn --only auth,firestore,functions,storage $IMPORT --export-on-exit=.emulator-data
