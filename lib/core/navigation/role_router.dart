import 'package:flutter/material.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/staff/presentation/screens/staff_dashboard_screen.dart';
import '../../features/user/presentation/screens/user_home_screen.dart';

class RoleRouter {
  /// Xác định màn hình tương ứng dựa trên vai trò của người dùng
  static Widget getHomeScreenForRole(AuthController authController) {
    final roleType = authController.currentUser?.roleType ?? UserRoleType.user;

    switch (roleType) {
      case UserRoleType.admin:
        return AdminDashboardScreen(authController: authController);
      case UserRoleType.staff:
        return StaffDashboardScreen(authController: authController);
      case UserRoleType.user:
        return UserHomeScreen(authController: authController);
    }
  }

  /// Điều hướng tới màn hình chính riêng biệt tùy theo vai trò
  static void navigateToRoleHome(BuildContext context, AuthController authController) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => getHomeScreenForRole(authController),
      ),
      (route) => false,
    );
  }

  /// Xử lý đăng xuất chung và trở về màn hình đăng nhập
  static Future<void> logout(BuildContext context, AuthController authController) async {
    await authController.logout();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(authController: authController),
      ),
      (route) => false,
    );
  }
}
