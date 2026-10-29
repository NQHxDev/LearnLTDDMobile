import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../device/data/models/device_model.dart';
import '../../../device/presentation/controllers/device_controller.dart';
import '../../../video_call/presentation/screens/video_call_screen.dart';
import '../../../video_call/presentation/widgets/call_hub_widget.dart';

class StaffDashboardScreen extends StatefulWidget {
  final AuthController authController;

  const StaffDashboardScreen({
    super.key,
    required this.authController,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _currentIndex = 0;
  final DeviceController _deviceController = DeviceController();
  final TextEditingController _handoverNoteController = TextEditingController();

  bool _isOnDuty = true;

  // Checklist công việc trong ca của nhân viên
  final List<Map<String, dynamic>> _shiftTasks = [
    {
      'title': 'Khởi động trạm kiểm tra sóng định vị GPS cho thiết bị',
      'category': 'Kiểm tra phần cứng',
      'done': true,
    },
    {
      'title': 'Kiểm định 5 mẫu đồng hồ SmartWatch nhập lô mới',
      'category': 'Kiểm duyệt thiết bị',
      'done': false,
    },
    {
      'title': 'Xử lý phiếu hỗ trợ phụ huynh bé An về cài đặt SIM 4G',
      'category': 'Hỗ trợ khách hàng',
      'done': true,
    },
    {
      'title': 'Video Call hỗ trợ kết nối camera trẻ em cho gia đình anh Minh',
      'category': 'Hỗ trợ kỹ thuật',
      'done': false,
    },
    {
      'title': 'Bàn giao báo cáo kiểm định thiết bị cho ca chiều',
      'category': 'Vận hành',
      'done': false,
    },
  ];

  // Trạng thái kiểm định của các thiết bị trong ca trực
  final Map<int, String> _qcStatusMap = {};

  // Danh sách phiếu hỗ trợ phụ huynh
  final List<Map<String, dynamic>> _supportTickets = [
    {
      'id': '#TK-1082',
      'parent': 'Chị Lê Mai Hoa',
      'child': 'Bé Tuấn (6 tuổi)',
      'issue': 'Đồng hồ GPS không cập nhật định vị khi bé vào trường',
      'priority': 'Khẩn cấp',
      'status': 'Đang xử lý',
      'time': '15 phút trước',
    },
    {
      'id': '#TK-1083',
      'parent': 'Anh Hoàng Văn Nam',
      'child': 'Bé Linh (8 tuổi)',
      'issue': 'Yêu cầu gọi Video Call hướng dẫn kết nối âm thanh 2 chiều',
      'priority': 'Ưu tiên',
      'status': 'Chờ nhận ca',
      'time': '40 phút trước',
    },
    {
      'id': '#TK-1084',
      'parent': 'Chị Vũ Thùy Dung',
      'child': 'Bé Bắp (4 tuổi)',
      'issue': 'Camera phòng ngủ bé bị mất kết nối Wi-Fi',
      'priority': 'Bình thường',
      'status': 'Đã hoàn tất',
      'time': '2 giờ trước',
    },
  ];

  @override
  void initState() {
    super.initState();
    _deviceController.loadDevices();
  }

  @override
  void dispose() {
    _handoverNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Đăng xuất ca làm việc',
      content: 'Bạn có chắc chắn muốn kết thúc ca trực Nhân viên vận hành (STAFF)?',
      confirmText: 'Kết thúc ca',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    await widget.authController.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(authController: widget.authController),
      ),
      (_) => false,
    );
  }

