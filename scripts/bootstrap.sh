#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --empty --platforms=android,ios,web --project-name=flow_desk --org=com.saadi .
flutter pub get
dart run scripts/configure_platforms.dart
dart run flutter_launcher_icons
dart format lib test scripts
flutter analyze --no-fatal-infos
flutter test
