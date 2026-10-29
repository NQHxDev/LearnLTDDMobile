import 'package:flutter/material.dart';
import '../../../../core/navigation/role_router.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  final AuthController authController;

  const HomeScreen({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    // Điều phối tự động tới màn hình theo Role (ADMIN / STAFF / USER)
    return RoleRouter.getHomeScreenForRole(authController);
  }
}
