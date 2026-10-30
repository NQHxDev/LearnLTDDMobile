import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/appearance_controller.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

class NguyenQuangHungApp extends StatefulWidget {
  const NguyenQuangHungApp({super.key});

  @override
  State<NguyenQuangHungApp> createState() => _NguyenQuangHungAppState();
}

class _NguyenQuangHungAppState extends State<NguyenQuangHungApp> {
  final _authController = AuthController();

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceController.instance;

    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: appearance.buildThemeData(),
          // ĐẶC BIỆT THEO YÊU CẦU:
          // Cỡ chữ của Mobile bắt buộc phải theo cấu hình ứng dụng,
          // hoàn toàn độc lập và không phụ thuộc vào cấu hình hệ thống người dùng!
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(appearance.fontSizeScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: SplashScreen(authController: _authController),
        );
      },
    );
  }
}
