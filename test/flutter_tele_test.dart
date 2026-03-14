import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tele/flutter_tele.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flutter_tele', () {
    test('TeleCall.fromMap creates call with correct properties', () {
      final callData = {
        'id': 1,
        'state': 'ACTIVE',
        'remoteUri': '"Test User" <sip:+1234567890@domain.com>',
        'direction': 'DIRECTION_INCOMING',
        'held': false,
        'muted': false,
        'speaker': false,
        'creationTimeMillis': 1000,
        'connectTimeMillis': 2000,
      };

      final call = TeleCall.fromMap(callData);

      expect(call.id, equals(1));
      expect(call.state, equals(CallState.connected));
      expect(call.remoteNumber, equals('+1234567890'));
      expect(call.remoteName, equals('Test User'));
      expect(call.direction, equals(CallDirection.incoming));
      expect(call.held, equals(false));
      expect(call.muted, equals(false));
      expect(call.speaker, equals(false));
      expect(call.creationTimeMillis, equals(1000));
      expect(call.connectTimeMillis, equals(2000));
    });

    test('TeleCall.toMap returns correct map', () {
      final call = TeleCall(
        id: 1,
        state: CallState.connected,
        remoteNumber: '+1234567890',
        remoteName: 'Test User',
        direction: CallDirection.incoming,
        held: false,
        muted: false,
        speaker: false,
        creationTimeMillis: 1000,
        connectTimeMillis: 2000,
      );

      final map = call.toMap();

      expect(map['id'], equals(1));
      expect(map['state'], equals('CONNECTED'));
      expect(map['remoteNumber'], equals('+1234567890'));
      expect(map['remoteName'], equals('Test User'));
      expect(map['direction'], equals('INCOMING'));
      expect(map['held'], equals(false));
      expect(map['muted'], equals(false));
      expect(map['speaker'], equals(false));
      expect(map['creationTimeMillis'], equals(1000));
      expect(map['connectTimeMillis'], equals(2000));
    });

    test('TeleCall duration calculation works correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final call = TeleCall(
        id: 1,
        state: CallState.connected,
        remoteNumber: '+1234567890',
        remoteName: 'Test User',
        direction: CallDirection.incoming,
        creationTimeMillis: now - 5000, // 5 seconds ago
        connectTimeMillis: now - 3000, // 3 seconds ago
      );

      expect(call.totalDuration.inSeconds, closeTo(5, 1));
      expect(call.duration.inSeconds, closeTo(3, 1));
    });

    test('TeleCall state mapping works correctly', () {
      final activeCall = TeleCall(
        id: 1,
        state: CallState.connected,
        remoteNumber: '',
        remoteName: '',
        direction: CallDirection.unknown,
      );
      final ringingCall = TeleCall(
        id: 2,
        state: CallState.ringing,
        remoteNumber: '',
        remoteName: '',
        direction: CallDirection.unknown,
      );

      expect(activeCall.state, equals(CallState.connected));
      expect(ringingCall.state, equals(CallState.ringing));
    });

    test('TeleCall fromMap handles minimal values', () {
      final callData = {
        'id': 1,
      };

      final call = TeleCall.fromMap(callData);

      expect(call.id, equals(1));
      expect(call.state, equals(CallState.unknown));
      expect(call.direction, equals(CallDirection.unknown));
      expect(call.remoteNumber, equals(''));
      expect(call.remoteName, equals(''));
    });
  });
}