  void _showQCTestDialog(Device device) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.fact_check_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Kiểm tra kỹ thuật (QC)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'Danh mục: ${device.category} | Model: ${device.modelNumber ?? "Chuẩn"}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const Divider(height: 20),
              _buildQCCheckRow(Icons.gps_fixed_rounded, 'Độ nhạy định vị GPS', 'Sai số < 3m (Đạt)'),
              _buildQCCheckRow(Icons.battery_charging_full_rounded, 'Dung lượng pin thực tế', '100% dung lượng chuẩn'),
              _buildQCCheckRow(Icons.record_voice_over_rounded, 'Loa & Micro đàm thoại 2 chiều', 'Âm lượng lọc ồn tốt'),
              _buildQCCheckRow(Icons.shield_outlined, 'Chỉ số an toàn bức xạ RF trẻ em', 'Đạt chuẩn CE/RoHS'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _qcStatusMap[device.id] = 'Cần bảo trì');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFD97706),
                    content: Text('Đã đánh dấu thiết bị CẦN BẢO TRÌ'),
                  ),
                );
              },
              child: const Text('Báo bảo trì', style: TextStyle(color: Color(0xFFD97706))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() => _qcStatusMap[device.id] = 'Đạt chuẩn 100%');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF059669),
                    content: Text('Thiết bị đã ĐẠT CHUẨN kiểm định kỹ thuật'),
                  ),
                );
              },
              child: const Text('Xác nhận Đạt Chuẩn'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQCCheckRow(IconData icon, String label, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
          Text(result, style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _openLiveVideoCallSupport(
    String ticketId,
    String parentName,
    String issue, {
    bool isAudioOnly = false,
  }) {
    final cleanRoomId = ticketId.replaceAll('#', '').toLowerCase();
    CallHubWidget.launchDirectCall(
      context: context,
      authController: widget.authController,
      roomName: 'ticket-$cleanRoomId',
      description: 'Hỗ trợ $parentName: $issue',
      callType: CallType.support,
      isAudioOnly: isAudioOnly,
      isHost: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: _buildStaffAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildShiftDeskTab(),
          _buildInspectionTab(),
          CallHubWidget(authController: widget.authController),
          _buildTicketsTab(),
          _buildShiftProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildStaffBottomNav(),
    );
  }

  PreferredSizeWidget _buildStaffAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF064E3B),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'STAFF OPERATIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Bàn làm việc Vận hành & Kỹ thuật',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Color(0xFFA7F3D0)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withAlpha(40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF34D399)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOnDuty ? const Color(0xFF34D399) : Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'ROLE: STAFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Kết thúc ca',
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFA7F3D0)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildStaffBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF059669),
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in_rounded),
            label: 'Bàn ca trực',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.biotech_rounded),
            label: 'Kiểm định QC',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_in_talk_rounded),
            label: 'Gọi hỗ trợ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent_rounded),
            label: 'Phiếu hỗ trợ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_rounded),
            label: 'Hồ sơ ca',
          ),
        ],
      ),
    );
  }

  // ================= TAB 0: BÀN CA TRỰC =================
  Widget _buildShiftDeskTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Shift Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ca làm việc: Ca Sáng (08:00 - 16:30)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MÃ NV: STF-77',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Mục tiêu ca trực hôm nay:',
                style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kiểm tra chất lượng thiết bị trẻ em & Sẵn sàng hỗ trợ phụ huynh trực tuyến qua Video Call.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Staff KPI row
        Row(
          children: [
            Expanded(
              child: _buildStaffKpiCard(
                title: 'Đã kiểm định',
                count: '${_qcStatusMap.length}',
                unit: 'thiết bị',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStaffKpiCard(
                title: 'Phiếu hỗ trợ',
                count: '${_supportTickets.length}',
                unit: 'yêu cầu',
                icon: Icons.mark_chat_unread_rounded,
                color: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStaffKpiCard(
                title: 'Nhiệm vụ',
                count: '${_shiftTasks.where((t) => t['done'] == true).length}/${_shiftTasks.length}',
                unit: 'đã xong',
                icon: Icons.checklist_rounded,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Shift Tasks Checklist
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Checklist nhiệm vụ trong ca trực',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF059669), size: 20),
                ],
              ),
              const SizedBox(height: 12),
              ..._shiftTasks.map((task) {
                final bool isDone = task['done'] as bool;

                return InkWell(
                  onTap: () {
                    setState(() {
                      task['done'] = !isDone;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isDone ? const Color(0xFF059669) : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['title'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDone ? Colors.grey : AppColors.textPrimary,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                task['category'],
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffKpiCard({
    required String title,
    required String count,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: TRẠM KIỂM ĐỊNH THIẾT BỊ (QC) =================
  Widget _buildInspectionTab() {
    return ListenableBuilder(
      listenable: _deviceController,
      builder: (context, _) {
        final devices = _deviceController.devices;

        if (_deviceController.isLoading && devices.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));
        }

        return RefreshIndicator(
          onRefresh: () => _deviceController.loadDevices(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.biotech_rounded, color: Color(0xFF065F46), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trạm Kiểm Định Phần Cứng & An Toàn Trẻ Em',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đánh giá cảm biến GPS, pin và bức xạ trước khi bàn giao cho phụ huynh.',
                            style: TextStyle(color: Color(0xFF047857), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...devices.map((device) {
                final status = _qcStatusMap[device.id] ?? 'Chờ kiểm định';
                final isPassed = status == 'Đạt chuẩn 100%';
                final isWarning = status == 'Cần bảo trì';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(Icons.devices_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Loại: ${device.category} | Tồn: ${device.stockQuantity}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPassed
                                    ? const Color(0xFFD1FAE5)
                                    : (isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isPassed
                                      ? const Color(0xFF065F46)
                                      : (isWarning ? const Color(0xFF92400E) : Colors.grey.shade700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showQCTestDialog(device),
                        child: const Text('Kiểm tra', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ================= TAB 2: PHIẾU HỖ TRỢ PHỤ HUYNH =================
  Widget _buildTicketsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Hàng đợi yêu cầu hỗ trợ khách hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Icon(Icons.live_help_rounded, color: Color(0xFF059669)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._supportTickets.map((ticket) {
          final isUrgent = ticket['priority'] == 'Khẩn cấp';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          ticket['id'],
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF064E3B)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ticket['priority'],
                            style: TextStyle(
                              color: isUrgent ? Colors.red.shade700 : Colors.amber.shade900,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(ticket['time'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${ticket['parent']} (${ticket['child']})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket['issue'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trạng thái: ${ticket['status']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF059669)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                          label: const Text('Gọi Thoại', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: () => _openLiveVideoCallSupport(
                            ticket['id'],
                            ticket['parent'],
                            ticket['issue'],
                            isAudioOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.video_call_rounded, size: 18),
                          label: const Text('Video Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: () => _openLiveVideoCallSupport(
                            ticket['id'],
                            ticket['parent'],
                            ticket['issue'],
                            isAudioOnly: false,
                          ),
                        ),
                      ],
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

  // ================= TAB 3: HỒ SƠ CA TRỰC =================
  Widget _buildShiftProfileTab() {
    final user = widget.authController.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFD1FAE5),
                child: const Icon(Icons.engineering_rounded, size: 30, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Nhân Viên Kỹ Thuật',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'staff@childdevices.vn',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VAI TRÒ: NHÂN VIÊN VẬN HÀNH (STAFF)',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Trạng thái trực switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isOnDuty,
              activeThumbColor: const Color(0xFF059669),
              title: const Text('Trạng thái sẵn sàng nhận hỗ trợ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text(_isOnDuty ? 'Đang sẵn sàng kết nối Video Call & nhận phiếu' : 'Đang tạm nghỉ giải lao', style: const TextStyle(fontSize: 11.5)),
              onChanged: (val) {
                setState(() => _isOnDuty = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Ghi chú bàn giao ca
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhật ký bàn giao ca trực:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _handoverNoteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập ghi chú cho nhân viên ca sau (ví dụ: Đã kiểm định xong lô K2, cần liên hệ lại phụ huynh số #1082...)',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã lưu nhật ký bàn giao ca thành công')),
                    );
                  },
                  child: const Text('Lưu ghi chú bàn giao'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Bàn giao ca & Đăng xuất', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }
}
