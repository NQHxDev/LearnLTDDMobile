import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/location_models.dart';
import '../../data/services/location_service.dart';
import '../widgets/location_map_preview_widget.dart';

class LocationShareScreen extends StatefulWidget {
  final AuthController authController;
  final bool isEmbeddedInTab;
  final String initialShareType;
  final String initialRecipient;
  final String? initialNote;

  const LocationShareScreen({
    super.key,
    required this.authController,
    this.isEmbeddedInTab = false,
    this.initialShareType = 'pickup',
    this.initialRecipient = 'Gia đình & Bé Minh An',
    this.initialNote,
  });

  /// Mở màn hình Chia sẻ vị trí chuẩn xác dành riêng cho User từ bất kỳ đâu
  static Future<void> open(
    BuildContext context, {
    required AuthController authController,
    String initialShareType = 'pickup',
    String initialRecipient = 'Gia đình & Bé Minh An',
    String? initialNote,
  }) async {
    if (authController.currentRoleType != UserRoleType.user) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Tính năng Chia sẻ vị trí là chức năng dành riêng cho User (Phụ huynh).',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationShareScreen(
          authController: authController,
          isEmbeddedInTab: false,
          initialShareType: initialShareType,
          initialRecipient: initialRecipient,
          initialNote: initialNote,
        ),
      ),
    );
  }

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _noteController = TextEditingController();

  GpsPositionModel _currentPosition = GpsPositionModel(
    latitude: 10.776889,
    longitude: 106.700981,
    accuracyMeters: 3.4,
    altitudeMeters: 12.5,
    speedMps: 0.0,
    bearingDegrees: 90.0,
    provider: 'GPS_SATELLITE',
    satellites: 10,
    timestamp: DateTime.now(),
    address: 'Đường Đồng Khởi, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    ward: 'Phường Bến Nghé',
    district: 'Quận 1',
    city: 'TP. Hồ Chí Minh',
  );

  List<SharedLocationRecord> _recentShares = [];
  List<KidLocationModel> _kidLocations = [];
  SharedLocationRecord? _activeLiveShare;

  bool _isAcquiringGps = false;
  bool _isSubmittingShare = false;
  bool _isLiveTracking = false;
  int _liveUpdateCount = 0;
  int _selectedDurationMinutes = 30;
  late String _selectedShareType;
  late String _selectedRecipient;
  String? _statusBannerMessage;
  bool _isErrorBanner = false;

  StreamSubscription<GpsPositionModel>? _gpsStreamSub;

  static const List<Map<String, dynamic>> _shareTypeOptions = [
    {
      'value': 'pickup',
      'label': 'Điểm đón Bé',
      'icon': Icons.child_care_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'value': 'current',
      'label': 'Vị trí hiện tại',
      'icon': Icons.my_location_rounded,
      'color': Color(0xFF059669),
    },
    {
      'value': 'safe_point',
      'label': 'Điểm hẹn Gia đình',
      'icon': Icons.home_work_rounded,
      'color': Color(0xFF7C3AED),
    },
    {
      'value': 'sos',
      'label': 'Khẩn cấp SOS',
      'icon': Icons.sos_rounded,
      'color': Color(0xFFDC2626),
    },
  ];

  static const List<String> _recipientOptions = [
    'Gia đình & Bé Minh An',
    'Đồng hồ Bé Minh An (K2 Pro)',
    'Thiết bị Bé Bông Nhi',
    'Tất cả thành viên Gia đình',
    'Đội Hỗ trợ Kỹ thuật & SOS',
  ];

  static const List<String> _quickNotes = [
    'Ba/Mẹ đang đứng ở cổng chính chờ đón con nhé!',
    'Ba/Mẹ đã tới điểm hẹn an toàn, con ra vị trí ghim này nhé.',
    'Vị trí hiện tại chính xác của Ba/Mẹ.',
    'Cần hỗ trợ khẩn cấp tại đúng tọa độ GPS này!',
  ];

  @override
  void initState() {
    super.initState();
    _selectedShareType = widget.initialShareType;
    _selectedRecipient = widget.initialRecipient;
    _noteController.text = widget.initialNote ??
        'Ba/Mẹ đang đứng ở cổng chính chờ đón con nhé!';
    _initializeLocationAndDashboard();
  }

  @override
  void dispose() {
    _gpsStreamSub?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  String get _userDisplayName {
    final user = widget.authController.currentUser;
    if (user != null && user.fullName.trim().isNotEmpty) {
      return user.fullName.trim();
    }
    return 'Phụ huynh (User)';
  }

  Future<void> _initializeLocationAndDashboard() async {
    await _refreshHardwareGps(silent: true);
    await _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    try {
      final dashboard = await _locationService.getDashboard(
        currentRole: widget.authController.currentRoleType,
        currentLat: _currentPosition.latitude,
        currentLng: _currentPosition.longitude,
      );
      if (!mounted) return;
      setState(() {
        _activeLiveShare = dashboard.activeLiveShare;
        _recentShares = dashboard.recentShares;
        _kidLocations = dashboard.kidLocations
            .map(
              (k) => k.withDistanceToUser(
                _currentPosition.latitude,
                _currentPosition.longitude,
              ),
            )
            .toList();
        if (_activeLiveShare != null &&
            _activeLiveShare!.isActive &&
            !_isLiveTracking) {
          _startRealtimeStreamOnly();
        }
      });
    } catch (_) {}
  }

  Future<void> _refreshHardwareGps({bool silent = false}) async {
    if (_isAcquiringGps) return;
    setState(() {
      _isAcquiringGps = true;
      if (!silent) {
        _statusBannerMessage =
            'Đang khóa tín hiệu vệ tinh GPS độ chính xác cao...';
        _isErrorBanner = false;
      }
    });

    try {
      final pos = await _locationService.acquireAccuratePosition(
        waitFreshFix: true,
      );
      if (!mounted) return;

      // Kiểm tra nếu máy ảo Android đang trả về tọa độ mặc định Googleplex Mountain View (Mỹ: 37.421998, -122.084)
      final isEmulatorDefaultUsa = (pos.latitude - 37.421998).abs() < 0.05 &&
          (pos.longitude - (-122.084)).abs() < 0.05;

      setState(() {
        _currentPosition = pos;
        _isAcquiringGps = false;
        _kidLocations = _kidLocations
            .map((k) => k.withDistanceToUser(pos.latitude, pos.longitude))
            .toList();
        _statusBannerMessage = isEmulatorDefaultUsa
            ? 'Đã lấy GPS từ thiết bị (±${pos.accuracyMeters.toStringAsFixed(1)}m). Máy ảo đang để GPS mặc định tại Mỹ — bạn có thể chạm mốc Việt Nam bên dưới hoặc chạm bản đồ để ghim!'
            : 'Đã khóa vị trí GPS chuẩn xác (±${pos.accuracyMeters.toStringAsFixed(1)}m) • ${pos.address}';
        _isErrorBanner = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll(RegExp(r'ApiException\(\d+\): '), '');
      setState(() {
        _isAcquiringGps = false;
        _statusBannerMessage = msg;
        _isErrorBanner = true;
      });
    }
  }

  Future<void> _handleMapPinCalibrated(Offset latLng) async {
    HapticFeedback.selectionClick();
    setState(() {
      _isAcquiringGps = true;
      _statusBannerMessage =
          'Đang phân giải địa chỉ chính xác tại điểm ghim (${latLng.dx.toStringAsFixed(6)}, ${latLng.dy.toStringAsFixed(6)})...';
      _isErrorBanner = false;
    });

    final pinned = await _locationService.resolveManualPinPosition(
      latitude: latLng.dx,
      longitude: latLng.dy,
      provider: 'MANUAL_PIN',
      accuracyMeters: 1.5,
    );

    if (!mounted) return;
    setState(() {
      _currentPosition = pinned;
      _isAcquiringGps = false;
      _kidLocations = _kidLocations
          .map((k) => k.withDistanceToUser(pinned.latitude, pinned.longitude))
          .toList();
      _statusBannerMessage =
          'Đã tinh chỉnh ghim chuẩn xác (±1.5m): ${pinned.address}';
      _isErrorBanner = false;
    });
  }

  Future<void> _shareCurrentLocationNow({bool alsoOpenNativeSheet = false}) async {
    if (_isSubmittingShare) return;
    setState(() {
      _isSubmittingShare = true;
    });

    try {
      final shared = await _locationService.shareLocation(
        currentRole: widget.authController.currentRoleType,
        userName: _userDisplayName,
        position: _currentPosition,
        shareType: _selectedShareType,
        recipientTarget: _selectedRecipient,
        note: _noteController.text.trim(),
        isLive: false,
      );

      if (!mounted) return;
      setState(() {
        _isSubmittingShare = false;
        _recentShares = [
          shared,
          ..._recentShares.where((s) => s.id != shared.id),
        ];
        _statusBannerMessage =
            'Đã chia sẻ vị trí thành công (Mã: ${shared.shareCode}) tới $_selectedRecipient!';
        _isErrorBanner = false;
      });

      if (alsoOpenNativeSheet) {
        final msg = _currentPosition.toShareableMessage(
          userName: _userDisplayName,
          note: _noteController.text.trim(),
          shareCode: shared.shareCode,
          recipientTarget: _selectedRecipient,
          isLive: false,
        );
        await _locationService.shareViaSystemSheet(text: msg);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Đã phát vị trí chuẩn xác (${shared.shareCode}) tới $_selectedRecipient!',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingShare = false;
        _statusBannerMessage = e.toString();
        _isErrorBanner = true;
      });
    }
  }

  Future<void> _toggleLiveLocationSharing() async {
    if (_isLiveTracking) {
      await _stopLiveSharing();
    } else {
      await _startLiveSharing();
    }
  }

  Future<void> _startLiveSharing() async {
    setState(() {
      _isSubmittingShare = true;
    });

    try {
      final liveRecord = await _locationService.shareLocation(
        currentRole: widget.authController.currentRoleType,
        userName: _userDisplayName,
        position: _currentPosition,
        shareType: 'live',
        recipientTarget: _selectedRecipient,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Đang chia sẻ hành trình di chuyển trực tiếp (Live GPS)',
        isLive: true,
        durationMinutes: _selectedDurationMinutes,
      );

      if (!mounted) return;
      setState(() {
        _isSubmittingShare = false;
        _activeLiveShare = liveRecord;
        _isLiveTracking = true;
        _liveUpdateCount = 1;
        _recentShares = [
          liveRecord,
          ..._recentShares.where((e) => e.id != liveRecord.id),
        ];
        _statusBannerMessage =
            'Đang phát sóng vị trí trực tiếp (LIVE GPS - Mã ${liveRecord.shareCode}) trong $_selectedDurationMinutes phút';
        _isErrorBanner = false;
      });

      _startRealtimeStreamOnly();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingShare = false;
        _statusBannerMessage = e.toString();
        _isErrorBanner = true;
      });
    }
  }

  void _startRealtimeStreamOnly() {
    _gpsStreamSub?.cancel();
    _isLiveTracking = true;
    _gpsStreamSub = _locationService
        .watchRealtimePosition(lastKnown: _currentPosition)
        .listen((livePos) async {
      if (!mounted) return;
      setState(() {
        _currentPosition = livePos;
        _liveUpdateCount++;
        _kidLocations = _kidLocations
            .map(
              (k) => k.withDistanceToUser(
                livePos.latitude,
                livePos.longitude,
              ),
            )
            .toList();
      });

      final code = _activeLiveShare?.shareCode;
      if (code != null && code.isNotEmpty) {
        await _locationService.updateLiveLocation(
          currentRole: widget.authController.currentRoleType,
          shareCode: code,
          position: livePos,
        );
      }
    });
  }

  Future<void> _stopLiveSharing() async {
    await _gpsStreamSub?.cancel();
    _gpsStreamSub = null;

    await _locationService.stopLiveLocation(
      currentRole: widget.authController.currentRoleType,
      shareCode: _activeLiveShare?.shareCode,
    );

    if (!mounted) return;
    setState(() {
      _isLiveTracking = false;
      _activeLiveShare = null;
      _statusBannerMessage = 'Đã dừng chia sẻ vị trí trực tiếp (Live GPS).';
      _isErrorBanner = false;
    });
    await _loadDashboard();
  }

  Future<void> _copyPositionToClipboard({SharedLocationRecord? record}) async {
    final text = record != null
        ? '📍 Vị trí chia sẻ từ ${record.userName} (Mã: ${record.shareCode})\n'
            '🏠 Địa chỉ: ${record.address}\n'
            '🧭 Tọa độ: ${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)} (${record.dmsCoordinates})\n'
            '🎯 Sai số: ±${record.accuracyMeters.toStringAsFixed(1)}m | Plus Code: ${record.plusCode}\n'
            '🗺️ Google Maps: ${record.googleMapsUrl}'
        : _currentPosition.toShareableMessage(
            userName: _userDisplayName,
            note: _noteController.text.trim(),
            shareCode: _activeLiveShare?.shareCode,
            recipientTarget: _selectedRecipient,
            isLive: _isLiveTracking,
          );

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Đã sao chép tọa độ GPS chuẩn xác & liên kết Google Maps vào bộ nhớ tạm!',
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps({
    double? lat,
    double? lng,
    String? label,
  }) async {
    final targetLat = lat ?? _currentPosition.latitude;
    final targetLng = lng ?? _currentPosition.longitude;
    final targetLabel = label ?? 'Vị trí của $_userDisplayName';

    final opened = await _locationService.openInExternalMap(
      latitude: targetLat,
      longitude: targetLng,
      label: targetLabel,
    );

    if (!opened && mounted) {
      await _copyPositionToClipboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.authController.currentRoleType != UserRoleType.user) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chức năng Chia sẻ vị trí chỉ dành riêng cho tài khoản User (Phụ huynh).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bodyContent = RefreshIndicator(
      onRefresh: () async {
        await _refreshHardwareGps(silent: false);
        await _loadDashboard();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // 1. Header chứng nhận chức năng độc quyền của USER & trạng thái GPS
          _buildUserRoleLocationHeader(),
          const SizedBox(height: 12),

          // 2. Thanh thông báo trạng thái định vị / lỗi nếu có
          if (_statusBannerMessage != null) ...[
            _buildStatusBanner(),
            const SizedBox(height: 12),
          ],

          // 3. Bản đồ tương tác trực quan (OpenStreetMap + Radar + Ghim từng mét)
          LocationMapPreviewWidget(
            position: _currentPosition,
            kidLocations: _kidLocations,
            isLiveSharing: _isLiveTracking,
            onTapPinCoordinate: _handleMapPinCalibrated,
            onRecenterHardwareGps: () => _refreshHardwareGps(silent: false),
            onOpenExternalMaps: () => _openInGoogleMaps(),
          ),
          const SizedBox(height: 12),

          // 4. Thanh chọn nhanh mốc chuẩn Việt Nam (Hỗ trợ khi chạy trên Máy ảo Android)
          _buildQuickCalibrationRow(),
          const SizedBox(height: 14),

          // 5. Bảng thông số Tọa độ GPS & Địa chỉ Chuẩn Xác Nhất
          _buildPrecisionTelemetryCard(),
          const SizedBox(height: 14),

          // 6. Trạm Chia sẻ Hành trình Trực tiếp (Live Location Sharing)
          _buildLiveTrackingControlCard(),
          const SizedBox(height: 14),

          // 7. Biểu mẫu Chia sẻ vị trí tức thì & Gửi qua Zalo/SMS/Google Maps
          _buildInstantShareComposerCard(),
          const SizedBox(height: 16),

          // 8. Khoảng cách chính xác từ Vị trí của User tới các Bé (Haversine)
          _buildDistanceToKidsSection(),
          const SizedBox(height: 16),

          // 9. Lịch sử các vị trí đã chia sẻ của User
          _buildSharedHistorySection(),
        ],
      ),
    );

    if (widget.isEmbeddedInTab) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chia Sẻ Vị Trí Chuẩn Xác (User)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Định vị vệ tinh GPS đa tầng & Chia sẻ hành trình trực tiếp',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lấy lại GPS Vệ Tinh',
            icon: _isAcquiringGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF2563EB),
                  ),
            onPressed: () => _refreshHardwareGps(silent: false),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildUserRoleLocationHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLiveTracking
              ? const [Color(0xFF059669), Color(0xFF10B981)]
              : const [Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (_isLiveTracking
                    ? const Color(0xFF059669)
                    : const Color(0xFF2563EB))
                .withAlpha(45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isLiveTracking
                  ? Icons.sensors_rounded
                  : Icons.share_location_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CHỨC NĂNG ĐỘC QUYỀN USER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_isLiveTracking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LIVE #$_liveUpdateCount',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _isLiveTracking
                      ? 'Đang Phát Sóng Hành Trình Trực Tiếp'
                      : 'Định Vị & Chia Sẻ Vị Trí Của Phụ Huynh',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Người chia sẻ: $_userDisplayName • Độ chính xác ±${_currentPosition.accuracyMeters.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final bgColor = _isErrorBanner
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFEFF6FF);
    final borderColor = _isErrorBanner
        ? const Color(0xFFFECACA)
        : const Color(0xFFBFDBFE);
    final textColor = _isErrorBanner
        ? const Color(0xFFB91C1C)
        : const Color(0xFF1E40AF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            _isErrorBanner
                ? Icons.warning_amber_rounded
                : Icons.verified_rounded,
            size: 18,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusBannerMessage!,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isErrorBanner)
            TextButton(
              onPressed: () => _locationService.openLocationSettings(),
              child: const Text(
                'Bật GPS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCalibrationRow() {
    final presets = [
      (
        label: '📡 GPS Vệ Tinh Thật',
        lat: null,
        lng: null,
      ),
      (
        label: '📍 Quận 1, TP.HCM',
        lat: 10.776889,
        lng: 106.700981,
      ),
      (
        label: '📍 Trường Chu Văn An',
        lat: 10.779150,
        lng: 106.699420,
      ),
      (
        label: '📍 Hoàn Kiếm, Hà Nội',
        lat: 21.028511,
        lng: 105.854444,
      ),
      (
        label: '📍 Hải Châu, Đà Nẵng',
        lat: 16.054407,
        lng: 108.202167,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((item) {
          final isHardware = item.lat == null;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor:
                  isHardware ? const Color(0xFFEFF6FF) : Colors.white,
              side: BorderSide(
                color: isHardware
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE2E8F0),
              ),
              label: Text(
                item.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight:
                      isHardware ? FontWeight.bold : FontWeight.w500,
                  color: isHardware
                      ? const Color(0xFF1D4ED8)
                      : AppColors.textPrimary,
                ),
              ),
              onPressed: () {
                if (isHardware) {
                  _refreshHardwareGps(silent: false);
                } else {
                  _handleMapPinCalibrated(Offset(item.lat!, item.lng!));
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrecisionTelemetryCard() {
    final pos = _currentPosition;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa Chỉ & Tọa Độ Chuẩn Xác Của Bạn',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      pos.accuracyGradeLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sao chép tọa độ & địa chỉ',
                icon: const Icon(
                  Icons.copy_all_rounded,
                  color: Color(0xFF2563EB),
                ),
                onPressed: () => _copyPositionToClipboard(),
              ),
            ],
          ),
          const Divider(height: 20),

          // Địa chỉ đường phố Tiếng Việt chi tiết
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ĐỊA CHỈ PHÂN GIẢI TỪ TỌA ĐỘ VỆ TINH:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pos.address,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lưới 4 thông số kỹ thuật chuẩn xác
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'Vĩ độ (Latitude)',
                  value: '${pos.latitude.toStringAsFixed(6)}° N',
                  icon: Icons.explore_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  label: 'Kinh độ (Longitude)',
                  value: '${pos.longitude.toStringAsFixed(6)}° E',
                  icon: Icons.language_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'Độ lệch / Sai số GPS',
                  value: '±${pos.accuracyMeters.toStringAsFixed(1)} mét',
                  icon: Icons.radar_rounded,
                  valueColor: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  label: 'Tọa độ Độ-Phút-Giây',
                  value: pos.dmsCoordinates,
                  icon: Icons.compass_calibration_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'Mã Google Plus Code',
                  value: pos.plusCode,
                  icon: Icons.pin_drop_outlined,
                  valueColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  label: 'Tốc độ & Hướng',
                  value:
                      '${pos.speedKmh.toStringAsFixed(1)} km/h • ${pos.compassHeadingText}',
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingControlCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isLiveTracking ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isLiveTracking
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: _isLiveTracking ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isLiveTracking
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  color: _isLiveTracking
                      ? Colors.white
                      : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chia Sẻ Hành Trình Trực Tiếp (Live GPS)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _isLiveTracking
                          ? 'Đang tự động cập nhật tọa độ khi bạn di chuyển (Mã: ${_activeLiveShare?.shareCode ?? "LIVE"})'
                          : 'Tự động cập nhật vị trí của bạn theo thời gian thực khi đi đón bé',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Thời lượng phát Live:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              ...[15, 30, 60, 120].map((mins) {
                final selected = _selectedDurationMinutes == mins;
                return ChoiceChip(
                  label: Text(
                    mins == 120 ? '2 giờ' : '$mins phút',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: Colors.white,
                  onSelected: _isLiveTracking
                      ? null
                      : (_) =>
                          setState(() => _selectedDurationMinutes = mins),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLiveTracking
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isLiveTracking
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
              ),
              label: Text(
                _isLiveTracking
                    ? 'Dừng Phát Sóng Vị Trí Trực Tiếp (Live)'
                    : 'Bắt Đầu Chia Sẻ Vị Trí Trực Tiếp (Live GPS)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: _isSubmittingShare ? null : _toggleLiveLocationSharing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantShareComposerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thiết Lập & Gửi Vị Trí Chuẩn Xác Của Bạn',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),

          // Chọn loại chia sẻ vị trí
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _shareTypeOptions.map((opt) {
                final val = opt['value'] as String;
                final isSel = _selectedShareType == val;
                final color = opt['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      opt['icon'] as IconData,
                      size: 16,
                      color: isSel ? Colors.white : color,
                    ),
                    label: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: color,
                    backgroundColor: const Color(0xFFF8FAFC),
                    onSelected: (_) => setState(() => _selectedShareType = val),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Chọn người nhận trong gia đình
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipient,
            decoration: InputDecoration(
              labelText: 'Chia sẻ vị trí này tới',
              prefixIcon: const Icon(
                Icons.family_restroom_rounded,
                color: Color(0xFF2563EB),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            items: _recipientOptions
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedRecipient = val);
              }
            },
          ),
          const SizedBox(height: 12),

          // Lời nhắn kèm theo vị trí
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Lời nhắn đính kèm vị trí',
              hintText: 'Ví dụ: Ba đang đứng ở cổng trường đón con...',
              prefixIcon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF2563EB),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Mẫu lời nhắn nhanh
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickNotes.map((note) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: BorderSide.none,
                    label: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    onPressed: () {
                      setState(() => _noteController.text = note);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Các nút hành động Chia sẻ vị trí
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedShareType == 'sos'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSubmittingShare
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _selectedShareType == 'sos'
                    ? 'PHÁT TÍN HIỆU VỊ TRÍ KHẨN CẤP (SOS) NGAY'
                    : 'Chia Sẻ Vị Trí Chuẩn Xác Lên Hệ Thống Gia Đình',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              onPressed: _isSubmittingShare
                  ? null
                  : () => _shareCurrentLocationNow(alsoOpenNativeSheet: false),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text(
                    'Gửi qua Zalo / SMS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () =>
                      _shareCurrentLocationNow(alsoOpenNativeSheet: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 17),
                  label: const Text(
                    'Mở Google Maps',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _openInGoogleMaps(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceToKidsSection() {
    if (_kidLocations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.social_distance_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Khoảng Cách Từ Vị Trí Của Bạn Tới Các Bé',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tính toán chính xác theo công thức mặt cầu Haversine từ tọa độ GPS của bạn',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._kidLocations.map((kid) {
            final dist = kid.distanceFromUserMeters ??
                GpsPositionModel.calculateDistanceMeters(
                  _currentPosition.latitude,
                  _currentPosition.longitude,
                  kid.latitude,
                  kid.longitude,
                );
            final dir = kid.bearingFromUserText ??
                GpsPositionModel.calculateBearingDirection(
                  _currentPosition.latitude,
                  _currentPosition.longitude,
                  kid.latitude,
                  kid.longitude,
                );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(
                          Icons.child_care_rounded,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kid.kidName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              '${kid.deviceName} • Pin ${kid.batteryPercent}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cách bạn ${GpsPositionModel.formatDistanceText(dist)}',
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 Vị trí của bé: ${kid.address} ($dir)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(
                            Icons.send_to_mobile_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Gửi vị trí đón cho Bé',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedShareType = 'pickup';
                              _selectedRecipient =
                                  'Đồng hồ Bé Minh An (K2 Pro)';
                              _noteController.text =
                                  'Ba/Mẹ đang cách con ${GpsPositionModel.formatDistanceText(dist)}, đang đến đón con nhé!';
                            });
                            _shareCurrentLocationNow();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text(
                            'Chỉ đường tới Bé',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _openInGoogleMaps(
                            lat: kid.latitude,
                            lng: kid.longitude,
                            label: kid.kidName,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSharedHistorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lịch Sử Vị Trí Bạn Đã Chia Sẻ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Text(
                '${_recentShares.length} bản ghi',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentShares.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Chưa có lịch sử chia sẻ vị trí. Hãy nhấn nút Chia sẻ vị trí phía trên!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12.5),
                ),
              ),
            )
          else
            ..._recentShares.take(8).map(_buildSharedHistoryItem),
        ],
      ),
    );
  }

  Widget _buildSharedHistoryItem(SharedLocationRecord item) {
    final isSos = item.shareType.toLowerCase() == 'sos';
    final badgeColor = isSos
        ? const Color(0xFFDC2626)
        : (item.isLive && item.isActive
            ? const Color(0xFF059669)
            : const Color(0xFF2563EB));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.shareTypeLabel} • ${item.shareCode}',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '±${item.accuracyMeters.toStringAsFixed(1)}m',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                tooltip: 'Xóa bản ghi này',
                onPressed: () async {
                  await _locationService.deleteSharedLocation(
                    currentRole: widget.authController.currentRoleType,
                    id: item.id,
                  );
                  if (!mounted) return;
                  setState(() {
                    _recentShares.removeWhere((e) => e.id == item.id);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.address,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Gửi tới: ${item.recipientTarget} • "${item.note}"',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Tọa độ: ${item.latitude.toStringAsFixed(6)}, ${item.longitude.toStringAsFixed(6)} (${item.plusCode})',
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF2563EB),
                ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Sao chép', style: TextStyle(fontSize: 11.5)),
                onPressed: () => _copyPositionToClipboard(record: item),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF059669),
                ),
                icon: const Icon(Icons.map_outlined, size: 15),
                label: const Text(
                  'Xem bản đồ',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () => _openInGoogleMaps(
                  lat: item.latitude,
                  lng: item.longitude,
                  label: item.note,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF7C3AED),
                ),
                icon: const Icon(Icons.pin_drop_rounded, size: 15),
                label: const Text(
                  'Đưa lên bản đồ',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () => _handleMapPinCalibrated(
                  Offset(item.latitude, item.longitude),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
