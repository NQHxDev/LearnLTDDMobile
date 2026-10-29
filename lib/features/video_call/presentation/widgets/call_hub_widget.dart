import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/call_models.dart';
import '../../data/services/video_call_service.dart';
import '../screens/video_call_screen.dart';

class CallHubWidget extends StatefulWidget {
  final AuthController authController;

  const CallHubWidget({
    super.key,
    required this.authController,
  });

  /// Hàm tiện ích dùng chung cho User và Staff để khởi tạo và mở màn hình gọi điện từ bất kỳ đâu
  static Future<void> launchDirectCall({
    required BuildContext context,
    required AuthController authController,
    required String roomName,
    String? description,
    CallType callType = CallType.support,
    bool isAudioOnly = false,
    bool isHost = false,
  }) async {
    final roleType = authController.currentRoleType;

    // Chặn hoàn toàn Admin
    if (roleType == UserRoleType.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Tài khoản Admin không có chức năng gọi điện. Chức năng này chỉ dành cho User và Staff.',
          ),
        ),
      );
      return;
    }

    final user = authController.currentUser;
    final participantName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
        ? user.fullName.trim()
        : (roleType == UserRoleType.staff ? 'Nhân viên hỗ trợ' : 'Phụ huynh');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Đang kết nối Server gọi điện...'),
              ],
            ),
          ),
        ),
      ),
    );

    final service = VideoCallService();
    try {
      final token = await service.startOrJoinCall(
        roomName: roomName,
        participantName: participantName,
        currentRole: roleType,
        callType: callType == CallType.group
            ? 'group'
            : (callType == CallType.oneToOne ? 'one_to_one' : 'support'),
        description: description,
        isAudioOnly: isAudioOnly,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Đóng hộp thoại loading

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            token: token,
            participantName: participantName,
            participantRole: roleType.label,
            callType: callType,
            isHost: isHost,
            initialAudioOnly: isAudioOnly,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Đóng hộp thoại loading

      final errMsg = e
          .toString()
          .replaceAll('ApiException(403): ', '')
          .replaceAll('ApiException(503): ', '')
          .replaceAll('ApiException(400): ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text('Không thể khởi tạo cuộc gọi: $errMsg'),
        ),
      );
    }
  }

  @override
  State<CallHubWidget> createState() => _CallHubWidgetState();
}

class _CallHubWidgetState extends State<CallHubWidget> {
  final VideoCallService _videoCallService = VideoCallService();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _roomDescController = TextEditingController();

  List<VideoCallRoom> _activeRooms = [];
  bool _isLoadingRooms = false;
  String? _errorMessage;

