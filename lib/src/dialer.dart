import 'package:flutter/services.dart';

class TeleDialer {
  static const MethodChannel _channel = MethodChannel('flutter_tele');

  static Future<bool> isDefaultDialer() async {
    try {
      final bool? isDefault = await _channel.invokeMethod('isDefaultDialer');
      return isDefault ?? false;
    } on PlatformException catch (e) {
      print('Error checking default dialer: ${e.message}');
      return false;
    }
  }

  static Future<bool> setDefaultDialer() async {
    try {
      final bool? result = await _channel.invokeMethod('setDefaultDialer');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting default dialer: ${e.message}');
      return false;
    }
  }

  static Future<bool> canSetDefaultDialer() async {
    try {
      final bool? canSet = await _channel.invokeMethod('canSetDefaultDialer');
      return canSet ?? false;
    } on PlatformException catch (e) {
      print('Error checking if can set default dialer: ${e.message}');
      return false;
    }
  }

  static Future<bool> requestDefaultDialer() async {
    return await setDefaultDialer();
  }
}
