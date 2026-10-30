import 'dart:math' as math;

class GpsPositionModel {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double altitudeMeters;
  final double speedMps;
  final double bearingDegrees;
  final String provider;
  final int satellites;
  final bool isMock;
  final DateTime timestamp;
  final String address;
  final String? ward;
  final String? district;
  final String? city;

  const GpsPositionModel({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 4.2,
    this.altitudeMeters = 12.0,
    this.speedMps = 0.0,
    this.bearingDegrees = 0.0,
    this.provider = 'GPS_SATELLITE',
    this.satellites = 9,
    this.isMock = false,
    required this.timestamp,
    required this.address,
    this.ward,
    this.district,
    this.city,
  });

  String get plusCode => encodePlusCode(latitude, longitude);

  String get dmsCoordinates => formatDms(latitude, longitude);

  String get decimalCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=${latitude.toStringAsFixed(7)},${longitude.toStringAsFixed(7)}';

  double get speedKmh => math.max(0.0, speedMps * 3.6);

  String get accuracyGradeLabel {
    if (accuracyMeters <= 6.0) return 'Chuẩn xác tuyệt đối (GPS Vệ tinh)';
    if (accuracyMeters <= 15.0) return 'Độ chính xác rất cao';
    if (accuracyMeters <= 35.0) return 'Độ chính xác tốt';
    return 'Định vị hỗn hợp (Wi-Fi/Trạm phát)';
  }

  String get providerVietnameseLabel {
    switch (provider.toUpperCase()) {
      case 'GPS_SATELLITE':
        return 'Vệ tinh GPS phần cứng';
      case 'FUSED_HIGH_ACCURACY':
        return 'Cảm biến Fused GPS đa tầng';
      case 'NETWORK_WIFI_CELL':
        return 'Định vị Wi-Fi & Trạm 4G/5G';
      case 'MANUAL_PIN':
        return 'Ghim chuẩn trực tiếp trên bản đồ';
      default:
        return 'Hệ thống định vị GPS';
    }
  }

  String get compassHeadingText {
    final normalized = ((bearingDegrees % 360) + 360) % 360;
    const dirs = [
      'Bắc',
      'Đông Bắc',
      'Đông',
      'Đông Nam',
      'Nam',
      'Tây Nam',
      'Tây',
      'Tây Bắc',
    ];
    final idx = ((normalized / 45.0).round()) % 8;
    return '${dirs[idx]} (${normalized.round()}°)';
  }

  GpsPositionModel copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    double? speedMps,
    double? bearingDegrees,
    String? provider,
    int? satellites,
    bool? isMock,
    DateTime? timestamp,
    String? address,
    String? ward,
    String? district,
    String? city,
  }) {
    return GpsPositionModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      speedMps: speedMps ?? this.speedMps,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      provider: provider ?? this.provider,
      satellites: satellites ?? this.satellites,
      isMock: isMock ?? this.isMock,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      ward: ward ?? this.ward,
      district: district ?? this.district,
      city: city ?? this.city,
    );
  }

  String toShareableMessage({
    required String userName,
    String? note,
    String? shareCode,
    String recipientTarget = 'Gia đình',
    bool isLive = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      isLive
          ? '📍 [CHIA SẺ VỊ TRÍ TRỰC TIẾP - LIVE GPS]'
          : '📍 [CHIA SẺ VỊ TRÍ CHUẨN XÁC - NGUYENQUANGHUNG]',
    );
    buffer.writeln('👤 Người chia sẻ: $userName (Vai trò: USER)');
    buffer.writeln('👨‍👩‍👧‍👦 Gửi tới: $recipientTarget');
    if (note != null && note.trim().isNotEmpty) {
      buffer.writeln('💬 Ghi chú: ${note.trim()}');
    }
    buffer.writeln('🏠 Địa chỉ: $address');
    buffer.writeln(
      '🧭 Tọa độ chuẩn: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} ($dmsCoordinates)',
    );
    buffer.writeln(
      '🎯 Độ chính xác: ±${accuracyMeters.toStringAsFixed(1)}m ($providerVietnameseLabel)',
    );
    buffer.writeln('🔖 Mã Plus Code: $plusCode');
    if (shareCode != null && shareCode.isNotEmpty) {
      buffer.writeln('🔑 Mã định vị: $shareCode');
    }
    buffer.writeln('🗺️ Mở bản đồ chỉ đường: $googleMapsUrl');
    return buffer.toString().trim();
  }

  static String formatDms(double lat, double lng) {
    String toDmsPart(double value, String pos, String neg) {
      final hemi = value >= 0 ? pos : neg;
      final absVal = value.abs();
      final deg = absVal.floor();
      final minFull = (absVal - deg) * 60.0;
      final min = minFull.floor();
      final sec = (minFull - min) * 60.0;
      return '$deg°${min.toString().padLeft(2, '0')}\'${sec.toStringAsFixed(1)}"$hemi';
    }

    return '${toDmsPart(lat, 'N', 'S')} ${toDmsPart(lng, 'E', 'W')}';
  }

  static String encodePlusCode(double latitude, double longitude) {
    const alphabet = '23456789CFGHJMPQRVWX';
    var lat = latitude.clamp(-90.0, 90.0);
    if (lat == 90.0) lat -= 0.00005;
    var lng = longitude;
    while (lng < -180.0) {
      lng += 360.0;
    }
    while (lng >= 180.0) {
      lng -= 360.0;
    }

    lat += 90.0;
    lng += 180.0;

    var latVal = (lat * 8000).floor();
    var lngVal = (lng * 8000).floor();

    final chars = List<String>.filled(11, '');
    for (var i = 4; i >= 0; i--) {
      final lngDigit = lngVal % 20;
      final latDigit = latVal % 20;
      lngVal ~/= 20;
      latVal ~/= 20;

      var pos = i * 2;
      if (pos >= 8) pos++;
      chars[pos + 1] = alphabet[lngDigit];
      chars[pos] = alphabet[latDigit];
    }
    chars[8] = '+';
    return chars.join();
  }

  /// Công thức Haversine tính khoảng cách mặt cầu chính xác tới từng mét
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static String formatDistanceText(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }

  static String calculateBearingDirection(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);
    final brng = ((math.atan2(y, x) * 180.0 / math.pi) + 360.0) % 360.0;

    const dirs = [
      'Bắc',
      'Đông Bắc',
      'Đông',
      'Đông Nam',
      'Nam',
      'Tây Nam',
      'Tây',
      'Tây Bắc',
    ];
    final idx = ((brng / 45.0).round()) % 8;
    return 'Hướng ${dirs[idx]} (${brng.round()}°)';
  }
}

