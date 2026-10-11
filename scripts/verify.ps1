$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency check failed.' }
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build apk --debug --dart-define=DEMO=true
if ($LASTEXITCODE -ne 0) { throw 'Android demo build failed.' }
Write-Host 'Analysis, tests and Android demo build passed. Verify Firebase live mode separately.'
