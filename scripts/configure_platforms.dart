import 'dart:io';

void main() {
  final generated = File('test/widget_test.dart');
  if (generated.existsSync() &&
      generated.readAsStringSync().contains('MyApp')) {
    generated.deleteSync();
  }
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var s = manifest.readAsStringSync().replaceAll(
      'android:label="flow_desk"',
      'android:label="Flow Desk"',
    );
    if (!s.contains('android.permission.INTERNET')) {
      s = s.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
      );
    }
    manifest.writeAsStringSync(s);
  }
  for (final path in [
    'android/app/build.gradle.kts',
    'android/app/build.gradle',
  ]) {
    final f = File(path);
    if (f.existsSync()) {
      var s = f
          .readAsStringSync()
          .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 24')
          .replaceAll(
            'minSdkVersion flutter.minSdkVersion',
            'minSdkVersion 24',
          );
      f.writeAsStringSync(s);
    }
  }
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var s = plist.readAsStringSync().replaceAll(
      '<string>Flow Desk</string>',
      '<string>Flow Desk</string>',
    );
    if (!s.contains('NSPhotoLibraryUsageDescription')) {
      s = s.replaceFirst(
        '</dict>',
        '<key>NSPhotoLibraryUsageDescription</key>\n<string>Choose a profile photo for your Flow Desk account.</string>\n</dict>',
      );
    }
    plist.writeAsStringSync(s);
  }
  stdout.writeln(
    'Flow Desk display name, Android permissions/minSdk and iOS photo permission configured.',
  );
}