  bool get _isStaff => widget.authController.currentRoleType == UserRoleType.staff;
  Color get _themeColor => _isStaff ? const Color(0xFF059669) : const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadActiveRooms();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _roomDescController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveRooms() async {
    if (widget.authController.currentRoleType == UserRoleType.admin) return;

    setState(() {
      _isLoadingRooms = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _videoCallService.getActiveRooms(
        currentRole: widget.authController.currentRoleType,
      );
      if (mounted) {
        setState(() {
          _activeRooms = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _joinOrCreateCustomRoom({required bool isAudioOnly}) async {
    final code = _roomCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Vui lòng nhập mã phòng gọi (ví dụ: phong-ho-tro-ky-thuat)'),
        ),
      );
      return;
    }

    final desc = _roomDescController.text.trim();
    FocusScope.of(context).unfocus();

    await CallHubWidget.launchDirectCall(
      context: context,
      authController: widget.authController,
      roomName: code,
      description: desc.isNotEmpty ? desc : null,
      isAudioOnly: isAudioOnly,
      isHost: true,
    );

    if (mounted) {
      _loadActiveRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleType = widget.authController.currentRoleType;

    // Bảo vệ lớp UI: Admin không có chức năng gọi điện
    if (roleType == UserRoleType.admin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.phone_disabled_rounded, size: 56, color: Colors.redAccent),
              SizedBox(height: 12),
              Text(
                'Chức năng gọi điện không khả dụng cho Admin',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Chỉ tài khoản User và Staff mới được phép thực hiện cuộc gọi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveRooms,
      color: _themeColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBannerCard(),
          const SizedBox(height: 16),
          _buildQuickChannelsSection(),
          const SizedBox(height: 16),
          _buildCustomRoomCard(),
          const SizedBox(height: 18),
          _buildActiveServerRoomsSection(),
        ],
      ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isStaff
              ? [const Color(0xFF064E3B), const Color(0xFF059669)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _themeColor.withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isStaff
                        ? 'TRUNG TÂM GỌI HỖ TRỢ • STAFF'
                        : 'TỔNG ĐÀI GỌI ĐIỆN • USER & STAFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isStaff
                      ? 'Tiếp nhận cuộc gọi từ Phụ huynh (User)'
                      : 'Gọi Điện Trực Tuyến Với Nhân Viên (Staff) & Bé',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isStaff
                      ? 'Kết nối âm thanh & hình ảnh thời gian thực qua Server LiveKit. Chỉ dành riêng cho Staff và User.'
                      : 'Hỗ trợ kỹ thuật 1-1 cùng nhân viên vận hành (Staff) hoặc gọi trực tiếp cho thiết bị của bé.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.ring_volume_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChannelsSection() {
    final channels = _isStaff
        ? [
            (
              room: 'phong-ho-tro-ky-thuat',
              title: 'Phòng Hỗ Trợ Kỹ Thuật Chung',
              subtitle: 'Trực tiếp nhận cuộc gọi tư vấn từ Phụ huynh (User)',
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF059669),
              type: CallType.support,
            ),
            (
              room: 'ho-tro-khan-cap-sos',
              title: 'Trạm Trực Cứu Hộ SOS 24/7',
              subtitle: 'Kênh ưu tiên xử lý sự cố định vị & SOS của trẻ',
              icon: Icons.emergency_share_rounded,
              color: const Color(0xFFDC2626),
              type: CallType.oneToOne,
            ),
          ]
        : [
            (
              room: 'phong-ho-tro-ky-thuat',
              title: 'Gọi Nhân Viên Kỹ Thuật (STAFF)',
              subtitle: 'Kết nối trực tiếp với Staff đang trực ca hỗ trợ',
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF2563EB),
              type: CallType.support,
            ),
            (
              room: 'ho-tro-khan-cap-sos',
              title: 'Gọi Đường Dây Khẩn Cấp SOS (STAFF)',
              subtitle: 'Liên hệ khẩn cấp với bàn trực vận hành 24/7',
              icon: Icons.emergency_rounded,
              color: const Color(0xFFDC2626),
              type: CallType.oneToOne,
            ),
            (
              room: 'be-minh-an-k2pro',
              title: 'Gọi Đồng Hồ Bé Minh An (K2 Pro)',
              subtitle: 'Đàm thoại 2 chiều với thiết bị đeo của bé',
              icon: Icons.watch_rounded,
              color: const Color(0xFF059669),
              type: CallType.oneToOne,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isStaff ? 'KÊNH TRỰC GỌI NHANH (STAFF <-> USER)' : 'KÊNH GỌI NHANH (USER <-> STAFF)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        ...channels.map((ch) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ch.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(ch.icon, color: ch.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ch.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã phòng: ${ch.room}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ch.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ch.color,
                          side: BorderSide(color: ch.color.withAlpha(140)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                        label: const Text(
                          'Gọi Thoại',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await CallHubWidget.launchDirectCall(
                            context: context,
                            authController: widget.authController,
                            roomName: ch.room,
                            description: ch.subtitle,
                            callType: ch.type,
                            isAudioOnly: true,
                          );
                          if (mounted) _loadActiveRooms();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ch.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.videocam_rounded, size: 18),
                        label: const Text(
                          'Gọi Video',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await CallHubWidget.launchDirectCall(
                            context: context,
                            authController: widget.authController,
                            roomName: ch.room,
                            description: ch.subtitle,
                            callType: ch.type,
                            isAudioOnly: false,
                          );
                          if (mounted) _loadActiveRooms();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomRoomCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.meeting_room_rounded, color: _themeColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tạo hoặc Tham gia phòng bằng Mã phòng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập cùng một mã phòng trên máy của User và Staff để kết nối cuộc gọi trực tiếp qua Server.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            decoration: InputDecoration(
              hintText: 'Nhập mã phòng (VD: tu-van-101, tk-1082...)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
              prefixIcon: Icon(Icons.tag_rounded, color: _themeColor, size: 20),
              suffixIcon: TextButton(
                onPressed: () {
                  final randomNum = DateTime.now().millisecondsSinceEpoch % 900 + 100;
                  _roomCodeController.text = 'call-room-$randomNum';
                  setState(() {});
                },
                child: Text(
                  'Tạo mã',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _themeColor,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _roomDescController,
            decoration: InputDecoration(
              hintText: 'Ghi chú cuộc gọi (tùy chọn)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
              prefixIcon: const Icon(Icons.notes_rounded, color: Colors.grey, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _themeColor,
                    side: BorderSide(color: _themeColor),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Bắt đầu Gọi Thoại', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _joinOrCreateCustomRoom(isAudioOnly: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text('Bắt đầu Gọi Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _joinOrCreateCustomRoom(isAudioOnly: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveServerRoomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'PHÒNG GỌI ĐANG HOẠT ĐỘNG TRÊN SERVER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loadActiveRooms,
              icon: Icon(Icons.refresh_rounded, size: 16, color: _themeColor),
              label: Text(
                'Làm mới',
                style: TextStyle(fontSize: 12, color: _themeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (_isLoadingRooms)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa đồng bộ được danh sách phòng từ Server',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadActiveRooms,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử kết nối lại'),
                ),
              ],
            ),
          )
        else if (_activeRooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Hiện chưa có phòng gọi nào trên Server. Hãy tạo phòng mới ở trên!',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ..._activeRooms.map(_buildServerRoomTile),
      ],
    );
  }

  Widget _buildServerRoomTile(VideoCallRoom room) {
    final hasOnline = room.currentParticipants > 0;
    final creatorRoleUpper = room.createdByRole.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOnline ? _themeColor.withAlpha(120) : const Color(0xFFE2E8F0),
          width: hasOnline ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hasOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.roomName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${room.currentParticipants}/${room.maxParticipants} đang trong phòng',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasOnline ? const Color(0xFF059669) : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (room.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              room.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Tạo bởi: ${room.createdByName.isNotEmpty ? room.createdByName : "Hệ thống"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: creatorRoleUpper == 'STAFF'
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  creatorRoleUpper,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: creatorRoleUpper == 'STAFF'
                        ? const Color(0xFF065F46)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          if (room.participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: room.participants.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '🟢 ${p.name} (${p.role.toUpperCase()})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _themeColor,
                  side: BorderSide(color: _themeColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                label: const Text('Vào gọi thoại', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await CallHubWidget.launchDirectCall(
                    context: context,
                    authController: widget.authController,
                    roomName: room.roomName,
                    description: room.description,
                    isAudioOnly: true,
                  );
                  if (mounted) _loadActiveRooms();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.videocam_rounded, size: 16),
                label: const Text('Vào Video Call', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await CallHubWidget.launchDirectCall(
                    context: context,
                    authController: widget.authController,
                    roomName: room.roomName,
                    description: room.description,
                    isAudioOnly: false,
                  );
                  if (mounted) _loadActiveRooms();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

