$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter create --empty --platforms=android,ios,web --project-name=flow_desk --org=com.saadi .
if ($LASTEXITCODE -ne 0) { throw 'Native platform generation failed.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
dart run scripts/configure_platforms.dart
if ($LASTEXITCODE -ne 0) { throw 'Platform configuration failed.' }
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed.' }
dart format lib test scripts
if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
Write-Host 'Setup checks passed. Try: flutter run --dart-define=DEMO=true'
