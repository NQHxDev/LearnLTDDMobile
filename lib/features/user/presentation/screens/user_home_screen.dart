import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../device/data/models/device_model.dart';
import '../../../device/presentation/controllers/device_controller.dart';
import '../../../location/presentation/screens/location_share_screen.dart';
import '../../../translator/presentation/screens/smart_translator_screen.dart';
import '../../../video_call/presentation/screens/video_call_screen.dart';
import '../../../video_call/presentation/widgets/call_hub_widget.dart';

class UserHomeScreen extends StatefulWidget {
  final AuthController authController;

  const UserHomeScreen({
    super.key,
    required this.authController,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  final DeviceController _deviceController = DeviceController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Tất cả';
  int _selectedAgeFilter = 0; // 0: Tất cả, 1: 3-5 tuổi, 2: 6-10 tuổi, 3: 11+ tuổi
  final Set<int> _favoriteDeviceIds = {};

  @override
  void initState() {
    super.initState();
    _deviceController.loadDevices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Đăng xuất tài khoản',
      content: 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng Child Devices?',
      confirmText: 'Đăng xuất',
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

  void _showDeviceDetailSheet(Device device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.devices_rounded, color: Color(0xFF2563EB), size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thương hiệu: ${device.brand ?? "Chính hãng"} | Danh mục: ${device.category}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${device.averageRating > 0 ? device.averageRating : 4.8} (${device.reviewCount > 0 ? device.reviewCount : 24} đánh giá từ phụ huynh)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              const Text(
                'Chứng nhận An toàn cho trẻ em:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSafetyBadge('Bức xạ an toàn CE', Icons.health_and_safety_outlined),
                  _buildSafetyBadge('Phù hợp lứa tuổi ${device.minAge}-${device.maxAge} tuổi', Icons.child_care_rounded),
                  _buildSafetyBadge('Chống nước IP67', Icons.water_drop_outlined),
                  _buildSafetyBadge('Định vị SOS tức thì', Icons.location_on_outlined),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Mô tả sản phẩm:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    device.description ??
                        'Thiết bị thông minh chuyên dụng bảo vệ và đồng hành cùng bé yêu. Giúp phụ huynh an tâm theo dõi vị trí, liên lạc hai chiều và nhận cảnh báo khẩn cấp khi con ra khỏi vùng an toàn.',
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giá ưu đãi phụ huynh', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                      Text(
                        '${device.price.toStringAsFixed(0)} đ',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Tư vấn & Đặt mua', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF2563EB),
                          content: Text('Đã gửi yêu cầu tư vấn sản phẩm "${device.name}"'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSafetyBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildUserAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildExploreCatalogTab(),
          _buildKidsDevicesTab(),
          LocationShareScreen(
            authController: widget.authController,
            isEmbeddedInTab: true,
          ),
          CallHubWidget(authController: widget.authController),
          SmartTranslatorScreen(
            isEmbeddedInTab: true,
            isActiveTab: _currentIndex == 4,
          ),
          _buildParentProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildUserBottomNav(),
    );
  }

  PreferredSizeWidget _buildUserAppBar() {
    final user = widget.authController.currentUser;
    final name = user?.fullName.split(' ').last ?? 'Phụ Huynh';

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0.5,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.family_restroom_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào ba mẹ $name! 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Đồng hành an toàn cùng bé yêu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text(
                'ROLE: USER',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Chia sẻ vị trí GPS chuẩn xác',
          icon: const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB)),
          onPressed: () => setState(() => _currentIndex = 2),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildUserBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care_rounded),
            label: 'Bé & Thiết bị',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_location_rounded),
            label: 'Vị trí GPS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_in_talk_rounded),
            label: 'Gọi điện',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_enhance_rounded),
            label: 'Dịch AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_rounded),
            label: 'Gia đình',
          ),
        ],
      ),
    );
  }

  // ================= TAB 0: KHÁM PHÁ THIẾT BỊ AN TOÀN CHO BÉ =================
  Widget _buildExploreCatalogTab() {
    return ListenableBuilder(
      listenable: _deviceController,
      builder: (context, _) {
        final devices = _deviceController.devices.where((d) {
          if (_selectedCategory != 'Tất cả' && d.category != _selectedCategory) {
            return false;
          }
          if (_selectedAgeFilter == 1 && (d.minAge > 5 || d.maxAge < 3)) return false;
          if (_selectedAgeFilter == 2 && (d.minAge > 10 || d.maxAge < 6)) return false;
          if (_selectedAgeFilter == 3 && d.maxAge < 11) return false;

          final q = _searchController.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            return d.name.toLowerCase().contains(q) ||
                (d.brand?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () => _deviceController.loadDevices(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Friendly Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withAlpha(40),
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
                        children: const [
                          Text(
                            'An Tâm Từng Bước Chân Của Bé',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Đồng hồ định vị GPS, camera giấc ngủ và thiết bị học tập chuẩn quốc tế.',
                            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Trợ Lý Dịch Thuật AI (Camera OCR & Hội Thoại Realtime EN -> VI)
              _buildAiTranslatorQuickCard(),
              const SizedBox(height: 12),

              // Trạm Chia Sẻ Vị Trí GPS Chuẩn Xác (Chức năng độc quyền của User)
              _buildLocationShareQuickCard(),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm thiết bị cho bé (đồng hồ, camera, máy tính...)',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Age Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAgeChip('Mọi lứa tuổi', 0),
                    _buildAgeChip('Mầm non (3-5 tuổi)', 1),
                    _buildAgeChip('Tiểu học (6-10 tuổi)', 2),
                    _buildAgeChip('Thiếu niên (11+ tuổi)', 3),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Tất cả',
                    ...Device.defaultCategories,
                  ].map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Product Grid / List
              if (_deviceController.isLoading && _deviceController.devices.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  ),
                )
              else if (devices.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.devices_other_rounded, size: 50, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có thiết bị nào phù hợp với bộ lọc',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = 'Tất cả';
                              _selectedAgeFilter = 0;
                              _searchController.clear();
                            });
                          },
                          child: const Text('Đặt lại bộ lọc'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...devices.map((device) => _buildParentDeviceCard(device)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgeChip(String label, int index) {
    final isSel = _selectedAgeFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSel ? const Color(0xFF2563EB) : AppColors.textSecondary,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            fontSize: 11.5,
          ),
        ),
        selected: isSel,
        onSelected: (_) => setState(() => _selectedAgeFilter = index),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFEFF6FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildParentDeviceCard(Device device) {
    final isFav = _favoriteDeviceIds.contains(device.id);

    return InkWell(
      onTap: () => _showDeviceDetailSheet(device),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.devices_rounded, color: Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Độ tuổi: ${device.minAge}-${device.maxAge} tuổi • ${device.category}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${device.price.toStringAsFixed(0)} đ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'An toàn cho bé',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? Colors.red : Colors.grey,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  if (isFav) {
                    _favoriteDeviceIds.remove(device.id);
                  } else {
                    _favoriteDeviceIds.add(device.id);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: BÉ & THIẾT BỊ ĐANG GIÁM SÁT =================
  Widget _buildKidsDevicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kid 1
        _buildKidMonitoringCard(
          kidName: 'Bé Minh An',
          kidAge: '7 tuổi - Lớp 2A',
          deviceName: 'Đồng Hồ Định Vị Trẻ Em K2 Pro',
          location: 'Trường Tiểu học Chu Văn An (Vùng an toàn)',
          battery: '86%',
          isSafe: true,
          avatarColor: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 14),

        // Kid 2
        _buildKidMonitoringCard(
          kidName: 'Bé Bông Nhi',
          kidAge: '4 tuổi - Lớp Mầm',
          deviceName: 'Camera Cảm Biến Giấc Ngủ SafeSleep',
          location: 'Phòng ngủ bé (Tầng 2 - Bình thường)',
          battery: 'Cắm nguồn 24/7',
          isSafe: true,
          avatarColor: const Color(0xFFEC4899),
        ),
        const SizedBox(height: 20),

        // Connect new device button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
          label: const Text(
            'Quét mã QR kết nối thêm thiết bị cho bé',
            style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng quét mã QR kết nối thiết bị đang sẵn sàng')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKidMonitoringCard({
    required String kidName,
    required String kidAge,
    required String deviceName,
    required String location,
    required String battery,
    required bool isSafe,
    required Color avatarColor,
  }) {
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
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor.withAlpha(30),
                child: Text(
                  kidName.substring(0, 1),
                  style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kidName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      kidAge,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'AN TOÀN',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.watch_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  deviceName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Pin: $battery',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                  label: const Text('Gọi Thoại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final slug = kidName.toLowerCase().replaceAll(' ', '-');
                    CallHubWidget.launchDirectCall(
                      context: context,
                      authController: widget.authController,
                      roomName: 'kid-$slug',
                      description: 'Gọi thoại 2 chiều tới $deviceName của $kidName',
                      callType: CallType.oneToOne,
                      isAudioOnly: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text('Gọi Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final slug = kidName.toLowerCase().replaceAll(' ', '-');
                    CallHubWidget.launchDirectCall(
                      context: context,
                      authController: widget.authController,
                      roomName: 'kid-$slug',
                      description: 'Video Call tới $deviceName của $kidName',
                      callType: CallType.oneToOne,
                      isAudioOnly: false,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB)),
                tooltip: 'Chia sẻ vị trí của Ba/Mẹ tới $kidName',
                onPressed: () {
                  LocationShareScreen.open(
                    context,
                    authController: widget.authController,
                    initialShareType: 'pickup',
                    initialRecipient: 'Gia đình & $kidName',
                    initialNote: 'Ba/Mẹ đang đến đón $kidName tại vị trí GPS này nhé!',
                  );
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF059669)),
                tooltip: 'Gọi Staff hỗ trợ thiết bị này',
                onPressed: () {
                  CallHubWidget.launchDirectCall(
                    context: context,
                    authController: widget.authController,
                    roomName: 'phong-ho-tro-ky-thuat',
                    description: 'Phụ huynh cần hỗ trợ thiết bị $deviceName ($kidName)',
                    callType: CallType.support,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TRỢ LÝ DỊCH CAMERA & HỘI THOẠI REALTIME (EN -> VI) =================
  Widget _buildAiTranslatorQuickCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(14),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Icons.translate_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dịch Camera & Hội Thoại Realtime (Anh → Việt)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Giơ camera vào chữ Tiếng Anh để dịch hoặc phát âm đoạn hội thoại',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 17),
                  label: const Text(
                    'Camera Dịch Chữ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => SmartTranslatorScreen.open(
                    context,
                    initialTabIndex: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669), width: 1.3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.record_voice_over_rounded, size: 17),
                  label: const Text(
                    'Dịch Hội Thoại',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => SmartTranslatorScreen.open(
                    context,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TRẠM CHIA SẺ VỊ TRÍ GPS CHUẨN XÁC (CHỨC NĂNG USER) =================
  Widget _buildLocationShareQuickCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withAlpha(14),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.share_location_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chia Sẻ Vị Trí GPS Chuẩn Xác & Hành Trình Live (User)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Định vị vệ tinh ±3m, bản đồ trực quan, tính khoảng cách tới Bé & gửi vị trí qua Zalo/Google Maps',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 17),
                  label: const Text(
                    'Chia Sẻ Vị Trí Của Tôi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => setState(() => _currentIndex = 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.sos_rounded, size: 17),
                  label: const Text(
                    'Phát Vị Trí SOS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => LocationShareScreen.open(
                    context,
                    authController: widget.authController,
                    initialShareType: 'sos',
                    initialRecipient: 'Đội Hỗ trợ Kỹ thuật & SOS',
                    initialNote: 'CẢNH BÁO SOS: Cần hỗ trợ khẩn cấp tại đúng tọa độ GPS này!',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: HỒ SƠ PHỤ HUYNH & CÀI ĐẶT GIA ĐÌNH =================
  Widget _buildParentProfileTab() {
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
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Phụ Huynh Minh Anh',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'phuhuynh@childdevices.vn',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VAI TRÒ: PHỤ HUYNH / KHÁCH HÀNG (USER)',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
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

        // Cài đặt cảnh báo SOS
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
                'Cài đặt an toàn & Cảnh báo khẩn cấp',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildParentSettingTile(Icons.notifications_active_outlined, 'Âm thanh cảnh báo SOS mức cao nhất'),
              _buildParentSettingTile(Icons.shield_outlined, 'Thông báo ngay khi con ra khỏi vùng an toàn'),
              InkWell(
                onTap: () => setState(() => _currentIndex = 2),
                child: _buildParentSettingTile(
                  Icons.share_location_rounded,
                  'Chia sẻ vị trí GPS chuẩn xác & Hành trình Live (Chức năng User)',
                ),
              ),
              InkWell(
                onTap: () {
                  CallHubWidget.launchDirectCall(
                    context: context,
                    authController: widget.authController,
                    roomName: 'phong-ho-tro-ky-thuat',
                    description: 'Kết nối trực tuyến Phụ huynh (USER) và Kỹ thuật viên (STAFF)',
                    callType: CallType.support,
                  );
                },
                child: _buildParentSettingTile(
                  Icons.headset_mic_outlined,
                  'Gọi trực tiếp Kỹ thuật viên trực tuyến (STAFF)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildParentSettingTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
