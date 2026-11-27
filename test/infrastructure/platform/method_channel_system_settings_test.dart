import 'package:cantae/infrastructure/platform/method_channel_system_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-20, 37, 57): "Abrir ajustes" calls the wrong channel
// or method; a platform without the handler (tests, an old build) crashes
// the room screen instead of doing nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cantae/system_settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks the platform to open the app settings', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });

    await const MethodChannelSystemSettings().openAppSettings();

    expect(calls, ['openAppSettings']);
  });

  test('does nothing when the platform has no handler', () async {
    await expectLater(
      const MethodChannelSystemSettings().openAppSettings(),
      completes,
    );
  });

  test('does nothing when the platform reports an error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    await expectLater(
      const MethodChannelSystemSettings().openAppSettings(),
      completes,
    );
  });
}
