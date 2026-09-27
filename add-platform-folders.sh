#!/usr/bin/env bash
# EduLearn - adds the android, ios, windows, macos and linux folders (plus
# Flutter's usual .idea / .metadata files) to the teacher and admin apps,
# made by YOUR Flutter version. Code in lib/, web/ and test/ is kept as is.
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "Flutter is not installed or not on PATH. See START_HERE.md"; exit 1; }
for app in teacher_web admin_web; do
  echo "Adding platform folders to apps/$app..."
  (cd "apps/$app" && flutter create . --org ph.edulearn --project-name "$app" \
      --platforms=android,ios,web,windows,macos,linux)
done
echo
echo "Done. apps/teacher_web and apps/admin_web now have android, ios, windows, macos and linux folders."
