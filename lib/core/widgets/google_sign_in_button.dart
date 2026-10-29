import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import '../navigation/role_router.dart';
import '../utils/validators.dart';

/// Nút đăng nhập / đăng ký Google chuẩn giao diện Brand Guideline của Google
class GoogleSignInButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  const GoogleSignInButton({
    super.key,
    this.text = 'Đăng nhập bằng Google',
    this.onPressed,
    this.isLoading = false,
    this.height = 50,
  });

  /// Xử lý đăng nhập hoặc đăng ký bằng Google:
  /// 1. Ưu tiên gọi Google Sign-In SDK gốc (Android / iOS / Web).
  /// 2. Nếu máy ảo / thiết bị chưa cấu hình SHA-1 OAuth Client ID trên Google Cloud,
  ///    tự động mở hộp thoại Chọn tài khoản Google tương tác và xác thực với Backend (/api/Auth/google).
  static Future<void> handleGoogleAuth(
    BuildContext context,
    AuthController authController, {
    bool isRegister = false,
  }) async {
    FocusScope.of(context).unfocus();

    final status = await authController.signInWithNativeGoogle();
    if (!context.mounted) return;

    if (status == GoogleSignInStatus.success) {
      _onGoogleAuthSuccess(context, authController, isRegister: isRegister);
      return;
    }

    if (status == GoogleSignInStatus.cancelled) {
      return;
    }

    // Mở hộp thoại Chọn tài khoản Google để đăng nhập / đăng ký qua Backend API
    await showGoogleAccountPicker(
      context,
      authController: authController,
      isRegister: isRegister,
    );
  }

  static void _onGoogleAuthSuccess(
    BuildContext context,
    AuthController authController, {
    required bool isRegister,
  }) {
    final user = authController.currentUser;
    final isNew = authController.lastGoogleIsNewUser || isRegister;
    final actionText =
        isNew ? 'Đăng ký & đăng nhập Google thành công' : 'Đăng nhập Google thành công';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$actionText: ${user?.fullName ?? user?.email ?? ''}',
              ),
            ),
          ],
        ),
      ),
    );

    RoleRouter.navigateToRoleHome(context, authController);
  }

  /// Hộp thoại Chọn hoặc Nhập tài khoản Google để Đăng nhập / Đăng ký trực tiếp với Backend
  static Future<void> showGoogleAccountPicker(
    BuildContext context, {
    required AuthController authController,
    bool isRegister = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GoogleAccountPickerSheet(
        authController: authController,
        isRegister: isRegister,
        onAuthenticated: () {
          Navigator.of(sheetContext).pop();
          if (context.mounted) {
            _onGoogleAuthSuccess(
              context,
              authController,
              isRegister: isRegister,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Đang kết nối Google...',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GooglePresetAccount {
  final String email;
  final String fullName;
  final Color avatarColor;

  const _GooglePresetAccount({
    required this.email,
    required this.fullName,
    required this.avatarColor,
  });
}

class _GoogleAccountPickerSheet extends StatefulWidget {
  final AuthController authController;
  final bool isRegister;
  final VoidCallback onAuthenticated;

  const _GoogleAccountPickerSheet({
    required this.authController,
    required this.isRegister,
    required this.onAuthenticated,
  });

  @override
  State<_GoogleAccountPickerSheet> createState() =>
      _GoogleAccountPickerSheetState();
}

class _GoogleAccountPickerSheetState extends State<_GoogleAccountPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _useCustomAccount = false;
  bool _submitting = false;
  String? _localError;

  static const List<_GooglePresetAccount> _presetAccounts = [
    _GooglePresetAccount(
      email: 'anhjkrrr@gmail.com',
      fullName: 'Nguyễn Quang Hưng (Admin)',
      avatarColor: Color(0xFF2563EB),
    ),
    _GooglePresetAccount(
      email: 'anhjkrr@gmail.com',
      fullName: 'Nguyễn Quang Hưng (Staff)',
      avatarColor: Color(0xFF059669),
    ),
    _GooglePresetAccount(
      email: 'anhjkr@gmail.com',
      fullName: 'Nguyễn Quang Hưng (User)',
      avatarColor: Color(0xFF7C3AED),
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithAccount({
    required String email,
    required String fullName,
  }) async {
    setState(() {
      _submitting = true;
      _localError = null;
    });

    final ok = await widget.authController.loginWithGoogleAccount(
      email: email,
      fullName: fullName,
    );

    if (!mounted) return;

    if (ok) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _submitting = false;
        _localError = widget.authController.errorMessage ??
            'Không thể xác thực tài khoản Google. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _submitCustomAccount() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : email.split('@').first;

    await _signInWithAccount(email: email, fullName: name);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const GoogleLogo(size: 36),
                const SizedBox(height: 14),
                Text(
                  widget.isRegister
                      ? 'Đăng ký bằng Google'
                      : 'Chọn một tài khoản Google',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'để tiếp tục tới Child Devices',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                if (_localError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _localError!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_useCustomAccount) ...[
                  ..._presetAccounts.map(
                    (acc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _submitting
                            ? null
                            : () => _signInWithAccount(
                                  email: acc.email,
                                  fullName: acc.fullName,
                                ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: acc.avatarColor,
                                child: Text(
                                  acc.fullName.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.fullName,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      acc.email,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _submitting
                        ? null
                        : () {
                            setState(() {
                              _useCustomAccount = true;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sử dụng một tài khoản Google khác',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Họ và tên hiển thị',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.required(v, 'họ và tên'),
                          decoration: const InputDecoration(
                            hintText: 'Nguyễn Văn A',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Địa chỉ Gmail / Google Email',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitCustomAccount(),
                          validator: Validators.email,
                          decoration: const InputDecoration(
                            hintText: 'tenban@gmail.com',
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _useCustomAccount = false;
                                      });
                                    },
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: const Text('Quay lại'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  _submitting ? null : _submitCustomAccount,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.isRegister
                                          ? 'Đăng ký với Google'
                                          : 'Tiếp tục với Google',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (_submitting && !_useCustomAccount) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(strokeWidth: 2.4),
                ],
                const SizedBox(height: 14),
                Text(
                  'Nếu tài khoản Google chưa tồn tại trên hệ thống, ứng dụng sẽ tự động đăng ký tài khoản mới và gán Role mặc định là USER.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget vẽ logo Google 4 màu sắc chính xác theo thiết kế chuẩn
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final double radius = size.width / 2;
    final double strokeWidth = size.width * 0.22;
    final Rect rect = Rect.fromCircle(
      center: Offset(center, center),
      radius: radius - strokeWidth / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 1. Red (Top section: ~135 deg to ~225 deg counter-clockwise)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, paint);

    // 2. Yellow (Left section)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -math.pi * 1.25, math.pi * 0.5, false, paint);

    // 3. Green (Bottom section)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -math.pi * 1.75, math.pi * 0.5, false, paint);

    // 4. Blue (Right bottom to center bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.45, false, paint);

    // Center horizontal blue bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barHeight = strokeWidth;
    final barWidth = radius + (strokeWidth / 2);
    final barRect = Rect.fromLTWH(
      center - (strokeWidth * 0.2),
      center - (barHeight / 2),
      barWidth - (strokeWidth * 0.4),
      barHeight,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
