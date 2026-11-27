import 'package:flutter/services.dart';

import 'package:cantae/domain/session/system_settings.dart';

/// "Abrir ajustes" through `cantae/system_settings`, handled in
/// `MainActivity.kt` and `AppDelegate.swift`.
class MethodChannelSystemSettings implements SystemSettings {
  const MethodChannelSystemSettings();

  static const _channel = MethodChannel('cantae/system_settings');

  @override
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // No handler on this platform: nothing to open.
    } on PlatformException {
      // The system refused; the banner stays and the person can retry.
    }
  }
}
