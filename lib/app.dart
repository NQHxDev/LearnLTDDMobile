import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

class ChildDevicesApp extends StatefulWidget {
  const ChildDevicesApp({super.key});

  @override
  State<ChildDevicesApp> createState() => _ChildDevicesAppState();
}

class _ChildDevicesAppState extends State<ChildDevicesApp> {
  final _authController = AuthController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(authController: _authController),
    );
  }
}
