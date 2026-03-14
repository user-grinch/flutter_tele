import 'package:flutter_dialer/flutter_dialer.dart';

class TeleDialer {
  static Future<bool> isDefaultDialer() async {
    return await FlutterDialer.isDefaultDialer();
  }

  static Future<bool> setDefaultDialer() async {
    return await FlutterDialer.setDefaultDialer();
  }

  static Future<bool> canSetDefaultDialer() async {
    return await FlutterDialer.canSetDefaultDialer();
  }

  static Future<bool> requestDefaultDialer() async {
    return await FlutterDialer.setDefaultDialer();
  }
}
