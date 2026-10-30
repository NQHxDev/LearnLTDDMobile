import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/appearance_controller.dart';

class AppearanceSettingsModal extends StatefulWidget {
  final int initialBackgroundTab;

  const AppearanceSettingsModal({
    super.key,
    this.initialBackgroundTab = 0,
  });

  /// Hàm tiện ích mở BottomSheet cài đặt hiển thị từ bất kỳ đâu trong app
  static Future<void> show(BuildContext context, {int initialBackgroundTab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppearanceSettingsModal(
        initialBackgroundTab: initialBackgroundTab,
      ),
    );
  }

  /// Tiện ích mở trực tiếp phần Chọn Màu Nền Tự Do
  static Future<void> showBackgroundColorPicker(BuildContext context) {
    return show(context, initialBackgroundTab: 1);
  }

  @override
  State<AppearanceSettingsModal> createState() => _AppearanceSettingsModalState();
}

class _AppearanceSettingsModalState extends State<AppearanceSettingsModal> {
  late int _selectedBgTab; // 0: Presets, 1: Bảng màu nhanh, 2: Tự nhập HEX
  late final TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _selectedBgTab = widget.initialBackgroundTab;
    final currentColor = AppearanceController.instance.currentPreset.backgroundColor;
    final hexString = currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    _hexController = TextEditingController(text: hexString);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHexColor(AppearanceController appearance) {
    final text = _hexController.text.trim();
    final parsed = AppearanceController.parseHexColor(text);
    if (parsed == null) {
      setState(() {
        _hexError = 'Mã màu không hợp lệ! Ví dụ: #E0F2FE hoặc F0FDF4';
      });
      return;
    }

    setState(() {
      _hexError = null;
    });

    appearance.setCustomBackgroundColor(parsed);
  }

