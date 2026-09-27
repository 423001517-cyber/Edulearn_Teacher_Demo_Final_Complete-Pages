#!/usr/bin/env bash
# EduLearn - loads the demo data. Run while 2-start-firebase.sh is running.
set -e
cd "$(dirname "$0")/tools/seed"
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  node seed.mjs --reset --project demo-edulearn
echo
echo "Teacher website sign-in: jean@edulearn.test / edulearn123"
echo "Admin website sign-in:   admin@edulearn.test / edulearn123"
