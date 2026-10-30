import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preset cấu hình màu nền và giao diện cho ứng dụng di động
class AppBackgroundTheme {
  final String id;
  final String name;
  final String subtitle;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color appBarColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final Color primaryColor;
  final bool isDark;

  const AppBackgroundTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.appBarColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.primaryColor,
    this.isDark = false,
  });

  /// Sinh một AppBackgroundTheme hoàn chỉnh và cân đối dựa trên màu nền người dùng chọn tự do
  factory AppBackgroundTheme.fromCustomColor({
    required Color backgroundColor,
    String? name,
    Color? primaryColor,
  }) {
    final luminance = backgroundColor.computeLuminance();
    final isDark = luminance < 0.45;

    final primary = primaryColor ??
        (isDark ? const Color(0xFF3B82F6) : const Color(0xFF1769FF));

    if (isDark) {
      return AppBackgroundTheme(
        id: 'custom',
        name: name ?? 'Màu Tùy Chỉnh (Dark)',
        subtitle: 'Giao diện nền tối tự chọn, bảo vệ thị lực',
        backgroundColor: backgroundColor,
        surfaceColor: Color.alphaBlend(Colors.white.withAlpha(28), backgroundColor),
        appBarColor: Color.alphaBlend(Colors.white.withAlpha(20), backgroundColor),
        textColor: const Color(0xFFF8FAFC),
        textSecondaryColor: const Color(0xFF94A3B8),
        borderColor: Color.alphaBlend(Colors.white.withAlpha(45), backgroundColor),
        primaryColor: primary,
        isDark: true,
      );
    } else {
      return AppBackgroundTheme(
        id: 'custom',
        name: name ?? 'Màu Tùy Chỉnh (Light)',
        subtitle: 'Giao diện nền sáng tự chọn, dịu mắt và thanh lịch',
        backgroundColor: backgroundColor,
        surfaceColor: Colors.white,
        appBarColor: Color.alphaBlend(Colors.black.withAlpha(12), backgroundColor),
        textColor: const Color(0xFF0F172A),
        textSecondaryColor: const Color(0xFF64748B),
        borderColor: Color.alphaBlend(Colors.black.withAlpha(25), backgroundColor),
        primaryColor: primary,
        isDark: false,
      );
    }
  }
}

/// Controller quản lý Cỡ chữ và Màu nền của ứng dụng di động.
/// Đảm bảo cỡ chữ ứng dụng tuân thủ theo cấu hình trong app,
/// hoàn toàn độc lập và không phụ thuộc vào cấu hình hệ thống của thiết bị.
/// Hỗ trợ thay đổi màu nền theo Preset chuẩn hoặc chọn Màu tự do (Color Palette / HEX).
class AppearanceController extends ChangeNotifier {
  AppearanceController._internal();
  static final AppearanceController instance = AppearanceController._internal();

  static const String _prefFontSizeKey = 'app_custom_font_size_scale';
  static const String _prefBgThemeKey = 'app_custom_background_theme_id';
  static const String _prefIsCustomBgKey = 'app_custom_background_is_custom';
  static const String _prefCustomBgColorValKey = 'app_custom_background_color_value';

  // Cỡ chữ mặc định: 1.0 (100% kích thước tiêu chuẩn ứng dụng)
  double _fontSizeScale = 1.0;
  String _currentBgThemeId = 'default_light';
  bool _isCustomBg = false;
  Color _customBgColor = const Color(0xFFF8FAFC);
  bool _isInitialized = false;

  double get fontSizeScale => _fontSizeScale;
  String get currentBgThemeId => _currentBgThemeId;
  bool get isCustomBg => _isCustomBg;
  Color get customBgColor => _customBgColor;
  bool get isInitialized => _isInitialized;

