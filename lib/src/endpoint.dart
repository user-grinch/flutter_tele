import 'dart:async';
import 'package:flutter/services.dart';
import 'call.dart';

class TeleEndpoint {
  static const MethodChannel _channel = MethodChannel('flutter_tele');
  static const EventChannel _eventChannel = EventChannel('flutter_tele_events');

  StreamSubscription? _eventSubscription;
  final Map<String, StreamController<dynamic>> _eventControllers = {};

  TeleEndpoint() {
    _setupEventChannel();
  }

  Future<bool> requestPermissions() async {
    try {
      print('FlutterTele: Requesting phone permissions');
      final result = await _channel.invokeMethod('requestPermissions');
      print('FlutterTele: Permission request result: $result');
      return result == true;
    } on PlatformException catch (e) {
      print(
        'FlutterTele: PlatformException in requestPermissions: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      print('FlutterTele: Exception in requestPermissions: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      print('FlutterTele: Checking phone permissions');
      final result = await _channel.invokeMethod('hasPermissions');
      print('FlutterTele: Has permissions result: $result');
      return result == true;
    } on PlatformException catch (e) {
      print(
        'FlutterTele: PlatformException in hasPermissions: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      print('FlutterTele: Exception in hasPermissions: $e');
      return false;
    }
  }

  void _setupEventChannel() {
    print('FlutterTele: Setting up event channel');
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      print('FlutterTele: Received event from native: $event');
      _handleEvent(event);
    });
  }

  void _handleEvent(dynamic event) {
    print('FlutterTele: Handling event: $event');
    if (event is Map) {
      final eventStringMap = event.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final eventType = eventStringMap['type'] as String?;
      final eventData = eventStringMap['data'];
      print('FlutterTele: Event type: $eventType, data: $eventData');

      if (eventType != null && _eventControllers.containsKey(eventType)) {
        print('FlutterTele: Sending event to controller: $eventType');
        _eventControllers[eventType]!.add(eventData);
      } else if (eventType == 'call_error') {
        print('FlutterTele: Call error: $eventData');
        if (_eventControllers.containsKey('call_error')) {
          _eventControllers['call_error']!.add(eventData);
        }
      } else {
        print('FlutterTele: No controller found for event type: $eventType');
      }
    } else {
      print('FlutterTele: Event is not a Map: ${event.runtimeType}');
    }
  }

  Stream<dynamic> on(String eventType) {
    print('FlutterTele: Creating event stream for type: $eventType');
    if (!_eventControllers.containsKey(eventType)) {
      print('FlutterTele: Creating new controller for event type: $eventType');
      _eventControllers[eventType] = StreamController<dynamic>.broadcast();
    }
    return _eventControllers[eventType]!.stream;
  }

  Future<Map<String, dynamic>> start(Map<String, dynamic> configuration) async {
    try {
      print(
        'FlutterTele: Starting telephony service with config: $configuration',
      );

      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print('FlutterTele: Missing phone permissions, requesting...');
        final granted = await requestPermissions();
        if (!granted) {
          throw Exception('Phone permissions are required but not granted');
        }
      }

      final result = await _channel.invokeMethod('start', configuration);

      if (result is Map) {
        final resultStringMap = result.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final accounts = <Map<String, dynamic>>[];
        final calls = <TeleCall>[];

        if (resultStringMap.containsKey('accounts')) {
          final accountsData = resultStringMap['accounts'] as List<dynamic>;
          for (final accountData in accountsData) {
            if (accountData is Map) {
              accounts.add(
                accountData.map((k, v) => MapEntry(k.toString(), v)),
              );
            }
          }
        }

        if (resultStringMap.containsKey('calls')) {
          final callsData = resultStringMap['calls'] as List<dynamic>;
          for (final callData in callsData) {
            if (callData is Map) {
              calls.add(
                TeleCall.fromMap(
                  callData.map((k, v) => MapEntry(k.toString(), v)),
                ),
              );
            }
          }
        }

        final extra = <String, dynamic>{};
        for (final key in resultStringMap.keys) {
          if (key != 'accounts' && key != 'calls') {
            extra[key] = resultStringMap[key];
          }
        }

        return {'accounts': accounts, 'calls': calls, ...extra};
      }

      throw Exception('Invalid response from native code');
    } on PlatformException catch (e) {
      throw Exception('Failed to start telephony service: ${e.message}');
    } catch (e) {
      throw Exception('Error starting telephony service: $e');
    }
  }

  Future<TeleCall> makeCall(
    int sim,
    String destination,
    Map<String, dynamic>? callSettings,
    Map<String, dynamic>? msgData,
  ) async {
    try {
      print('FlutterTele: Making call to $destination on SIM $sim');

      final completer = Completer<TeleCall>();
      late StreamSubscription subscription;

      subscription = on('call_received').listen((event) {
        final map = event as Map;
        final stringMap = map.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final call = TeleCall.fromMap(stringMap);

        // Ensure this is the call we just initiated
        if (call.remoteNumber == destination) {
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(call);
          }
        }
      });

      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.completeError(
            Exception(
              'Call placement timed out. Ensure permissions are granted and TelecomService is active.',
            ),
          );
        }
      });

      await _channel.invokeMethod('makeCall', {
        'sim': sim,
        'destination': destination,
        'callSettings': callSettings,
        'msgData': msgData,
      });

      return completer.future;
    } on PlatformException catch (e) {
      print(
        'FlutterTele: PlatformException in makeCall: ${e.code} - ${e.message}',
      );
      throw Exception('Failed to make call: ${e.message}');
    } catch (e) {
      print('FlutterTele: Exception in makeCall: $e');
      throw Exception('Error making call: $e');
    }
  }

  Future<dynamic> answerCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('answerCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to answer call: ${e.message}');
    }
  }

  Future<dynamic> hangupCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('hangupCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to hangup call: ${e.message}');
    }
  }

  Future<dynamic> declineCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('declineCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to decline call: ${e.message}');
    }
  }

  Future<dynamic> holdCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('holdCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to hold call: ${e.message}');
    }
  }

  Future<dynamic> unholdCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('unholdCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to unhold call: ${e.message}');
    }
  }

  Future<dynamic> muteCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('muteCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to mute call: ${e.message}');
    }
  }

  Future<dynamic> unMuteCall(TeleCall call) async {
    try {
      return await _channel.invokeMethod('unMuteCall', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to unmute call: ${e.message}');
    }
  }

  Future<dynamic> useSpeaker(TeleCall call) async {
    try {
      return await _channel.invokeMethod('useSpeaker', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to use speaker: ${e.message}');
    }
  }

  Future<dynamic> useEarpiece(TeleCall call) async {
    try {
      return await _channel.invokeMethod('useEarpiece', call.id);
    } on PlatformException catch (e) {
      throw Exception('Failed to use earpiece: ${e.message}');
    }
  }

  Future<String> sendEnvelope(TeleCall call) async {
    try {
      final result = await _channel.invokeMethod('sendEnvelope', call.id);
      return result.toString();
    } on PlatformException catch (e) {
      throw Exception('Failed to send envelope: ${e.message}');
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }
}
