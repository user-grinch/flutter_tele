enum CallState {
  initiating,
  incoming,
  ringing,
  outgoing,
  connected,
  disconnected,
  held,
  muted,
  unknown,
}

enum CallDirection {
  incoming,
  outgoing,
  unknown,
}

class TeleCall {
  final int id;
  final CallState state;
  final CallDirection direction;
  final String remoteNumber;
  final String remoteName;
  final int simSlot;
  final bool held;
  final bool muted;
  final bool speaker;
  final int? creationTimeMillis;
  final int? connectTimeMillis;
  final int? disconnectTimeMillis;
  final String? disconnectCause;

  TeleCall({
    required this.id,
    required this.state,
    required this.direction,
    required this.remoteNumber,
    required this.remoteName,
    this.simSlot = 1,
    this.held = false,
    this.muted = false,
    this.speaker = false,
    this.creationTimeMillis,
    this.connectTimeMillis,
    this.disconnectTimeMillis,
    this.disconnectCause,
  });

  /// Connected duration (from when the call was answered)
  Duration get duration {
    if (connectTimeMillis == null || connectTimeMillis == 0) {
      return Duration.zero;
    }
    final endTime = (disconnectTimeMillis != null && disconnectTimeMillis! > 0)
        ? disconnectTimeMillis!
        : DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: endTime - connectTimeMillis!);
  }

  /// Total duration (from when the call was initiated/received)
  Duration get totalDuration {
    if (creationTimeMillis == null || creationTimeMillis == 0) {
      return Duration.zero;
    }
    final endTime = (disconnectTimeMillis != null && disconnectTimeMillis! > 0)
        ? disconnectTimeMillis!
        : DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: endTime - creationTimeMillis!);
  }

  factory TeleCall.fromMap(dynamic event) {
    final map = Map<String, dynamic>.from(event as Map);

    // Parsing logic for remoteUri if it exists (fallback)
    String? parsedRemoteNumber;
    String? parsedRemoteName;
    final remoteUri = map['remoteUri'] ?? '';
    if (remoteUri.isNotEmpty) {
      final nameMatch = RegExp(r'"([^"]+)" <sip:([^@]+)@').firstMatch(remoteUri);
      if (nameMatch != null) {
        parsedRemoteName = nameMatch.group(1);
        parsedRemoteNumber = nameMatch.group(2);
      } else {
        final numberMatch = RegExp(r'sip:([^@]+)@').firstMatch(remoteUri);
        if (numberMatch != null) {
          parsedRemoteNumber = numberMatch.group(1);
        }
      }
      final telMatch = RegExp(r'tel:([^@]+)').firstMatch(remoteUri);
      if (telMatch != null) {
        parsedRemoteNumber = Uri.decodeComponent(telMatch.group(1)!);
      }
    }

    String remoteNumber =
        map['remoteNumber'] ?? parsedRemoteNumber ?? map['destination'] ?? '';
    String remoteName = map['remoteName'] ?? parsedRemoteName ?? remoteNumber;

    final rawState = (map['state'] as String?)?.toUpperCase() ?? '';
    CallState state;
    switch (rawState) {
      case 'INITIATING':
        state = CallState.initiating;
        break;
      case 'INCOMING':
        state = CallState.incoming;
        break;
      case 'RINGING':
        state = CallState.ringing;
        break;
      case 'DIALING':
      case 'CONNECTING':
      case 'OUTGOING':
        state = CallState.outgoing;
        break;
      case 'ACTIVE':
      case 'CONNECTED':
        state = CallState.connected;
        break;
      case 'DISCONNECTED':
      case 'DECLINED':
        state = CallState.disconnected;
        break;
      case 'HOLDING':
      case 'HOLD':
        state = CallState.held;
        break;
      case 'MUTED':
        state = CallState.muted;
        break;
      default:
        state = CallState.unknown;
    }

    final rawDirection = (map['direction'] as String?)?.toUpperCase() ?? '';
    CallDirection direction;
    if (rawDirection.contains('INCOMING')) {
      direction = CallDirection.incoming;
    } else if (rawDirection.contains('OUTGOING')) {
      direction = CallDirection.outgoing;
    } else {
      direction = CallDirection.unknown;
    }

    return TeleCall(
      id: map['id'] ?? 0,
      state: state,
      direction: direction,
      remoteNumber: remoteNumber,
      remoteName: remoteName,
      simSlot: map['simSlot'] ?? map['sim'] ?? 1,
      held: map['held'] ?? false,
      muted: map['muted'] ?? false,
      speaker: map['speaker'] ?? false,
      creationTimeMillis: map['creationTimeMillis'],
      connectTimeMillis: map['connectTimeMillis'],
      disconnectTimeMillis: map['disconnectTimeMillis'],
      disconnectCause: map['disconnectCause'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'state': state.name.toUpperCase(),
      'direction': direction.name.toUpperCase(),
      'remoteNumber': remoteNumber,
      'remoteName': remoteName,
      'simSlot': simSlot,
      'held': held,
      'muted': muted,
      'speaker': speaker,
      'creationTimeMillis': creationTimeMillis,
      'connectTimeMillis': connectTimeMillis,
      'disconnectTimeMillis': disconnectTimeMillis,
      'disconnectCause': disconnectCause,
    };
  }

  @override
  String toString() {
    return 'TeleCall(id: $id, state: $state, direction: $direction, number: $remoteNumber, duration: ${duration.inSeconds}s)';
  }
}
