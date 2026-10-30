import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyen_quang_hung/core/theme/appearance_controller.dart';
import 'package:nguyen_quang_hung/core/widgets/appearance_settings_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppearanceController.instance.init();
    await AppearanceController.instance.resetToDefaults();
  });

  group('AppearanceController Tests', () {
    test('Default values should be scale 1.0 and default_light', () {
      final appearance = AppearanceController.instance;
      expect(appearance.fontSizeScale, 1.0);
      expect(appearance.currentBgThemeId, 'default_light');
      expect(appearance.isCustomBg, false);
      expect(appearance.currentPreset.isDark, false);
    });

    test('Font size scale can be updated and clamped', () async {
      final appearance = AppearanceController.instance;

      await appearance.setFontSizeScale(1.15);
      expect(appearance.fontSizeScale, 1.15);

      // Clamp test: value below 0.8 should be clamped to 0.8
      await appearance.setFontSizeScale(0.5);
      expect(appearance.fontSizeScale, 0.8);

      // Clamp test: value above 1.45 should be clamped to 1.45
      await appearance.setFontSizeScale(2.0);
      expect(appearance.fontSizeScale, 1.45);
    });

    test('Background preset can be updated', () async {
      final appearance = AppearanceController.instance;

      await appearance.setBackgroundPreset('warm_sepia');
      expect(appearance.currentBgThemeId, 'warm_sepia');
      expect(appearance.currentPreset.name, 'Vàng Ấm Bảo Vệ Mắt');
      expect(appearance.isCustomBg, false);

      await appearance.setBackgroundPreset('dark_slate');
      expect(appearance.currentBgThemeId, 'dark_slate');
      expect(appearance.currentPreset.isDark, true);
    });

    test('Custom background color can be set and calculates theme properly', () async {
      final appearance = AppearanceController.instance;

      // Chọn màu nền sáng pastel (#E0F2FE)
      const lightBg = Color(0xFFE0F2FE);
      await appearance.setCustomBackgroundColor(lightBg);

      expect(appearance.isCustomBg, true);
      expect(appearance.currentBgThemeId, 'custom');
      expect(appearance.currentPreset.backgroundColor, lightBg);
      expect(appearance.currentPreset.isDark, false);
      expect(appearance.currentPreset.textColor, const Color(0xFF0F172A));

      // Chọn màu nền tối (#1E1E2E)
      const darkBg = Color(0xFF1E1E2E);
      await appearance.setCustomBackgroundColor(darkBg);

      expect(appearance.isCustomBg, true);
      expect(appearance.currentPreset.backgroundColor, darkBg);
      expect(appearance.currentPreset.isDark, true);
      expect(appearance.currentPreset.textColor, const Color(0xFFF8FAFC));
    });

    test('Hex color code can be parsed and applied', () async {
      final appearance = AppearanceController.instance;

      // Hex 6 ký tự có dấu #
      final success1 = await appearance.setCustomBackgroundColorHex('#FFF1F2');
      expect(success1, true);
      expect(appearance.isCustomBg, true);
      expect(appearance.currentPreset.backgroundColor, const Color(0xFFFFF1F2));

      // Hex không có dấu #
      final success2 = await appearance.setCustomBackgroundColorHex('0F172A');
      expect(success2, true);
      expect(appearance.currentPreset.backgroundColor, const Color(0xFF0F172A));
      expect(appearance.currentPreset.isDark, true);

      // Hex 3 ký tự viết tắt (#FFF)
      final success3 = await appearance.setCustomBackgroundColorHex('#FFF');
      expect(success3, true);
      expect(appearance.currentPreset.backgroundColor, const Color(0xFFFFFFFF));

      // Hex không hợp lệ
      final fail = await appearance.setCustomBackgroundColorHex('INVALID_HEX');
      expect(fail, false);
    });

    test('Quick palette colors list is populated and valid', () {
      expect(AppearanceController.quickPaletteColors.isNotEmpty, true);
      expect(AppearanceController.quickPaletteColors.length, greaterThanOrEqualTo(12));
    });

    test('Reset to defaults restores scale 1.0, default_light, and clears custom bg', () async {
      final appearance = AppearanceController.instance;

      await appearance.setFontSizeScale(1.30);
      await appearance.setCustomBackgroundColor(const Color(0xFF123456));

      expect(appearance.fontSizeScale, 1.30);
      expect(appearance.isCustomBg, true);

      await appearance.resetToDefaults();

      expect(appearance.fontSizeScale, 1.0);
      expect(appearance.isCustomBg, false);
      expect(appearance.currentBgThemeId, 'default_light');
    });

    test('ThemeData is generated properly for preset and custom color', () async {
      final appearance = AppearanceController.instance;
      final themeLight = appearance.buildThemeData();

      expect(themeLight.useMaterial3, true);
      expect(themeLight.scaffoldBackgroundColor, appearance.currentPreset.backgroundColor);

      await appearance.setCustomBackgroundColor(const Color(0xFFF0FDF4));
      final themeCustom = appearance.buildThemeData();
      expect(themeCustom.scaffoldBackgroundColor, const Color(0xFFF0FDF4));
    });

    testWidgets('AppearanceSettingsModal renders tabs and preview card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AppearanceSettingsModal.show(ctx),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Tùy Chỉnh Màu Nền & Cỡ Chữ'), findsOneWidget);
      expect(find.text('Chủ Đề Có Sẵn'), findsOneWidget);
      expect(find.text('Bảng Màu Nhanh'), findsOneWidget);
      expect(find.text('Mã Màu HEX'), findsOneWidget);

      // Chuyển sang Tab Bảng Màu Nhanh
      await tester.tap(find.text('Bảng Màu Nhanh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chạm vào bất kỳ màu nào'), findsOneWidget);

      // Chuyển sang Tab Mã Màu HEX
      await tester.tap(find.text('Mã Màu HEX'));
      await tester.pumpAndSettle();
      expect(find.text('Tự chọn mã màu nền HEX'), findsOneWidget);
      expect(find.text('Tạo màu ngẫu nhiên dịu mắt 🎲'), findsOneWidget);
    });
  });
}
