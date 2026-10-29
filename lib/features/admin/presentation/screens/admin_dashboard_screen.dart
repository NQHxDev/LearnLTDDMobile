import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../device/data/models/device_model.dart';
import '../../../device/presentation/controllers/device_controller.dart';
import '../../../device/presentation/screens/device_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthController authController;

  const AdminDashboardScreen({
    super.key,
    required this.authController,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  final DeviceController _deviceController = DeviceController();
  final TextEditingController _deviceSearchController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();

  String _selectedCategory = 'Tất cả';
  String _userRoleFilter = 'ALL';
  bool _maintenanceMode = false;

  // Danh sách người dùng mẫu của hệ thống để quản trị phân quyền
  late List<Map<String, dynamic>> _managedUsers;

  @override
  void initState() {
    super.initState();
    _deviceController.loadDevices();

    _managedUsers = [
      {
        'id': 1,
        'name': 'Nguyễn Quang Hưng (Admin)',
        'email': 'anhjkrrr@gmail.com',
        'role': 'ADMIN',
        'isActive': true,
        'createdAt': '2026-10-15',
      },
      {
        'id': 2,
        'name': 'Nguyễn Quang Hưng (Staff)',
        'email': 'anhjkrr@gmail.com',
        'role': 'STAFF',
        'isActive': true,
        'createdAt': '2026-10-18',
      },
      {
        'id': 3,
        'name': 'Nguyễn Quang Hưng (User)',
        'email': 'anhjkr@gmail.com',
        'role': 'USER',
        'isActive': true,
        'createdAt': '2026-10-20',
      },
      {
        'id': 4,
        'name': 'Trần Văn Kỹ Thuật',
        'email': 'staff.kythuat@childdevices.vn',
        'role': 'STAFF',
        'isActive': true,
        'createdAt': '2026-10-22',
      },
      {
        'id': 5,
        'name': 'Hoàng Mai Anh',
        'email': 'maianh.parent@yahoo.com',
        'role': 'USER',
        'isActive': true,
        'createdAt': '2026-10-25',
      },
    ];
  }

  @override
  void dispose() {
    _deviceSearchController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Đăng xuất Quản trị',
      content: 'Bạn có chắc chắn muốn rời khỏi Bàn điều hành Quản trị viên (ADMIN)?',
      confirmText: 'Đăng xuất',
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

  Future<void> _editDevice(Device device) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormScreen(
          deviceController: _deviceController,
          initialDevice: device,
        ),
      ),
    );
    if (updated == true) {
      _deviceController.loadDevices();
    }
  }

  Future<void> _showSelectDeviceToEditSheet() async {
    if (_deviceController.devices.isEmpty && !_deviceController.isLoading) {
      await _deviceController.loadDevices();
    }
    if (!mounted) return;

    final searchCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = _deviceController.devices.where((d) {
              if (query.isEmpty) return true;
              return d.name.toLowerCase().contains(query) ||
                  (d.brand?.toLowerCase().contains(query) ?? false) ||
                  d.category.toLowerCase().contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withAlpha(35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFFFBBF24),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chọn sản phẩm cần chỉnh sửa',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Chạm vào "Sửa sản phẩm" để cập nhật thông tin lên Server',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tìm nhanh sản phẩm theo tên, hãng, danh mục...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF818CF8),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không tìm thấy sản phẩm phù hợp',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtered.length,
                                itemBuilder: (_, idx) {
                                  final item = filtered[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.devices_rounded,
                                            color: Color(0xFF818CF8),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.price.toStringAsFixed(0)} đ • Kho: ${item.stockQuantity} • ${item.category}',
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4F46E5),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.edit_rounded, size: 15),
                                          label: const Text(
                                            'Sửa ngay',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _editDevice(item);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDevice(int id, String name) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Xóa thiết bị (ADMIN)',
      content: 'Bạn có chắc chắn muốn xóa vĩnh viễn thiết bị "$name" khỏi hệ thống?',
      confirmText: 'Xóa ngay',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final success = await _deviceController.deleteDevice(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.success : AppColors.error,
        content: Text(
          success
              ? 'Đã xóa thiết bị thành công'
              : (_deviceController.errorMessage ?? 'Không thể xóa thiết bị'),
        ),
      ),
    );
  }

  void _showDeviceDetailDialog(Device d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: d.imageUrl == null || d.imageUrl!.isEmpty
                        ? const Icon(Icons.devices_rounded, color: Color(0xFF818CF8), size: 32)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              d.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.devices_rounded,
                                color: Color(0xFF818CF8),
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #${d.id} • Danh mục: ${d.category}',
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.price.toStringAsFixed(0)} VNĐ',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 24),
              if (d.description != null && d.description!.isNotEmpty) ...[
                const Text(
                  'Mô tả sản phẩm:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  d.description!,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              _buildDetailInfoRow('Thương hiệu', d.brand ?? 'Chưa cập nhật'),
              _buildDetailInfoRow('Mã Model', d.modelNumber ?? 'Chưa cập nhật'),
              _buildDetailInfoRow('Độ tuổi phù hợp', '${d.minAge} - ${d.maxAge} tuổi'),
              _buildDetailInfoRow('Số lượng tồn kho', '${d.stockQuantity} sản phẩm'),
              _buildDetailInfoRow(
                'Trạng thái kinh doanh',
                d.isAvailable ? 'Đang mở bán' : 'Tạm ngừng kinh doanh',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Xóa thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteDevice(d.id, d.name);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editDevice(d);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(Map<String, dynamic> userItem) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.manage_accounts_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 10),
              Text('Phân quyền tài khoản'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản: ${userItem['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Email: ${userItem['email']}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn vai trò mới cho tài khoản:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _buildRoleOptionTile('ADMIN', 'Quản trị viên toàn quyền', const Color(0xFFDC2626), () {
                setState(() => userItem['role'] = 'ADMIN');
                Navigator.pop(ctx);
                _notifyRoleChanged(userItem['name'], 'ADMIN');
              }),
              _buildRoleOptionTile('STAFF', 'Nhân viên vận hành & Kỹ thuật', const Color(0xFF059669), () {
                setState(() => userItem['role'] = 'STAFF');
                Navigator.pop(ctx);
                _notifyRoleChanged(userItem['name'], 'STAFF');
              }),
              _buildRoleOptionTile('USER', 'Khách hàng / Phụ huynh', const Color(0xFF2563EB), () {
                setState(() => userItem['role'] = 'USER');
                Navigator.pop(ctx);
                _notifyRoleChanged(userItem['name'], 'USER');
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleOptionTile(String role, String desc, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              role,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          title: Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ),
      ),
    );
  }

  void _notifyRoleChanged(String name, String newRole) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        content: Text('Đã cập nhật vai trò của "$name" thành $newRole'),
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'STAFF';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm tài khoản hệ thống'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Địa chỉ Email'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Vai trò cấp phép'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN - Quản trị viên')),
                    DropdownMenuItem(value: 'STAFF', child: Text('STAFF - Nhân viên vận hành')),
                    DropdownMenuItem(value: 'USER', child: Text('USER - Khách hàng')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
                setState(() {
                  _managedUsers.add({
                    'id': _managedUsers.length + 1,
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'role': selectedRole,
                    'isActive': true,
                    'createdAt': '2026-10-29',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã thêm tài khoản mới thành công')),
                );
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildAdminAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOverviewTab(),
          _buildDevicesTab(),
          _buildUsersTab(),
          _buildSystemTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAdminAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ADMIN PORTAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Trung tâm Quản trị Cấp cao',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
            color: const Color(0xFFDC2626).withAlpha(40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDC2626)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFFF87171)),
              SizedBox(width: 4),
              Text(
                'ROLE: ADMIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF87171),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFF87171)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF818CF8),
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Sản phẩm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Phân quyền',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            label: 'Hệ thống',
          ),
        ],
      ),
    );
  }

  // ================= TAB 0: TỔNG QUAN QUẢN TRỊ =================
  Widget _buildOverviewTab() {
    return ListenableBuilder(
      listenable: _deviceController,
      builder: (context, _) {
        final totalDevices = _deviceController.devices.length;
        final previewDevices = _deviceController.devices.take(5).toList();

        return RefreshIndicator(
          onRefresh: () => _deviceController.loadDevices(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Máy chủ Trung tâm: TRỰC TUYẾN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Độ trễ: 24ms | Phiên bản API: v2.0-RoleBased',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '99.98% SLA',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _currentIndex = 1),
                      child: _buildMetricCard(
                        title: 'Tổng sản phẩm',
                        value: '$totalDevices',
                        change: 'Chạm để quản lý & sửa',
                        icon: Icons.devices_other_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Người dùng',
                      value: '${_managedUsers.length * 280}',
                      change: '3 vai trò hoạt động',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Bảo mật & Phân quyền',
                      value: '100%',
                      change: '3 Role tách biệt',
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Yêu cầu chờ xử lý',
                      value: '12',
                      change: 'Đã phân phối Staff',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'TÁC VỤ NHANH DÀNH CHO ADMIN',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Thêm sản phẩm',
                      color: const Color(0xFF4F46E5),
                      onTap: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceFormScreen(deviceController: _deviceController),
                          ),
                        );
                        if (created == true) _deviceController.loadDevices();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.edit_note_rounded,
                      label: 'Sửa sản phẩm',
                      color: const Color(0xFFF59E0B),
                      onTap: _showSelectDeviceToEditSheet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Tạo tài khoản',
                      color: const Color(0xFF059669),
                      onTap: _showAddUserDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.sync_rounded,
                      label: 'Đồng bộ data',
                      color: const Color(0xFF0284C7),
                      onTap: () {
                        _deviceController.loadDevices();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đang đồng bộ dữ liệu hệ thống từ Server...')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Danh sách sản phẩm quản lý và sửa nhanh ngay tại màn hình Tổng quan Admin
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_rounded, color: Color(0xFF818CF8), size: 19),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'QUẢN LÝ & SỬA SẢN PHẨM NHANH',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF818CF8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: Text(
                            'Kho ($totalDevices)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => setState(() => _currentIndex = 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_deviceController.isLoading && previewDevices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF818CF8)),
                        ),
                      )
                    else if (previewDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Chưa tải được danh sách sản phẩm từ Server.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _deviceController.loadDevices(),
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF818CF8)),
                              label: const Text('Tải lại', style: TextStyle(color: Color(0xFF818CF8))),
                            ),
                          ],
                        ),
                      )
                    else
                      ...previewDevices.map((d) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.devices_rounded,
                                  color: Color(0xFF818CF8),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${d.price.toStringAsFixed(0)} đ • Kho: ${d.stockQuantity} • ${d.category}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_rounded, size: 14),
                                label: const Text(
                                  'Sửa',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _editDevice(d),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Xóa sản phẩm',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                onPressed: () => _deleteDevice(d.id, d.name),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(
                          child: Text(
                            'Nhật ký kiểm toán hệ thống (Audit Logs)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.security_rounded, color: Color(0xFF818CF8), size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAuditItem('ADMIN khởi động phiên làm việc bảo mật', 'Vừa xong', const Color(0xFF10B981)),
                    _buildAuditItem('Kiểm tra tải hệ thống & API Health', '10 phút trước', const Color(0xFF3B82F6)),
                    _buildAuditItem('Cấu hình 3 phân quyền: ADMIN, STAFF, USER', '35 phút trước', const Color(0xFFF59E0B)),
                    _buildAuditItem('Đồng bộ cơ sở dữ liệu thiết bị trẻ em', '1 giờ trước', const Color(0xFF818CF8)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditItem(String text, String time, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: KHO & QUẢN LÝ SẢN PHẨM / THIẾT BỊ =================
  Widget _buildDevicesTab() {
    return ListenableBuilder(
      listenable: _deviceController,
      builder: (context, _) {
        final devices = _deviceController.devices.where((d) {
          if (_selectedCategory != 'Tất cả' && d.category != _selectedCategory) {
            return false;
          }
          final query = _deviceSearchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            return d.name.toLowerCase().contains(query) ||
                (d.brand?.toLowerCase().contains(query) ?? false) ||
                (d.category.toLowerCase().contains(query));
          }
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deviceSearchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm sản phẩm...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 20),
                            suffixIcon: _deviceSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white70, size: 16),
                                    onPressed: () {
                                      _deviceSearchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF334155)),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeviceFormScreen(deviceController: _deviceController),
                            ),
                          );
                          if (created == true) _deviceController.loadDevices();
                        },
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 17),
                        label: const Text('Sửa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        onPressed: _showSelectDeviceToEditSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'Tất cả',
                        ...Device.defaultCategories,
                      ].map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSel ? const Color(0xFF6366F1) : const Color(0xFF334155),
                              ),
                            ),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            if (_deviceController.errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _deviceController.errorMessage!,
                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF87171), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deviceController.loadDevices(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _deviceController.isLoading && _deviceController.devices.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
                  : devices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF64748B)),
                              const SizedBox(height: 12),
                              const Text(
                                'Không tìm thấy sản phẩm nào',
                                style: TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _deviceController.loadDevices(),
                                child: const Text('Làm mới danh sách', style: TextStyle(color: Color(0xFF818CF8))),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _deviceController.loadDevices(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final d = devices[index];
                              return _buildAdminDeviceCard(d);
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminDeviceCard(Device d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDeviceDetailDialog(d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: d.imageUrl == null || d.imageUrl!.isEmpty
                        ? const Icon(Icons.devices_rounded, color: Color(0xFF818CF8), size: 24)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              d.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.devices_rounded,
                                color: Color(0xFF818CF8),
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hãng: ${d.brand ?? "N/A"} | Model: ${d.modelNumber ?? "N/A"}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                d.category,
                                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Độ tuổi: ${d.minAge}-${d.maxAge} tuổi',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Chỉnh sửa sản phẩm',
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF818CF8), size: 21),
                        onPressed: () => _editDevice(d),
                      ),
                      IconButton(
                        tooltip: 'Xóa sản phẩm',
                        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 21),
                        onPressed: () => _deleteDevice(d.id, d.name),
                      ),
                    ],
                  ),
                ],
              ),
              if (d.description != null && d.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  d.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
              const Divider(color: Color(0xFF334155), height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${d.price.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      if (!d.isAvailable)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Ngừng bán',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: d.inStock
                              ? const Color(0xFF10B981).withAlpha(30)
                              : const Color(0xFFEF4444).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.inStock ? 'Còn tồn kho (${d.stockQuantity})' : 'Hết hàng',
                          style: TextStyle(
                            color: d.inStock ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: const Text(
                        'Chỉnh sửa sản phẩm',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _editDevice(d),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text(
                      'Xóa',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _deleteDevice(d.id, d.name),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB 2: QUẢN LÝ PHÂN QUYỀN (ADMIN, STAFF, USER) =================
  Widget _buildUsersTab() {
    final filteredUsers = _managedUsers.where((u) {
      if (_userRoleFilter != 'ALL' && u['role'] != _userRoleFilter) {
        return false;
      }
      final q = _userSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return u['name'].toString().toLowerCase().contains(q) ||
            u['email'].toString().toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              TextField(
                controller: _userSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm tài khoản theo tên hoặc email...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['ALL', 'ADMIN', 'STAFF', 'USER'].map((r) {
                  final isSel = _userRoleFilter == r;
                  return ChoiceChip(
                    label: Text(
                      r,
                      style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: r == 'ADMIN'
                        ? const Color(0xFFDC2626)
                        : (r == 'STAFF'
                            ? const Color(0xFF059669)
                            : (r == 'USER' ? const Color(0xFF2563EB) : const Color(0xFF4F46E5))),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (_) => setState(() => _userRoleFilter = r),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final role = user['role'] as String;
              final color = role == 'ADMIN'
                  ? const Color(0xFFEF4444)
                  : (role == 'STAFF' ? const Color(0xFF10B981) : const Color(0xFF3B82F6));

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withAlpha(40),
                      child: Text(
                        (user['name'] as String).substring(0, 1).toUpperCase(),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user['email'],
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(40),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color.withAlpha(100)),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user['isActive'] ? '• Đang hoạt động' : '• Đã khóa',
                                style: TextStyle(
                                  color: user['isActive'] ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đổi vai trò',
                      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF818CF8)),
                      onPressed: () => _showChangeRoleDialog(user),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= TAB 3: HỆ THỐNG & CẤU HÌNH ADMIN =================
  Widget _buildSystemTab() {
    final user = widget.authController.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4338CA)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, size: 36, color: Color(0xFFFCA5A5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Quản Trị Viên Root',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'admin@childdevices.vn',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'QUYỀN HẠN: TOÀN BỘ HỆ THỐNG',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'THIẾT LẬP MÁY CHỦ & BẢO MẬT',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        _buildSettingTile(
          icon: Icons.alt_route_rounded,
          title: 'Đường dẫn API Gateway',
          subtitle: 'http://localhost:5057 / http://10.0.2.2:5057',
        ),
        _buildSettingTile(
          icon: Icons.phone_disabled_rounded,
          title: 'Chính sách Gọi điện (Call Access Control)',
          subtitle: 'Chỉ dành cho USER & STAFF • Tài khoản ADMIN không có chức năng gọi điện',
        ),
        SwitchListTile(
          value: _maintenanceMode,
          activeThumbColor: const Color(0xFFEF4444),
          tileColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Chế độ Bảo trì (Maintenance Mode)', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('Chỉ Admin mới có thể truy cập hệ thống', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          onChanged: (val) {
            setState(() => _maintenanceMode = val);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val ? 'Đã BẬT chế độ bảo trì toàn hệ thống' : 'Đã TẮT chế độ bảo trì'),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Đăng xuất khỏi Bàn Quản Trị', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF818CF8)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
        ),
      ),
    );
  }
}
