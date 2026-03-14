enum CallState {
  initiating,
  incoming,
  ringing,
  outgoing,
  connected,
  disconnected,
  muted,
  hold,
  unknown,
}

class TeleCall {
  final int id;
  final String? callId;
  final int? accountId;
  final String? localContact;
  final String? localUri;
  final String? remoteContact;
  final String? remoteUri;
  final String? state;
  final String? stateText;
  final bool? held;
  final bool? muted;
  final bool? speaker;
  final int? connectDuration;
  final int? totalDuration;
  final bool? remoteOfferer;
  final int? remoteAudioCount;
  final int? remoteVideoCount;
  final int? audioCount;
  final int? videoCount;
  final int? lastStatusCode;
  final String? lastReason;
  final Map<String, dynamic>? media;
  final Map<String, dynamic>? provisionalMedia;
  final String? creationTime;
  final String? connectTime;
  final Map<String, dynamic>? details;
  final String? callHashCode;
  final Map<String, dynamic>? extras;
  final int? connectTimeMillis;
  final int? creationTimeMillis;
  final String? disconnectCause;
  final String? direction;
  final int? simSlot;
  final int? simSlot1;
  final int? simSlot2;

  final String? remoteNumber;
  final String? remoteName;

  TeleCall({
    required this.id,
    this.callId,
    this.accountId,
    this.localContact,
    this.localUri,
    this.remoteContact,
    this.remoteUri,
    this.state,
    this.stateText,
    this.held,
    this.muted,
    this.speaker,
    this.connectDuration,
    this.totalDuration,
    this.remoteOfferer,
    this.remoteAudioCount,
    this.remoteVideoCount,
    this.audioCount,
    this.videoCount,
    this.lastStatusCode,
    this.lastReason,
    this.media,
    this.provisionalMedia,
    this.creationTime,
    this.connectTime,
    this.details,
    this.callHashCode,
    this.extras,
    this.connectTimeMillis,
    this.creationTimeMillis,
    this.disconnectCause,
    this.direction,
    this.simSlot,
    this.simSlot1,
    this.simSlot2,
    this.remoteNumber,
    this.remoteName,
  });

  CallState get currentCallState {
    switch (state?.toUpperCase()) {
      case 'INITIATING':
        return CallState.initiating;
      case 'INCOMING':
        return CallState.incoming;
      case 'RINGING':
        return CallState.ringing;
      case 'DIALING':
      case 'CONNECTING':
      case 'OUTGOING':
        return CallState.outgoing;
      case 'ACTIVE':
      case 'CONNECTED':
        return CallState.connected;
      case 'DISCONNECTED':
      case 'DECLINED':
      case 'PJSIP_INV_STATE_DISCONNECTED':
        return CallState.disconnected;
      case 'HOLDING':
      case 'HOLD':
        return CallState.hold;
      case 'MUTED':
        return CallState.muted;
      default:
        return CallState.unknown;
    }
  }

  factory TeleCall.fromMap(dynamic event) {
    // Safely cast the raw event map coming from the platform channel
    final map = Map<String, dynamic>.from(event as Map);
    print('FlutterTele: TeleCall.fromMap called with: $map');

    String? parsedRemoteNumber;
    String? parsedRemoteName;

    // Apply default fallback for remoteUri
    final remoteUri = map['remoteUri'] ?? '';

    if (remoteUri.isNotEmpty) {
      print('FlutterTele: Parsing remoteUri: $remoteUri');

      // Parse remote URI to extract name and number
      final nameMatch = RegExp(
        r'"([^"]+)" <sip:([^@]+)@',
      ).firstMatch(remoteUri);
      if (nameMatch != null) {
        parsedRemoteName = nameMatch.group(1);
        parsedRemoteNumber = nameMatch.group(2);
        print(
          'FlutterTele: Found name and number from SIP URI: $parsedRemoteName, $parsedRemoteNumber',
        );
      } else {
        final numberMatch = RegExp(r'sip:([^@]+)@').firstMatch(remoteUri);
        if (numberMatch != null) {
          parsedRemoteNumber = numberMatch.group(1);
          print('FlutterTele: Found number from SIP URI: $parsedRemoteNumber');
        }
      }

      final telMatch = RegExp(r'tel:([^@]+)').firstMatch(remoteUri);
      if (telMatch != null) {
        parsedRemoteNumber = Uri.decodeComponent(telMatch.group(1)!);
        print('FlutterTele: Found number from tel URI: $parsedRemoteNumber');
      }
    }

    // Resolution for finalRemoteNumber including the empty/destination fallback
    String? finalRemoteNumber = map['remoteNumber'] ?? parsedRemoteNumber;
    if (finalRemoteNumber == null || finalRemoteNumber.isEmpty) {
      finalRemoteNumber = map['destination']?.toString();
    }

    final finalRemoteName = map['remoteName'] ?? parsedRemoteName;
    print(
      'FlutterTele: Final remoteNumber: $finalRemoteNumber, remoteName: $finalRemoteName',
    );

    // Helper function that now guarantees a Map is returned (no nulls)
    Map<String, dynamic> convertMap(dynamic value) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }

