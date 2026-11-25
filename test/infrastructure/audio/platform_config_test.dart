import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Failure modes (BGA-03): iOS suspends the app when the screen locks because
// the audio background mode is missing; Android kills playback because the
// mediaPlayback foreground service was removed from the manifest.
void main() {
  test('iOS declares the audio background mode', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final modes = RegExp(
      r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);

    expect(modes, isNotNull);
    expect(modes!.group(1), contains('<string>audio</string>'));
  });

  test('Android keeps the mediaPlayback foreground service', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      RegExp(
        r'android:name="com\.ryanheise\.audioservice\.AudioService"\s+'
        r'android:foregroundServiceType="mediaPlayback"',
      ).hasMatch(manifest),
      isTrue,
    );
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
  });
}
