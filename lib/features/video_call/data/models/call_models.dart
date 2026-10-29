class VideoCallToken {
  final String token;
  final String wsUrl;
  final String roomName;
  final String participantName;
  final String participantRole;
  final String callType;
  final bool isAudioOnly;
  final DateTime expiresAt;

  VideoCallToken({
    required this.token,
    required this.wsUrl,
    required this.roomName,
    this.participantName = '',
    this.participantRole = 'User',
    this.callType = 'support',
    this.isAudioOnly = false,
    required this.expiresAt,
  });

  factory VideoCallToken.fromJson(Map<String, dynamic> json) {
    return VideoCallToken(
      token: json['token']?.toString() ?? '',
      wsUrl: json['wsUrl']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      participantName: json['participantName']?.toString() ?? '',
      participantRole: json['participantRole']?.toString() ?? 'User',
      callType: json['callType']?.toString() ?? 'support',
      isAudioOnly: json['isAudioOnly'] == true,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 2)),
    );
  }
}

class VideoCallRoom {
  final String roomName;
  final int maxParticipants;
  final int currentParticipants;
  final DateTime createdAt;
  final bool isActive;
  final int createdByUserId;
  final String createdByName;
  final String createdByRole;
  final String callType;
  final String description;
  final List<CallParticipant> participants;

  VideoCallRoom({
    required this.roomName,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.createdAt,
    required this.isActive,
    this.createdByUserId = 0,
    this.createdByName = '',
    this.createdByRole = 'User',
    this.callType = 'support',
    this.description = '',
    this.participants = const [],
  });

  factory VideoCallRoom.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List<dynamic>? ?? [];
    return VideoCallRoom(
      roomName: json['roomName']?.toString() ?? '',
      maxParticipants: json['maxParticipants'] is int
          ? json['maxParticipants'] as int
          : int.tryParse(json['maxParticipants']?.toString() ?? '10') ?? 10,
      currentParticipants: json['currentParticipants'] is int
          ? json['currentParticipants'] as int
          : int.tryParse(json['currentParticipants']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
      createdByUserId: json['createdByUserId'] is int
          ? json['createdByUserId'] as int
          : int.tryParse(json['createdByUserId']?.toString() ?? '0') ?? 0,
      createdByName: json['createdByName']?.toString() ?? '',
      createdByRole: json['createdByRole']?.toString() ?? 'User',
      callType: json['callType']?.toString() ?? 'support',
      description: json['description']?.toString() ?? '',
      participants: rawParticipants
          .whereType<Map<String, dynamic>>()
          .map(CallParticipant.fromJson)
          .toList(),
    );
  }
}

class CallParticipant {
  final String identity;
  final String name;
  final String role;
  final DateTime joinedAt;
  final bool isConnected;

  CallParticipant({
    required this.identity,
    required this.name,
    this.role = 'User',
    required this.joinedAt,
    required this.isConnected,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      identity: json['identity']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'User',
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ?? DateTime.now(),
      isConnected: json['isConnected'] ?? true,
    );
  }
}
