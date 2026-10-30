import 'package:flutter/material.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/appearance_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nguyen Quang Hung
  // Đọc cấu hình môi trường từ file .env
  await AppConstants.init();
  // Khởi tạo cài đặt Cỡ chữ & Màu nền từ SharedPreferences
  await AppearanceController.instance.init();
  runApp(const NguyenQuangHungApp());
}
