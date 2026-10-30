import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/appearance_controller.dart';
import '../../../../core/widgets/appearance_settings_modal.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthController authController;

  const EditProfileScreen({super.key, required this.authController});

  static Future<bool?> navigate(
    BuildContext context,
    AuthController authController,
  ) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(authController: authController),
      ),
    );
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _changePassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final user = widget.authController.currentUser;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final currentPassword = _changePassword
        ? _currentPasswordController.text
        : null;
    final newPassword = _changePassword ? _newPasswordController.text : null;

    final success = await widget.authController.updateProfile(
      fullName: fullName,
      phoneNumber: phone.isEmpty ? null : phone,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cập nhật hồ sơ cá nhân thành công!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      final err =
          widget.authController.errorMessage ??
          'Không thể cập nhật hồ sơ, vui lòng thử lại';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(err)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final isUpdating = widget.authController.isUpdatingProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ cá nhân'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: 'Đổi màu nền Mobile',
            onPressed: () => AppearanceSettingsModal.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Avatar & Role Info Card
              _buildUserHeaderCard(user),
              const SizedBox(height: 20),

              // Thông tin cơ bản
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thông tin cơ bản',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Họ và tên
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Họ và tên *',
                      hintText: 'Nhập họ và tên đầy đủ',
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ và tên';
                        }
                        if (value.trim().length < 2) {
                          return 'Họ và tên phải có ít nhất 2 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Số điện thoại
                    AppTextField(
                      controller: _phoneController,
                      label: 'Số điện thoại liên hệ',
                      hintText: 'Ví dụ: 0912345678',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null; // Số điện thoại là tùy chọn
                        }
                        final digits = value.replaceAll(
                          RegExp(r'[\s\-\(\)\.]'),
                          '',
                        );
                        if (digits.length < 8 || digits.length > 13) {
                          return 'Số điện thoại không hợp lệ (8 - 13 số)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email (Readonly)
                    TextFormField(
                      initialValue: user?.email ?? '',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email tài khoản (Cố định)',
                        prefixIcon: const Icon(Icons.email_outlined, size: 22),
                        suffixIcon: const Tooltip(
                          message: 'Email dùng để đăng nhập và định danh, không thể thay đổi',
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                      ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card Thay đổi mật khẩu
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: _changePassword,
                        onChanged: (val) {
                          setState(() {
                            _changePassword = val;
                            if (!val) {
                              _currentPasswordController.clear();
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                            }
                          });
                        },
                        title: const Text(
                          'Đổi mật khẩu tài khoản',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Cập nhật mật khẩu bảo mật mới cho tài khoản của bạn',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        activeThumbColor: AppColors.primary,
                      ),
                      if (_changePassword) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              AppTextField(
                                controller: _currentPasswordController,
                                label: 'Mật khẩu hiện tại *',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscureCurrentPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureCurrentPassword =
                                          !_obscureCurrentPassword,
                                    );
                                  },
                                ),
                                validator: (val) {
                                  if (!_changePassword) return null;
                                  if (val == null || val.isEmpty) {
                                    return 'Vui lòng nhập mật khẩu hiện tại';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _newPasswordController,
                                label: 'Mật khẩu mới *',
                                hintText: 'Tối thiểu 6 ký tự',
                                icon: Icons.lock_reset_rounded,
                                obscureText: _obscureNewPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureNewPassword =
                                          !_obscureNewPassword,
                                    );
                                  },
                                ),
                                validator: (val) {
                                  if (!_changePassword) return null;
                                  if (val == null || val.isEmpty) {
                                    return 'Vui lòng nhập mật khẩu mới';
                                  }
                                  if (val.length < 6) {
                                    return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _confirmPasswordController,
                                label: 'Xác nhận mật khẩu mới *',
                                icon: Icons.check_circle_outline_rounded,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    );
                                  },
                                ),
                                validator: (val) {
                                  if (!_changePassword) return null;
                                  if (val == null || val.isEmpty) {
                                    return 'Vui lòng xác nhận mật khẩu mới';
                                  }
                                  if (val != _newPasswordController.text) {
                                    return 'Mật khẩu xác nhận không trùng khớp';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Card Tùy chỉnh màu nền Mobile
              _buildAppearanceCard(context),
              const SizedBox(height: 24),

              // Button Lưu hồ sơ
              AppButton(
                text: 'Lưu thay đổi hồ sơ',
                icon: Icons.save_rounded,
                loading: isUpdating,
                onPressed: isUpdating ? null : _handleSave,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(dynamic user) {
    final fullName = user?.fullName ?? 'Người dùng';
    final initial = fullName.isNotEmpty
        ? fullName.substring(0, 1).toUpperCase()
        : 'U';
    final role = user?.role ?? 'USER';

    Color badgeColor = const Color(0xFF2563EB);
    Color badgeBg = const Color(0xFFEFF6FF);
    String roleLabel = 'NGƯỜI DÙNG (USER)';

    if (role.toString().toUpperCase() == 'ADMIN') {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEE2E2);
      roleLabel = 'QUẢN TRỊ VIÊN (ADMIN)';
    } else if (role.toString().toUpperCase() == 'STAFF') {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFD1FAE5);
      roleLabel = 'NHÂN VIÊN VẬN HÀNH (STAFF)';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: badgeBg,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final appearance = AppearanceController.instance;

    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        final currentPreset = appearance.currentPreset;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Màu Nền Ứng Dụng Di Động',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Đang áp dụng: ${currentPreset.name}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: currentPreset.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Bạn có thể thay đổi màu nền ứng dụng sang các phong cách dịu mắt (Sepia, Bạc hà, Xanh dịu, Chế độ tối AMOLED) hoặc chọn mã màu HEX tùy ý.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.color_lens_rounded, size: 18),
                  label: const Text(
                    'Đổi Màu Nền Mobile Ngay',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => AppearanceSettingsModal.show(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
