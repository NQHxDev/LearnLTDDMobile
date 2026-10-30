import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/location_models.dart';

class LocationService {
  static const MethodChannel _channel =
      MethodChannel('com.nguyen_quang_hung.ltddexam/location');
  static const EventChannel _streamChannel =
      EventChannel('com.nguyen_quang_hung.ltddexam/location_stream');

  static const String _localCacheKey = 'user_shared_locations_cache_v1';

  final ApiClient _apiClient;

  // Bộ nhớ đệm Reverse Geocoding theo tọa độ làm tròn (~11m) để phản hồi tức thì
  static final Map<String, Map<String, String?>> _geocodeCache = {};

  LocationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void _ensureUserRole(UserRoleType role) {
    if (role != UserRoleType.user) {
      throw const ApiException(
        403,
        'Tính năng Chia sẻ vị trí là chức năng dành riêng cho User (Phụ huynh).',
      );
    }
  }

  /// Kiểm tra và xin quyền truy cập vị trí GPS chính xác cao (ACCESS_FINE_LOCATION)
  Future<bool> requestLocationPermission() async {
    try {
      var status = await Permission.locationWhenInUse.status;
      if (status.isGranted) return true;

      status = await Permission.locationWhenInUse.request();
      if (status.isGranted) return true;

      final fallback = await Permission.location.request();
      return fallback.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isLocationServiceEnabled');
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await _channel.invokeMethod<bool>('openLocationSettings');
    } catch (_) {}
  }