  /// Danh sách 18 màu sắc thịnh hành dành cho tính năng chọn màu nền nhanh (Quick Palette)
  static const List<Color> quickPaletteColors = [
    Color(0xFFFFFFFF), // Trắng tinh khôi
    Color(0xFFF8FAFC), // Xám tuyết thanh lịch
    Color(0xFFFAF6EE), // Giấy sepia dịu mắt
    Color(0xFFFEFCE8), // Vàng nắng nhẹ
    Color(0xFFF0FDF4), // Xanh bạc hà dịu mát
    Color(0xFFECFDF5), // Xanh ngọc bích tươi
    Color(0xFFF0F7FF), // Xanh dương bình minh
    Color(0xFFE0F2FE), // Xanh băng tuyết
    Color(0xFFFAF5FF), // Tím oải hương mơ màng
    Color(0xFFFFF1F2), // Hồng cánh đào pastel
    Color(0xFFFFF7ED), // Cam đào ấm áp
    Color(0xFFF1F5F9), // Xám bạc tối giản
    Color(0xFFE2E8F0), // Xám khói trung tính
    Color(0xFF334155), // Xám đá đậm
    Color(0xFF1E293B), // Xanh than đêm
    Color(0xFF0F172A), // Tối xanh công nghệ
    Color(0xFF181825), // Tím than huyền bí
    Color(0xFF000000), // Đen tuyền AMOLED
  ];