    final call = TeleCall(
      id: map['id'] ?? 0,
      callId: map['callId'],
      accountId: map['accountId'],
      localContact: map['localContact'],
      localUri: map['localUri'],
      remoteContact: map['remoteContact'],
      remoteUri: remoteUri,
      state: map['state'],
      stateText: map['stateText'] ?? map['state'], // Fallback to state
      held: map['held'],
      muted: map['muted'],
      speaker: map['speaker'],
      connectDuration: map['connectDuration'] ?? 0, // Fallback to 0
      totalDuration: map['totalDuration'] ?? 0, // Fallback to 0
      remoteOfferer: map['remoteOfferer'],
      remoteAudioCount: map['remoteAudioCount'],
      remoteVideoCount: map['remoteVideoCount'],
      audioCount: map['audioCount'],
      videoCount: map['videoCount'],
      lastStatusCode: map['lastStatusCode'],
      lastReason: map['lastReason'],
      media: convertMap(map['media']), // Will default to {}
      provisionalMedia: convertMap(
        map['provisionalMedia'],
      ), // Will default to {}
      creationTime: map['creationTime'],
      connectTime: map['connectTime'],
      details: convertMap(map['details']), // Will default to {}
      callHashCode: map['hashCode'],
      extras: convertMap(map['extras']), // Will default to {}
      connectTimeMillis: map['connectTimeMillis'],
      creationTimeMillis: map['creationTimeMillis'],
      disconnectCause: map['disconnectCause'],
      direction: map['direction'],
      simSlot: map['simSlot'] ?? map['sim'], // Map sim to simSlot
      simSlot1: map['simSlot1'],
      simSlot2: map['simSlot2'],
      remoteNumber: finalRemoteNumber,
      remoteName: finalRemoteName,
    );

    print(
      'FlutterTele: Created TeleCall with id: ${call.id}, state: ${call.state}, remoteNumber: ${call.remoteNumber}',
    );
    return call;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callId': callId,
      'accountId': accountId,
      'localContact': localContact,
      'localUri': localUri,
      'remoteContact': remoteContact,
      'remoteUri': remoteUri,
      'state': state,
      'stateText': stateText,
      'held': held,
      'muted': muted,
      'speaker': speaker,
      'connectDuration': connectDuration,
      'totalDuration': totalDuration,
      'remoteOfferer': remoteOfferer,
      'remoteAudioCount': remoteAudioCount,
      'remoteVideoCount': remoteVideoCount,
      'audioCount': audioCount,
      'videoCount': videoCount,
      'lastStatusCode': lastStatusCode,
      'lastReason': lastReason,
      'media': media,
      'provisionalMedia': provisionalMedia,
      'creationTime': creationTime,
      'connectTime': connectTime,
      'details': details,
      'hashCode': callHashCode,
      'extras': extras,
      'connectTimeMillis': connectTimeMillis,
      'creationTimeMillis': creationTimeMillis,
      'disconnectCause': disconnectCause,
      'direction': direction,
      'simSlot': simSlot,
      'simSlot1': simSlot1,
      'simSlot2': simSlot2,
      'remoteNumber': remoteNumber,
      'remoteName': remoteName,
    };
  }

  // Getters
  int getId() => id;
  int? getAccountId() => accountId;
  String? getCallId() => callId;
  String? getLocalContact() => localContact;
  String? getLocalUri() => localUri;
  String? getRemoteContact() => remoteContact;
  String? getRemoteUri() => remoteUri;
  String? getRemoteName() => remoteName;
  String? getRemoteNumber() => remoteNumber;
  String? getState() => state;
  String? getStateText() => stateText;
  bool? isHeld() => held;
  bool? isMuted() => muted;
  bool? isSpeaker() => speaker;
  bool? isTerminated() => state == 'PJSIP_INV_STATE_DISCONNECTED';
  bool? getRemoteOfferer() => remoteOfferer;
  int? getRemoteAudioCount() => remoteAudioCount;
  int? getRemoteVideoCount() => remoteVideoCount;
  int? getAudioCount() => audioCount;
  int? getVideoCount() => videoCount;
  int? getLastStatusCode() => lastStatusCode;
  String? getLastReason() => lastReason;
  Map<String, dynamic>? getMedia() => media;
  Map<String, dynamic>? getProvisionalMedia() => provisionalMedia;
  String? getDirection() => direction;

  // Duration methods
  int getTotalDuration() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final constructionTime = creationTimeMillis ?? 0;
    final offset = now - constructionTime;
    return (totalDuration ?? 0) + offset;
  }

  int getConnectDuration() {
    if (connectDuration == null ||
        connectDuration! < 0 ||
        state == 'PJSIP_INV_STATE_DISCONNECTED') {
      return connectDuration ?? 0;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final constructionTime = creationTimeMillis ?? 0;
    final offset = now - constructionTime;
    return offset;
  }

  String getFormattedTotalDuration() => formatTime(getTotalDuration());
  String getFormattedConnectDuration() => formatTime(getConnectDuration());

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'TeleCall{id: $id, state: $state, remoteNumber: $remoteNumber, remoteName: $remoteName}';
  }
}