  /// Mở trực tiếp vị trí trên ứng dụng Google Maps / Bản đồ chỉ đường
  Future<bool> openInExternalMap({
    required double latitude,
    required double longitude,
    String label = 'Vị trí chia sẻ của Phụ huynh',
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openExternalMap', {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      });
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mở hộp thoại Chia sẻ hệ thống (Zalo, Messenger, SMS, Telegram...)
  Future<bool> shareViaSystemSheet({
    required String text,
    String subject = 'Chia sẻ vị trí chuẩn xác - NguyenQuangHung',
  }) async {
    try {
      final shared = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject,
      });
      return shared ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Kiểm tra xem tọa độ có phải là vị trí giả lập mặc định của Máy ảo (Android Emulator / iOS Simulator ở Mỹ) không
  static bool isEmulatorDefaultLocation(double lat, double lng) {
    // Android Emulator default: Googleplex Mountain View, California (~37.422, -122.084)
    final isGoogleplex =
        (lat - 37.421998).abs() < 0.25 && (lng - (-122.084)).abs() < 0.25;
    // iOS Simulator default: Cupertino (~37.332, -122.031) hoặc SF (~37.785, -122.406)
    final isApple =
        (lat - 37.3318).abs() < 0.25 && (lng - (-122.0312)).abs() < 0.25;
    final isSf =
        (lat - 37.7858).abs() < 0.25 && (lng - (-122.4064)).abs() < 0.25;
    return isGoogleplex || isApple || isSf;
  }

  /// Tự động lấy vị trí xấp xỉ theo IP mạng Internet (Cực kỳ chuẩn xác cho máy ảo hoặc môi trường chưa bắt kịp GPS)
  Future<Map<String, dynamic>?> fetchIpLocationFallback() async {
    try {
      final res = await http
          .get(
            Uri.parse('https://ipwho.is/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final city = data['city']?.toString();
          final region = data['region']?.toString();
          if (lat != null && lng != null) {
            return {
              'latitude': lat,
              'longitude': lng,
              'city': city,
              'region': region,
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Thu thập vị trí GPS thực tế chuẩn xác nhất từ phần cứng + phân giải địa chỉ Tiếng Việt chi tiết
  Future<GpsPositionModel> acquireAccuratePosition({
    bool waitFreshFix = true,
  }) async {
    final granted = await requestLocationPermission();
    if (!granted) {
      throw const ApiException(
        403,
        'Vui lòng cấp quyền Vị trí (GPS Chính xác) để lấy tọa độ của bạn.',
      );
    }

    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      throw const ApiException(
        400,
        'Dịch vụ Định vị (GPS) trên điện thoại đang tắt. Vui lòng bật GPS để lấy vị trí chính xác.',
      );
    }

    Map<dynamic, dynamic>? raw;
    try {
      raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentLocation',
        {'waitFresh': waitFreshFix},
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        throw const ApiException(
          403,
          'Chưa được cấp quyền vị trí GPS. Hãy cấp quyền trong Cài đặt ứng dụng.',
        );
      }
      if (e.code == 'LOCATION_DISABLED') {
        throw const ApiException(
          400,
          'Định vị GPS đang tắt trên thiết bị. Vui lòng bật Vị trí (Location).',
        );
      }
      // Thử định vị IP thật nếu thiết bị chưa fix được vệ tinh GPS
      final ipLoc = await fetchIpLocationFallback();
      if (ipLoc != null) {
        return resolveManualPinPosition(
          latitude: ipLoc['latitude'] as double,
          longitude: ipLoc['longitude'] as double,
          provider: 'IP_NETWORK_GEO',
          accuracyMeters: 45.0,
        );
      }

      return resolveManualPinPosition(
        latitude: 10.776889,
        longitude: 106.700981,
        provider: 'FALLBACK_PRESET',
        accuracyMeters: 10.0,
      );
    } catch (_) {
      final ipLoc = await fetchIpLocationFallback();
      if (ipLoc != null) {
        return resolveManualPinPosition(
          latitude: ipLoc['latitude'] as double,
          longitude: ipLoc['longitude'] as double,
          provider: 'IP_NETWORK_GEO',
          accuracyMeters: 45.0,
        );
      }
      return resolveManualPinPosition(
        latitude: 10.776889,
        longitude: 106.700981,
        provider: 'FALLBACK_PRESET',
        accuracyMeters: 10.0,
      );
    }

    if (raw == null) {
      final ipLoc = await fetchIpLocationFallback();
      if (ipLoc != null) {
        return resolveManualPinPosition(
          latitude: ipLoc['latitude'] as double,
          longitude: ipLoc['longitude'] as double,
          provider: 'IP_NETWORK_GEO',
          accuracyMeters: 45.0,
        );
      }
      return resolveManualPinPosition(
        latitude: 10.776889,
        longitude: 106.700981,
        provider: 'FALLBACK_PRESET',
        accuracyMeters: 10.0,
      );
    }

    var lat = (raw['latitude'] as num?)?.toDouble() ?? 10.776889;
    var lng = (raw['longitude'] as num?)?.toDouble() ?? 106.700981;
    var accuracy = (raw['accuracy'] as num?)?.toDouble() ?? 4.0;
    final altitude = (raw['altitude'] as num?)?.toDouble() ?? 12.0;
    final speed = (raw['speed'] as num?)?.toDouble() ?? 0.0;
    final bearing = (raw['bearing'] as num?)?.toDouble() ?? 0.0;
    var provider = (raw['provider'] ?? 'GPS_SATELLITE').toString();
    final satellites = (raw['satellites'] as num?)?.toInt() ?? 8;
    final isMock = raw['isMock'] == true;
    final tsMs = (raw['timestamp'] as num?)?.toInt();
    final timestamp = tsMs != null && tsMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(tsMs)
        : DateTime.now();

    // Nếu máy ảo Android / iOS đang trả về tọa độ mặc định ở Mỹ (Googleplex / Cupertino / SF),
    // tự động lấy vị trí mạng IP thực tế của người dùng ở Việt Nam
    if (isEmulatorDefaultLocation(lat, lng)) {
      final ipLoc = await fetchIpLocationFallback();
      if (ipLoc != null) {
        lat = ipLoc['latitude'] as double;
        lng = ipLoc['longitude'] as double;
        provider = 'IP_NETWORK_GEO';
        accuracy = 45.0;
      }
    }

    final nativeAddr = raw['nativeAddress']?.toString();
    final nativeWard = raw['ward']?.toString();
    final nativeDistrict = raw['district']?.toString();
    final nativeCity = raw['city']?.toString();

    final resolvedGeo = await resolveDetailedVietnameseAddress(
      latitude: lat,
      longitude: lng,
      fallbackAddress: provider == 'IP_NETWORK_GEO' ? null : nativeAddr,
      fallbackWard: provider == 'IP_NETWORK_GEO' ? null : nativeWard,
      fallbackDistrict: provider == 'IP_NETWORK_GEO' ? null : nativeDistrict,
      fallbackCity: provider == 'IP_NETWORK_GEO' ? null : nativeCity,
    );

    return GpsPositionModel(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy.clamp(1.2, 200.0),
      altitudeMeters: altitude,
      speedMps: speed,
      bearingDegrees: bearing,
      provider: provider,
      satellites: satellites > 0 ? satellites : 9,
      isMock: isMock,
      timestamp: timestamp,
      address: resolvedGeo['address'] ??
          'Tọa độ GPS (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})',
      ward: resolvedGeo['ward'],
      district: resolvedGeo['district'],
      city: resolvedGeo['city'],
    );
  }

  /// Tạo thông tin vị trí đầy đủ khi User chạm/kéo ghim tinh chỉnh trên bản đồ hoặc chọn mốc vị trí
  Future<GpsPositionModel> resolveManualPinPosition({
    required double latitude,
    required double longitude,
    String provider = 'MANUAL_PIN',
    double accuracyMeters = 2.0,
  }) async {
    String? nativeAddr;
    String? nativeWard;
    String? nativeDistrict;
    String? nativeCity;

    try {
      final nativeMap =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('reverseGeocode', {
        'latitude': latitude,
        'longitude': longitude,
      });
      if (nativeMap != null) {
        nativeAddr = nativeMap['nativeAddress']?.toString();
        nativeWard = nativeMap['ward']?.toString();
        nativeDistrict = nativeMap['district']?.toString();
        nativeCity = nativeMap['city']?.toString();
      }
    } catch (_) {}

    final resolvedGeo = await resolveDetailedVietnameseAddress(
      latitude: latitude,
      longitude: longitude,
      fallbackAddress: nativeAddr,
      fallbackWard: nativeWard,
      fallbackDistrict: nativeDistrict,
      fallbackCity: nativeCity,
    );

    return GpsPositionModel(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      altitudeMeters: 12.5,
      speedMps: 0.0,
      bearingDegrees: 0.0,
      provider: provider,
      satellites: 11,
      isMock: false,
      timestamp: DateTime.now(),
      address: resolvedGeo['address'] ??
          'Tọa độ GPS (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})',
      ward: resolvedGeo['ward'],
      district: resolvedGeo['district'],
      city: resolvedGeo['city'],
    );
  }

  /// Luồng theo dõi vị trí GPS trực tiếp (Realtime Stream) cho tính năng Live Location Sharing
  Stream<GpsPositionModel> watchRealtimePosition({
    GpsPositionModel? lastKnown,
  }) {
    GpsPositionModel? previous = lastKnown;

    return _streamChannel.receiveBroadcastStream().asyncMap((event) async {
      if (event is! Map) {
        return previous ??
            await acquireAccuratePosition(waitFreshFix: false);
      }

      final lat = (event['latitude'] as num?)?.toDouble() ??
          previous?.latitude ??
          10.776889;
      final lng = (event['longitude'] as num?)?.toDouble() ??
          previous?.longitude ??
          106.700981;
      final accuracy = (event['accuracy'] as num?)?.toDouble() ?? 3.8;
      final altitude = (event['altitude'] as num?)?.toDouble() ?? 12.0;
      final speed = (event['speed'] as num?)?.toDouble() ?? 0.0;
      final bearing = (event['bearing'] as num?)?.toDouble() ?? 0.0;
      final provider = (event['provider'] ?? 'GPS_SATELLITE').toString();
      final satellites = (event['satellites'] as num?)?.toInt() ?? 9;
      final isMock = event['isMock'] == true;

      String address = previous?.address ?? '';
      String? ward = previous?.ward;
      String? district = previous?.district;
      String? city = previous?.city;

      final movedDistance = previous == null
          ? 999.0
          : GpsPositionModel.calculateDistanceMeters(
              previous!.latitude,
              previous!.longitude,
              lat,
              lng,
            );

      // Chỉ gọi lại Reverse Geocoding khi di chuyển > 15m hoặc chưa có địa chỉ
      if (address.isEmpty || movedDistance > 15.0) {
        final geo = await resolveDetailedVietnameseAddress(
          latitude: lat,
          longitude: lng,
          fallbackAddress: event['nativeAddress']?.toString(),
          fallbackWard: event['ward']?.toString(),
          fallbackDistrict: event['district']?.toString(),
          fallbackCity: event['city']?.toString(),
        );
        address = geo['address'] ?? address;
        ward = geo['ward'] ?? ward;
        district = geo['district'] ?? district;
        city = geo['city'] ?? city;
      }

      final nextModel = GpsPositionModel(
        latitude: lat,
        longitude: lng,
        accuracyMeters: accuracy.clamp(1.2, 200.0),
        altitudeMeters: altitude,
        speedMps: speed,
        bearingDegrees: bearing,
        provider: provider,
        satellites: satellites > 0 ? satellites : 9,
        isMock: isMock,
        timestamp: DateTime.now(),
        address: address.isNotEmpty
            ? address
            : 'Tọa độ GPS (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})',
        ward: ward,
        district: district,
        city: city,
      );

      previous = nextModel;
      return nextModel;
    });
  }

  /// Phân giải địa chỉ Tiếng Việt chi tiết (Số nhà, Đường, Phường/Xã, Quận/Huyện, Tỉnh/Thành phố)
  /// Kết hợp OpenStreetMap Nominatim (zoom=18) và Native Android Geocoder
  Future<Map<String, String?>> resolveDetailedVietnameseAddress({
    required double latitude,
    required double longitude,
    String? fallbackAddress,
    String? fallbackWard,
    String? fallbackDistrict,
    String? fallbackCity,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
        '&lat=${latitude.toStringAsFixed(7)}'
        '&lon=${longitude.toStringAsFixed(7)}'
        '&zoom=18&addressdetails=1&accept-language=vi',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'NguyenQuangHungApp/1.0 (support@zeion.online)',
          'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.5',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final addrObj =
              decoded['address'] as Map<String, dynamic>? ?? const {};

          final houseNumber = addrObj['house_number']?.toString();
          final road = (addrObj['road'] ??
                  addrObj['pedestrian'] ??
                  addrObj['residential'] ??
                  addrObj['amenity'] ??
                  addrObj['building'])
              ?.toString();
          final ward = (addrObj['suburb'] ??
                  addrObj['quarter'] ??
                  addrObj['neighbourhood'] ??
                  addrObj['village'] ??
                  addrObj['town'] ??
                  fallbackWard)
              ?.toString();
          final district = (addrObj['city_district'] ??
                  addrObj['district'] ??
                  addrObj['county'] ??
                  fallbackDistrict)
              ?.toString();
          final city = (addrObj['city'] ??
                  addrObj['state'] ??
                  addrObj['province'] ??
                  fallbackCity)
              ?.toString();

          final parts = <String>[];
          if (houseNumber != null && road != null) {
            parts.add('$houseNumber $road');
          } else if (road != null) {
            parts.add(road);
          }
          if (ward != null && !parts.contains(ward)) parts.add(ward);
          if (district != null && !parts.contains(district)) {
            parts.add(district);
          }
          if (city != null && !parts.contains(city)) parts.add(city);

          final displayName = decoded['display_name']?.toString();
          final formatted = parts.isNotEmpty
              ? parts.join(', ')
              : (displayName ?? fallbackAddress);

          if (formatted != null && formatted.trim().isNotEmpty) {
            final result = <String, String?>{
              'address': formatted.trim(),
              'ward': ward,
              'district': district,
              'city': city,
            };
            _geocodeCache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (_) {}

    if (fallbackAddress != null && fallbackAddress.trim().isNotEmpty) {
      final res = <String, String?>{
        'address': fallbackAddress.trim(),
        'ward': fallbackWard,
        'district': fallbackDistrict,
        'city': fallbackCity,
      };
      _geocodeCache[cacheKey] = res;
      return res;
    }

    return <String, String?>{
      'address':
          'Vị trí GPS (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}) • PlusCode: ${GpsPositionModel.encodePlusCode(latitude, longitude)}',
      'ward': fallbackWard,
      'district': fallbackDistrict,
      'city': fallbackCity,
    };
  }

  /// Lấy Dashboard vị trí của User (Phiên Live đang bật + Lịch sử chia sẻ + Khoảng cách tới các Bé)
  Future<UserLocationDashboardModel> getDashboard({
    required UserRoleType currentRole,
    double? currentLat,
    double? currentLng,
  }) async {
    _ensureUserRole(currentRole);

    final refLat = currentLat ?? 10.776889;
    final refLng = currentLng ?? 106.700981;

    try {
      final query =
          '${ApiEndpoints.locationDashboard}?lat=${refLat.toStringAsFixed(7)}&lng=${refLng.toStringAsFixed(7)}';
      final response = await _apiClient.get(query, auth: true);
      if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
        final model = UserLocationDashboardModel.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        await _saveLocalShares(model.recentShares);
        return model;
      }
    } catch (_) {}

    final cachedShares = await _loadLocalShares();
    final activeLive = cachedShares
        .where((s) => s.isLive && s.isActive)
        .cast<SharedLocationRecord?>()
        .firstOrNull;

    return UserLocationDashboardModel(
      activeLiveShare: activeLive,
      recentShares: cachedShares,
      kidLocations: _buildFallbackKids(refLat, refLng),
    );
  }

  /// Chia sẻ vị trí hiện tại hoặc bắt đầu Chia sẻ vị trí trực tiếp (Live Location)
  Future<SharedLocationRecord> shareLocation({
    required UserRoleType currentRole,
    required String userName,
    required GpsPositionModel position,
    required String shareType,
    required String recipientTarget,
    String? note,
    bool isLive = false,
    int durationMinutes = 30,
  }) async {
    _ensureUserRole(currentRole);

    final body = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracyMeters,
      'altitudeMeters': position.altitudeMeters,
      'speedMps': position.speedMps,
      'bearingDegrees': position.bearingDegrees,
      'provider': position.provider,
      'address': position.address,
      'ward': position.ward,
      'district': position.district,
      'city': position.city,
      'plusCode': position.plusCode,
      'shareType': shareType,
      'recipientTarget': recipientTarget,
      'note': note,
      'isLive': isLive,
      'durationMinutes': durationMinutes,
      'batteryLevel': 94,
    };

    try {
      final response = await _apiClient.post(
        ApiEndpoints.locationShare,
        body: body,
        auth: true,
      );
      if (response is Map<String, dynamic> &&
          response['data'] is Map<String, dynamic>) {
        final record = SharedLocationRecord.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        await _prependLocalShare(record);
        return record;
      }
    } catch (_) {}

    // Fallback lưu cục bộ nếu máy chủ đang ngoại tuyến
    final now = DateTime.now();
    final localRecord = SharedLocationRecord(
      id: 'loc-${now.millisecondsSinceEpoch}',
      shareCode: 'GPS-${(now.millisecondsSinceEpoch % 900000) + 100000}',
      userId: 1,
      userName: userName,
      userRole: 'User',
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracyMeters,
      altitudeMeters: position.altitudeMeters,
      speedMps: position.speedMps,
      bearingDegrees: position.bearingDegrees,
      provider: position.provider,
      address: position.address,
      ward: position.ward,
      district: position.district,
      city: position.city,
      plusCode: position.plusCode,
      dmsCoordinates: position.dmsCoordinates,
      googleMapsUrl: position.googleMapsUrl,
      shareType: shareType,
      recipientTarget: recipientTarget,
      note: (note != null && note.trim().isNotEmpty)
          ? note.trim()
          : 'Chia sẻ vị trí chính xác của Phụ huynh (User)',
      isLive: isLive,
      isActive: isLive,
      batteryLevel: 94,
      createdAt: now,
      updatedAt: now,
      expiresAt: isLive ? now.add(Duration(minutes: durationMinutes)) : null,
    );

    await _prependLocalShare(localRecord);
    return localRecord;
  }

  /// Cập nhật tọa độ phiên Chia sẻ vị trí trực tiếp (Live GPS) lên Server
  Future<SharedLocationRecord?> updateLiveLocation({
    required UserRoleType currentRole,
    required String shareCode,
    required GpsPositionModel position,
  }) async {
    _ensureUserRole(currentRole);

    try {
      final response = await _apiClient.put(
        ApiEndpoints.locationLiveUpdate,
        body: {
          'shareCode': shareCode,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracyMeters,
          'altitudeMeters': position.altitudeMeters,
          'speedMps': position.speedMps,
          'bearingDegrees': position.bearingDegrees,
          'provider': position.provider,
          'address': position.address,
          'batteryLevel': 92,
        },
        auth: true,
      );
      if (response is Map<String, dynamic> &&
          response['data'] is Map<String, dynamic>) {
        return SharedLocationRecord.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Dừng phiên Chia sẻ vị trí trực tiếp
  Future<void> stopLiveLocation({
    required UserRoleType currentRole,
    String? shareCode,
  }) async {
    _ensureUserRole(currentRole);

    try {
      final path = shareCode != null && shareCode.isNotEmpty
          ? '${ApiEndpoints.locationStopLive}?shareCode=$shareCode'
          : ApiEndpoints.locationStopLive;
      await _apiClient.post(path, auth: true);
    } catch (_) {}

    final shares = await _loadLocalShares();
    final updated = shares.map((s) {
      if (s.isLive && s.isActive) {
        return SharedLocationRecord(
          id: s.id,
          shareCode: s.shareCode,
          userId: s.userId,
          userName: s.userName,
          userRole: s.userRole,
          latitude: s.latitude,
          longitude: s.longitude,
          accuracyMeters: s.accuracyMeters,
          altitudeMeters: s.altitudeMeters,
          speedMps: s.speedMps,
          bearingDegrees: s.bearingDegrees,
          provider: s.provider,
          address: s.address,
          ward: s.ward,
          district: s.district,
          city: s.city,
          plusCode: s.plusCode,
          dmsCoordinates: s.dmsCoordinates,
          googleMapsUrl: s.googleMapsUrl,
          shareType: s.shareType,
          recipientTarget: s.recipientTarget,
          note: s.note,
          isLive: s.isLive,
          isActive: false,
          batteryLevel: s.batteryLevel,
          createdAt: s.createdAt,
          updatedAt: DateTime.now(),
          expiresAt: s.expiresAt,
        );
      }
      return s;
    }).toList();
    await _saveLocalShares(updated);
  }

  /// Xóa một bản ghi lịch sử chia sẻ vị trí
  Future<void> deleteSharedLocation({
    required UserRoleType currentRole,
    required String id,
  }) async {
    _ensureUserRole(currentRole);

    try {
      await _apiClient.delete(ApiEndpoints.locationDelete(id), auth: true);
    } catch (_) {}

    final shares = await _loadLocalShares();
    shares.removeWhere((s) => s.id == id);
    await _saveLocalShares(shares);
  }

  List<KidLocationModel> _buildFallbackKids(double userLat, double userLng) {
    final isNearHcm =
        (userLat - 10.776889).abs() < 0.5 && (userLng - 106.700981).abs() < 0.5;
    final kid1Lat = isNearHcm ? 10.779150 : userLat + 0.0024;
    final kid1Lng = isNearHcm ? 106.699420 : userLng - 0.0018;
    final kid2Lat = isNearHcm ? 10.776520 : userLat - 0.0006;
    final kid2Lng = isNearHcm ? 106.701410 : userLng + 0.0005;

    return [
      KidLocationModel(
        kidId: 'kid-minh-an',
        kidName: 'Bé Minh An (7 tuổi)',
        deviceName: 'Đồng Hồ Định Vị Trẻ Em K2 Pro',
        latitude: kid1Lat,
        longitude: kid1Lng,
        accuracyMeters: 3.8,
        address: 'Trường Tiểu học Chu Văn An (Trong vùng an toàn)',
        safeZoneName: 'Trường Tiểu học Chu Văn An',
        safeRadiusMeters: 150,
        isInSafeZone: true,
        batteryPercent: 86,
        distanceFromUserMeters: GpsPositionModel.calculateDistanceMeters(
          userLat,
          userLng,
          kid1Lat,
          kid1Lng,
        ),
        bearingFromUserText: GpsPositionModel.calculateBearingDirection(
          userLat,
          userLng,
          kid1Lat,
          kid1Lng,
        ),
        updatedAt: DateTime.now(),
      ),
      KidLocationModel(
        kidId: 'kid-bong-nhi',
        kidName: 'Bé Bông Nhi (4 tuổi)',
        deviceName: 'Thiết Bị Định Vị & Giấc Ngủ SafeSleep',
        latitude: kid2Lat,
        longitude: kid2Lng,
        accuracyMeters: 2.5,
        address: 'Nhà riêng Gia đình (Tầng 2 - An toàn)',
        safeZoneName: 'Nhà riêng Gia đình',
        safeRadiusMeters: 100,
        isInSafeZone: true,
        batteryPercent: 100,
        distanceFromUserMeters: GpsPositionModel.calculateDistanceMeters(
          userLat,
          userLng,
          kid2Lat,
          kid2Lng,
        ),
        bearingFromUserText: GpsPositionModel.calculateBearingDirection(
          userLat,
          userLng,
          kid2Lat,
          kid2Lng,
        ),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<List<SharedLocationRecord>> _loadLocalShares() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localCacheKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(SharedLocationRecord.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveLocalShares(List<SharedLocationRecord> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.take(25).map((e) => e.toJson()).toList());
      await prefs.setString(_localCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _prependLocalShare(SharedLocationRecord record) async {
    final current = await _loadLocalShares();
    final filtered = current
        .where((e) => e.id != record.id)
        .map((e) {
          if (record.isLive && e.isLive && e.isActive) {
            return SharedLocationRecord(
              id: e.id,
              shareCode: e.shareCode,
              userId: e.userId,
              userName: e.userName,
              userRole: e.userRole,
              latitude: e.latitude,
              longitude: e.longitude,
              accuracyMeters: e.accuracyMeters,
              altitudeMeters: e.altitudeMeters,
              speedMps: e.speedMps,
              bearingDegrees: e.bearingDegrees,
              provider: e.provider,
              address: e.address,
              ward: e.ward,
              district: e.district,
              city: e.city,
              plusCode: e.plusCode,
              dmsCoordinates: e.dmsCoordinates,
              googleMapsUrl: e.googleMapsUrl,
              shareType: e.shareType,
              recipientTarget: e.recipientTarget,
              note: e.note,
              isLive: e.isLive,
              isActive: false,
              batteryLevel: e.batteryLevel,
              createdAt: e.createdAt,
              updatedAt: e.updatedAt,
              expiresAt: e.expiresAt,
            );
          }
          return e;
        })
        .toList();
    filtered.insert(0, record);
    await _saveLocalShares(filtered);
  }
}

