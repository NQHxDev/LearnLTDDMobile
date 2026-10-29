import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/role_router.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final AuthController authController;

  const SplashScreen({
    super.key,
    required this.authController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Cho phép hiển thị splash tối thiểu 800ms để trải nghiệm mượt mà
    final results = await Future.wait([
      widget.authController.checkInitialSession(),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    final isLoggedIn = results[0] as bool;

    if (!mounted) return;

    if (isLoggedIn) {
      // Điều hướng tới đúng khu vực màn hình của Role (ADMIN / STAFF / USER)
      RoleRouter.navigateToRoleHome(context, widget.authController);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(authController: widget.authController),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.child_care_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