class SharedLocationRecord {
  final String id;
  final String shareCode;
  final int userId;
  final String userName;
  final String userRole;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double altitudeMeters;
  final double speedMps;
  final double bearingDegrees;
  final String provider;
  final String address;
  final String? ward;
  final String? district;
  final String? city;
  final String plusCode;
  final String dmsCoordinates;
  final String googleMapsUrl;
  final String shareType;
  final String recipientTarget;
  final String note;
  final bool isLive;
  final bool isActive;
  final int batteryLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;

  const SharedLocationRecord({
    required this.id,
    required this.shareCode,
    required this.userId,
    required this.userName,
    this.userRole = 'User',
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.altitudeMeters = 0.0,
    this.speedMps = 0.0,
    this.bearingDegrees = 0.0,
    this.provider = 'GPS_SATELLITE',
    required this.address,
    this.ward,
    this.district,
    this.city,
    required this.plusCode,
    required this.dmsCoordinates,
    required this.googleMapsUrl,
    this.shareType = 'current',
    this.recipientTarget = 'Gia đình',
    required this.note,
    this.isLive = false,
    this.isActive = false,
    this.batteryLevel = 100,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  String get shareTypeLabel {
    switch (shareType.toLowerCase()) {
      case 'live':
        return 'Hành trình Trực tiếp (Live)';
      case 'pickup':
        return 'Điểm đón Bé';
      case 'sos':
        return 'Khẩn cấp SOS';
      case 'safe_point':
        return 'Điểm hẹn An toàn';
      default:
        return 'Vị trí Hiện tại';
    }
  }

  factory SharedLocationRecord.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? 10.776889;
    final lng = (json['longitude'] as num?)?.toDouble() ?? 106.700981;
    return SharedLocationRecord(
      id: (json['id'] ?? '').toString(),
      shareCode: (json['shareCode'] ?? '').toString(),
      userId: (json['userId'] as num?)?.toInt() ?? 1,
      userName: (json['userName'] ?? 'Phụ huynh (User)').toString(),
      userRole: (json['userRole'] ?? 'User').toString(),
      latitude: lat,
      longitude: lng,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 4.0,
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble() ?? 0.0,
      speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0.0,
      bearingDegrees: (json['bearingDegrees'] as num?)?.toDouble() ?? 0.0,
      provider: (json['provider'] ?? 'GPS_SATELLITE').toString(),
      address: (json['address'] ?? '').toString(),
      ward: json['ward']?.toString(),
      district: json['district']?.toString(),
      city: json['city']?.toString(),
      plusCode: (json['plusCode'] ?? GpsPositionModel.encodePlusCode(lat, lng))
          .toString(),
      dmsCoordinates:
          (json['dmsCoordinates'] ?? GpsPositionModel.formatDms(lat, lng))
              .toString(),
      googleMapsUrl: (json['googleMapsUrl'] ??
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng')
          .toString(),
      shareType: (json['shareType'] ?? 'current').toString(),
      recipientTarget: (json['recipientTarget'] ?? 'Gia đình').toString(),
      note: (json['note'] ?? '').toString(),
      isLive: json['isLive'] == true,
      isActive: json['isActive'] == true,
      batteryLevel: (json['batteryLevel'] as num?)?.toInt() ?? 100,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shareCode': shareCode,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'altitudeMeters': altitudeMeters,
      'speedMps': speedMps,
      'bearingDegrees': bearingDegrees,
      'provider': provider,
      'address': address,
      'ward': ward,
      'district': district,
      'city': city,
      'plusCode': plusCode,
      'dmsCoordinates': dmsCoordinates,
      'googleMapsUrl': googleMapsUrl,
      'shareType': shareType,
      'recipientTarget': recipientTarget,
      'note': note,
      'isLive': isLive,
      'isActive': isActive,
      'batteryLevel': batteryLevel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}

class KidLocationModel {
  final String kidId;
  final String kidName;
  final String deviceName;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String address;
  final String safeZoneName;
  final int safeRadiusMeters;
  final bool isInSafeZone;
  final int batteryPercent;
  final double? distanceFromUserMeters;
  final String? bearingFromUserText;
  final DateTime updatedAt;

  const KidLocationModel({
    required this.kidId,
    required this.kidName,
    required this.deviceName,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.address,
    required this.safeZoneName,
    required this.safeRadiusMeters,
    required this.isInSafeZone,
    required this.batteryPercent,
    this.distanceFromUserMeters,
    this.bearingFromUserText,
    required this.updatedAt,
  });

  factory KidLocationModel.fromJson(Map<String, dynamic> json) {
    return KidLocationModel(
      kidId: (json['kidId'] ?? '').toString(),
      kidName: (json['kidName'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 10.779150,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 106.699420,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 3.5,
      address: (json['address'] ?? '').toString(),
      safeZoneName: (json['safeZoneName'] ?? '').toString(),
      safeRadiusMeters: (json['safeRadiusMeters'] as num?)?.toInt() ?? 150,
      isInSafeZone: json['isInSafeZone'] != false,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 85,
      distanceFromUserMeters:
          (json['distanceFromUserMeters'] as num?)?.toDouble(),
      bearingFromUserText: json['bearingFromUserText']?.toString(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  KidLocationModel withDistanceToUser(double userLat, double userLng) {
    final dist = GpsPositionModel.calculateDistanceMeters(
      userLat,
      userLng,
      latitude,
      longitude,
    );
    final dir = GpsPositionModel.calculateBearingDirection(
      userLat,
      userLng,
      latitude,
      longitude,
    );
    return KidLocationModel(
      kidId: kidId,
      kidName: kidName,
      deviceName: deviceName,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      address: address,
      safeZoneName: safeZoneName,
      safeRadiusMeters: safeRadiusMeters,
      isInSafeZone: isInSafeZone,
      batteryPercent: batteryPercent,
      distanceFromUserMeters: dist,
      bearingFromUserText: dir,
      updatedAt: updatedAt,
    );
  }
}

class UserLocationDashboardModel {
  final SharedLocationRecord? activeLiveShare;
  final List<SharedLocationRecord> recentShares;
  final List<KidLocationModel> kidLocations;

  const UserLocationDashboardModel({
    this.activeLiveShare,
    this.recentShares = const [],
    this.kidLocations = const [],
  });

  factory UserLocationDashboardModel.fromJson(Map<String, dynamic> json) {
    final activeRaw = json['activeLiveShare'];
    final recentRaw = json['recentShares'] as List? ?? const [];
    final kidsRaw = json['kidLocations'] as List? ?? const [];

    return UserLocationDashboardModel(
      activeLiveShare: activeRaw is Map<String, dynamic>
          ? SharedLocationRecord.fromJson(activeRaw)
          : null,
      recentShares: recentRaw
          .whereType<Map<String, dynamic>>()
          .map(SharedLocationRecord.fromJson)
          .toList(),
      kidLocations: kidsRaw
          .whereType<Map<String, dynamic>>()
          .map(KidLocationModel.fromJson)
          .toList(),
    );
  }
}