  /// Danh sách các preset màu nền được tối ưu cho trải nghiệm người dùng
  static const List<AppBackgroundTheme> presets = [
    AppBackgroundTheme(
      id: 'default_light',
      name: 'Trắng Sáng Hiện Đại',
      subtitle: 'Giao diện sáng tiêu chuẩn, sắc nét ban ngày',
      backgroundColor: Color(0xFFF8FAFC),
      surfaceColor: Colors.white,
      appBarColor: Colors.white,
      textColor: Color(0xFF0F172A),
      textSecondaryColor: Color(0xFF64748B),
      borderColor: Color(0xFFE2E8F0),
      primaryColor: Color(0xFF1769FF),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'warm_sepia',
      name: 'Vàng Ấm Bảo Vệ Mắt',
      subtitle: 'Tông màu giấy ấm giúp đọc lâu không mỏi mắt',
      backgroundColor: Color(0xFFFAF6EE),
      surfaceColor: Color(0xFFFFFDF8),
      appBarColor: Color(0xFFF5EEDB),
      textColor: Color(0xFF292524),
      textSecondaryColor: Color(0xFF78716C),
      borderColor: Color(0xFFE7DFD5),
      primaryColor: Color(0xFFD97706),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'mint_soft',
      name: 'Xanh Bạc Hà Dịu Mát',
      subtitle: 'Gam xanh thiên nhiên mang lại cảm giác dễ chịu',
      backgroundColor: Color(0xFFF0FDF4),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFE2FBE9),
      textColor: Color(0xFF064E3B),
      textSecondaryColor: Color(0xFF047857),
      borderColor: Color(0xFFBBF7D0),
      primaryColor: Color(0xFF059669),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'sky_breeze',
      name: 'Xanh Dương Thanh Bình',
      subtitle: 'Gam màu dịu êm, thân thiện gia đình và trẻ em',
      backgroundColor: Color(0xFFF0F7FF),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFE0F2FE),
      textColor: Color(0xFF0C4A6E),
      textSecondaryColor: Color(0xFF0284C7),
      borderColor: Color(0xFFBAE6FD),
      primaryColor: Color(0xFF0284C7),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'rose_blush',
      name: 'Hồng Phấn Nhẹ Nhàng',
      subtitle: 'Tông màu pastel ngọt ngào, tạo cảm giác thư giãn',
      backgroundColor: Color(0xFFFFF1F2),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFFFE4E6),
      textColor: Color(0xFF881337),
      textSecondaryColor: Color(0xFF9F1239),
      borderColor: Color(0xFFFECDD3),
      primaryColor: Color(0xFFE11D48),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'peach_warm',
      name: 'Cam Đào Ấm Áp',
      subtitle: 'Sắc cam nhạt tràn đầy năng lượng và tích cực',
      backgroundColor: Color(0xFFFFF7ED),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFFFEDD5),
      textColor: Color(0xFF7C2D12),
      textSecondaryColor: Color(0xFF9A3412),
      borderColor: Color(0xFFFED7AA),
      primaryColor: Color(0xFFEA580C),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'emerald_nature',
      name: 'Xanh Ngọc Tươi Mới',
      subtitle: 'Sắc xanh ngọc trong trẻo, mang hơi thở thiên nhiên',
      backgroundColor: Color(0xFFECFDF5),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFD1FAE5),
      textColor: Color(0xFF064E3B),
      textSecondaryColor: Color(0xFF047857),
      borderColor: Color(0xFFA7F3D0),
      primaryColor: Color(0xFF0D9488),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'lavender_calm',
      name: 'Tím Oải Hương Thư Thái',
      subtitle: 'Sắc tím pastel tinh tế, nhẹ nhàng cho mắt',
      backgroundColor: Color(0xFFFAF5FF),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFF3E8FF),
      textColor: Color(0xFF581C87),
      textSecondaryColor: Color(0xFF7E22CE),
      borderColor: Color(0xFFE9D5FF),
      primaryColor: Color(0xFF9333EA),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'slate_minimal',
      name: 'Xám Bạc Tối Giản',
      subtitle: 'Phong cách tối giản hiện đại, rõ ràng mạch lạc',
      backgroundColor: Color(0xFFF1F5F9),
      surfaceColor: Colors.white,
      appBarColor: Color(0xFFE2E8F0),
      textColor: Color(0xFF0F172A),
      textSecondaryColor: Color(0xFF475569),
      borderColor: Color(0xFFCBD5E1),
      primaryColor: Color(0xFF475569),
      isDark: false,
    ),
    AppBackgroundTheme(
      id: 'dark_slate',
      name: 'Tối Xanh Công Nghệ',
      subtitle: 'Tối mờ hiện đại, bảo vệ mắt tối đa trong đêm',
      backgroundColor: Color(0xFF0F172A),
      surfaceColor: Color(0xFF1E293B),
      appBarColor: Color(0xFF1E293B),
      textColor: Color(0xFFF8FAFC),
      textSecondaryColor: Color(0xFF94A3B8),
      borderColor: Color(0xFF334155),
      primaryColor: Color(0xFF3B82F6),
      isDark: true,
    ),
    AppBackgroundTheme(
      id: 'cyber_night',
      name: 'Tím Đêm Neon Huyền Bí',
      subtitle: 'Gam tím than cyberpunk cá tính và cuốn hút',
      backgroundColor: Color(0xFF181825),
      surfaceColor: Color(0xFF1E1E2E),
      appBarColor: Color(0xFF1E1E2E),
      textColor: Color(0xFFCDD6F4),
      textSecondaryColor: Color(0xFFA6ADC8),
      borderColor: Color(0xFF313244),
      primaryColor: Color(0xFFCBA6F7),
      isDark: true,
    ),
    AppBackgroundTheme(
      id: 'pure_black',
      name: 'Đen Tuyền AMOLED',
      subtitle: 'Đen sâu tuyệt đối, siêu tiết kiệm pin màn hình OLED',
      backgroundColor: Color(0xFF000000),
      surfaceColor: Color(0xFF121212),
      appBarColor: Color(0xFF121212),
      textColor: Color(0xFFFFFFFF),
      textSecondaryColor: Color(0xFFA1A1AA),
      borderColor: Color(0xFF27272A),
      primaryColor: Color(0xFF60A5FA),
      isDark: true,
    ),
  ];

  AppBackgroundTheme get currentPreset {
    if (_isCustomBg) {
      final hex = _customBgColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
      return AppBackgroundTheme.fromCustomColor(
        backgroundColor: _customBgColor,
        name: 'Màu Nền Tự Chọn (#$hex)',
      );
    }

    return presets.firstWhere(
      (p) => p.id == _currentBgThemeId,
      orElse: () => presets.first,
    );
  }

  /// Khởi tạo và đọc cấu hình từ bộ nhớ cục bộ (SharedPreferences)
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScale = prefs.getDouble(_prefFontSizeKey);
      if (savedScale != null && savedScale >= 0.8 && savedScale <= 1.5) {
        _fontSizeScale = savedScale;
      }

      final isCustom = prefs.getBool(_prefIsCustomBgKey) ?? false;
      final savedCustomColorVal = prefs.getInt(_prefCustomBgColorValKey);
      if (isCustom && savedCustomColorVal != null) {
        _isCustomBg = true;
        _customBgColor = Color(savedCustomColorVal);
        _currentBgThemeId = 'custom';
      } else {
        final savedThemeId = prefs.getString(_prefBgThemeKey);
        if (savedThemeId != null && presets.any((p) => p.id == savedThemeId)) {
          _currentBgThemeId = savedThemeId;
          _isCustomBg = false;
        }
      }
    } catch (_) {
      // Dùng cấu hình mặc định nếu đọc gặp lỗi
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Cập nhật cỡ chữ ứng dụng (bỏ qua cỡ chữ hệ thống của điện thoại)
  Future<void> setFontSizeScale(double scale) async {
    final clamped = scale.clamp(0.8, 1.45);
    if ((_fontSizeScale - clamped).abs() < 0.01) return;

    _fontSizeScale = clamped;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefFontSizeKey, _fontSizeScale);
    } catch (_) {}
  }

  /// Cập nhật màu nền giao diện theo Preset có sẵn
  Future<void> setBackgroundPreset(String presetId) async {
    if (_currentBgThemeId == presetId && !_isCustomBg) return;
    if (!presets.any((p) => p.id == presetId)) return;

    _isCustomBg = false;
    _currentBgThemeId = presetId;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsCustomBgKey, false);
      await prefs.setString(_prefBgThemeKey, _currentBgThemeId);
    } catch (_) {}
  }

  /// Đặt màu nền tùy chọn tự do (từ bảng màu Color Palette hoặc Color Picker)
  Future<void> setCustomBackgroundColor(Color color, {String? name}) async {
    _isCustomBg = true;
    _customBgColor = color;
    _currentBgThemeId = 'custom';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsCustomBgKey, true);
      await prefs.setInt(_prefCustomBgColorValKey, color.toARGB32());
    } catch (_) {}
  }

  /// Đặt màu nền bằng chuỗi mã màu HEX (ví dụ: "#F0F8FF" hoặc "FFF1F2")
  Future<bool> setCustomBackgroundColorHex(String hexCode) async {
    final parsed = parseHexColor(hexCode);
    if (parsed == null) return false;
    await setCustomBackgroundColor(parsed);
    return true;
  }

  /// Hàm tiện ích chuyển mã chuỗi HEX thành Color an toàn
  static Color? parseHexColor(String hex) {
    var cleanHex = hex.trim().replaceAll('#', '');
    if (cleanHex.length == 3) {
      // Ví dụ: F00 -> FF0000
      cleanHex = cleanHex.split('').map((c) => '$c$c').join();
    }
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    if (cleanHex.length != 8) return null;
    final intVal = int.tryParse(cleanHex, radix: 16);
    if (intVal == null) return null;
    return Color(intVal);
  }

  /// Khôi phục toàn bộ về cấu hình ban đầu
  Future<void> resetToDefaults() async {
    _fontSizeScale = 1.0;
    _currentBgThemeId = 'default_light';
    _isCustomBg = false;
    _customBgColor = const Color(0xFFF8FAFC);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefFontSizeKey);
      await prefs.remove(_prefBgThemeKey);
      await prefs.remove(_prefIsCustomBgKey);
      await prefs.remove(_prefCustomBgColorValKey);
    } catch (_) {}
  }

  /// Tạo ThemeData tương thích đầy đủ với preset hiện tại
  ThemeData buildThemeData() {
    final preset = currentPreset;
    final isDark = preset.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: preset.primaryColor,
        onPrimary: Colors.white,
        secondary: preset.primaryColor,
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: preset.surfaceColor,
        onSurface: preset.textColor,
      ),
      scaffoldBackgroundColor: preset.backgroundColor,
      canvasColor: preset.surfaceColor,
      cardColor: preset.surfaceColor,
      dividerColor: preset.borderColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: preset.appBarColor,
        foregroundColor: preset.textColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: preset.textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: preset.textColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : preset.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: TextStyle(color: preset.textSecondaryColor),
        hintStyle: TextStyle(color: preset.textSecondaryColor.withAlpha(180)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: preset.borderColor, width: 0.8),
        ),
        color: preset.surfaceColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: preset.surfaceColor,
        selectedItemColor: preset.primaryColor,
        unselectedItemColor: preset.textSecondaryColor,
      ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: preset.textColor,
        displayColor: preset.textColor,
      ),
    );
  }
}