  void _generateRandomColor(AppearanceController appearance) {
    final random = Random();
    // Tạo màu nền pastel hoặc dịu mắt ngẫu nhiên
    final r = 180 + random.nextInt(75);
    final g = 180 + random.nextInt(75);
    final b = 180 + random.nextInt(75);
    final color = Color.fromARGB(255, r, g, b);
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

    _hexController.text = hex;
    setState(() => _hexError = null);
    appearance.setCustomBackgroundColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceController.instance;

    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        final currentPreset = appearance.currentPreset;
        final isDark = currentPreset.isDark;
        final currentScale = appearance.fontSizeScale;

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: currentPreset.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 30),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: currentPreset.primaryColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.palette_rounded,
                        color: currentPreset.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tùy Chỉnh Màu Nền & Cỡ Chữ',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: currentPreset.textColor,
                            ),
                          ),
                          Text(
                            'Thay đổi màu nền Mobile & đồng bộ toàn ứng dụng',
                            style: TextStyle(
                              fontSize: 12,
                              color: currentPreset.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: currentPreset.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Mặc định', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        appearance.resetToDefaults();
                        final c = appearance.currentPreset.backgroundColor;
                        _hexController.text = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: currentPreset.textSecondaryColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Nội dung cuộn
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // ================= 1. HỘP XEM TRƯỚC TRỰC QUAN =================
                    _buildPreviewCard(appearance, currentPreset, currentScale),
                    const SizedBox(height: 24),

                    // ================= 2. ĐIỀU CHỈNH MÀU NỀN MOBILE =================
                    _buildBackgroundColorSection(context, appearance, currentPreset),
                    const SizedBox(height: 28),

                    // ================= 3. ĐIỀU CHỈNH CỠ CHỮ =================
                    _buildFontSizeSection(context, appearance, currentPreset, currentScale),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Khung Live Preview trực tiếp theo thời gian thực
  Widget _buildPreviewCard(
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
    double currentScale,
  ) {
    final hexCode = currentPreset.backgroundColor
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility_rounded, size: 18, color: currentPreset.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Xem Trước Màu Nền Đang Chọn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: currentPreset.textColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: currentPreset.backgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: currentPreset.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: currentPreset.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '#$hexCode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: currentPreset.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: currentPreset.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentPreset.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(currentPreset.isDark ? 50 : 15),
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
                      color: currentPreset.primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.smartphone_rounded, color: currentPreset.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Màu Nền: ${currentPreset.name}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: currentPreset.textColor,
                          ),
                        ),
                        Text(
                          currentPreset.isDark ? 'Chế độ tối (Dark Mode) • Tiết kiệm pin' : 'Chế độ sáng (Light Mode) • Dịu mắt',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: currentPreset.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentPreset.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentPreset.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.format_color_fill_rounded, size: 20, color: currentPreset.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Toàn bộ giao diện điện thoại (Scaffold, AppBar, Thẻ thẻ, Danh sách) sẽ lập tức chuyển sang tông màu này.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: currentPreset.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Phần Cấu hình Màu Nền Giao Diện Di Động
  Widget _buildBackgroundColorSection(
    BuildContext context,
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.color_lens_rounded, size: 20, color: currentPreset.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Tính Năng Đổi Màu Nền Mobile',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: currentPreset.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tabs phân loại kiểu chọn màu
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentPreset.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: currentPreset.borderColor),
          ),
          child: Row(
            children: [
              _buildTabButton(
                index: 0,
                label: 'Chủ Đề',
                icon: Icons.auto_awesome_rounded,
                currentPreset: currentPreset,
              ),
              _buildTabButton(
                index: 1,
                label: 'Bảng Màu',
                icon: Icons.palette_rounded,
                currentPreset: currentPreset,
              ),
              _buildTabButton(
                index: 2,
                label: 'Mã HEX',
                icon: Icons.colorize_rounded,
                currentPreset: currentPreset,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Nội dung của từng Tab
        if (_selectedBgTab == 0) ...[
          _buildPresetThemeList(appearance, currentPreset),
        ] else if (_selectedBgTab == 1) ...[
          _buildQuickColorPalette(appearance, currentPreset),
        ] else ...[
          _buildHexColorPicker(appearance, currentPreset),
        ],
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required AppBackgroundTheme currentPreset,
  }) {
    final isSelected = _selectedBgTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedBgTab = index),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? currentPreset.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: currentPreset.primaryColor.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : currentPreset.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : currentPreset.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 0: Danh sách chủ đề Preset có sẵn
  Widget _buildPresetThemeList(
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: AppearanceController.presets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final preset = AppearanceController.presets[index];
        final isSelected = !appearance.isCustomBg && preset.id == appearance.currentBgThemeId;

        return InkWell(
          onTap: () => appearance.setBackgroundPreset(preset.id),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? preset.backgroundColor
                  : (currentPreset.isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? preset.primaryColor : currentPreset.borderColor,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: preset.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: preset.borderColor, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: preset.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? preset.textColor : currentPreset.textColor,
                              ),
                            ),
                          ),
                          if (preset.isDark) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DARK',
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? preset.textSecondaryColor : currentPreset.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? preset.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? preset.primaryColor : currentPreset.borderColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tab 1: Bảng màu nhanh (Quick Palette - 18 sắc màu hot)
  Widget _buildQuickColorPalette(
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chạm vào bất kỳ màu nào để áp dụng màu nền ngay lập tức:',
          style: TextStyle(
            fontSize: 12,
            color: currentPreset.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: AppearanceController.quickPaletteColors.length,
          itemBuilder: (context, index) {
            final color = AppearanceController.quickPaletteColors[index];
            final isSelected = appearance.isCustomBg &&
                appearance.customBgColor.toARGB32() == color.toARGB32();

            final isColorDark = color.computeLuminance() < 0.45;

            return InkWell(
              onTap: () {
                appearance.setCustomBackgroundColor(color);
                final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                _hexController.text = hex;
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (isColorDark ? Colors.white : Colors.black)
                        : Colors.grey.withAlpha(90),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: isColorDark ? Colors.white : Colors.black,
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Tab 2: Nhập mã màu HEX tùy ý
  Widget _buildHexColorPicker(
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentPreset.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentPreset.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appearance.currentPreset.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: currentPreset.borderColor, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tự chọn mã màu nền HEX',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: currentPreset.textColor,
                      ),
                    ),
                    Text(
                      'Hỗ trợ mã HEX 6 ký tự (VD: FFF1F2, E0F2FE, 1E293B)',
                      style: TextStyle(
                        fontSize: 11,
                        color: currentPreset.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hexController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    prefixText: '# ',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: currentPreset.primaryColor,
                    ),
                    hintText: 'Nhập mã HEX (VD: E0F7FA)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _applyHexColor(appearance),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentPreset.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _applyHexColor(appearance),
              ),
            ],
          ),
          if (_hexError != null) ...[
            const SizedBox(height: 8),
            Text(
              _hexError!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444)),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: currentPreset.textColor,
              side: BorderSide(color: currentPreset.borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Tạo màu ngẫu nhiên dịu mắt 🎲'),
            onPressed: () => _generateRandomColor(appearance),
          ),
        ],
      ),
    );
  }

  /// Phần cấu hình Cỡ Chữ (Khóa cố định theo ứng dụng, độc lập hệ điều hành)
  Widget _buildFontSizeSection(
    BuildContext context,
    AppearanceController appearance,
    AppBackgroundTheme currentPreset,
    double currentScale,
  ) {
    final presetsMap = [
      {'label': 'Nhỏ', 'scale': 0.85, 'percent': '85%'},
      {'label': 'Tiêu chuẩn', 'scale': 1.00, 'percent': '100%'},
      {'label': 'Lớn', 'scale': 1.15, 'percent': '115%'},
      {'label': 'Rất lớn', 'scale': 1.30, 'percent': '130%'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_size_rounded, size: 20, color: currentPreset.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Cỡ Chữ Ứng Dụng',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: currentPreset.textColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: currentPreset.primaryColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(currentScale * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: currentPreset.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Huy hiệu thông báo độc lập với hệ thống
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: currentPreset.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: currentPreset.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cỡ chữ được khóa cố định theo ứng dụng, hoàn toàn KHÔNG bị thay đổi bởi cấu hình chữ to/nhỏ của hệ thống máy.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: currentPreset.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Hàng nút chọn nhanh preset tỉ lệ chữ
        Row(
          children: presetsMap.map((item) {
            final targetScale = item['scale'] as double;
            final isSelected = (currentScale - targetScale).abs() < 0.04;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => appearance.setFontSizeScale(targetScale),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? currentPreset.primaryColor : currentPreset.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? currentPreset.primaryColor : currentPreset.borderColor,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: currentPreset.primaryColor.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : currentPreset.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['percent'] as String,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isSelected ? Colors.white.withAlpha(200) : currentPreset.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Thanh trượt Slider tinh chỉnh
        Row(
          children: [
            Text(
              'A',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: currentPreset.textSecondaryColor,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: currentPreset.primaryColor,
                  inactiveTrackColor: currentPreset.borderColor,
                  thumbColor: currentPreset.primaryColor,
                  overlayColor: currentPreset.primaryColor.withAlpha(30),
                  valueIndicatorColor: currentPreset.primaryColor,
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                child: Slider(
                  value: currentScale,
                  min: 0.80,
                  max: 1.45,
                  divisions: 13,
                  label: '${(currentScale * 100).round()}%',
                  onChanged: (val) => appearance.setFontSizeScale(val),
                ),
              ),
            ),
            Text(
              'A',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: currentPreset.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
