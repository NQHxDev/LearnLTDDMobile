import 'package:flutter/material.dart';
import 'appearance_controller.dart';

class AppTheme {
  /// Lấy ThemeData mặc định hoặc lấy theo AppearanceController hiện tại
  static ThemeData get lightTheme {
    return AppearanceController.instance.buildThemeData();
  }

  /// Sinh ThemeData dựa trên cấu hình AppearanceController
  static ThemeData fromAppearance(AppearanceController appearance) {
    return appearance.buildThemeData();
  }
}
