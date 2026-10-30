import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = 'access_token';
  static const String userIdKey = 'user_id';
  static const String emailKey = 'email';
  static const String roleKey = 'role';

  // Biometric & Last Login keys
  static const String lastEmailKey = 'last_logged_in_email';
  static const String biometricEmailKey = 'biometric_email';
  static const String biometricTokenKey = 'biometric_token';
  static const String biometricRoleKey = 'biometric_role';
  static const String biometricUserIdKey = 'biometric_user_id';
  static const String biometricFullNameKey = 'biometric_full_name';
  static const String biometricEnabledKey = 'biometric_enabled';

  Future<void> saveAuth({
    required String token,
    required int userId,
    required String email,
    required String role,
    String? fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setInt(userIdKey, userId);
    await prefs.setString(emailKey, email);
    await prefs.setString(roleKey, role);

    // Lưu lại email đăng nhập gần nhất để tự điền và kích hoạt đăng nhập vân tay
    await prefs.setString(lastEmailKey, email);
    await prefs.setString(biometricEmailKey, email);
    await prefs.setString(biometricTokenKey, token);
    await prefs.setString(biometricRoleKey, role);
    await prefs.setInt(biometricUserIdKey, userId);
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString(biometricFullNameKey, fullName);
    }
    await prefs.setBool(biometricEnabledKey, true);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(roleKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(userIdKey);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(emailKey);
  }

  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastEmailKey) ?? prefs.getString(emailKey);
  }

  Future<void> setLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastEmailKey, email);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(biometricEnabledKey, enabled);
  }

  Future<String?> getBiometricEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(biometricEmailKey) ?? prefs.getString(lastEmailKey);
  }

  Future<String?> getBiometricToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(biometricTokenKey);
  }

  Future<String?> getBiometricRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(biometricRoleKey);
  }

  Future<int?> getBiometricUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(biometricUserIdKey);
  }

  Future<String?> getBiometricFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(biometricFullNameKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cập nhật thông tin họ tên và token mới sau khi sửa hồ sơ
  Future<void> updateStoredProfile({
    required String fullName,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(biometricFullNameKey, fullName);
    if (token != null && token.isNotEmpty) {
      await prefs.setString(tokenKey, token);
      await prefs.setString(biometricTokenKey, token);
    }
  }

  /// Khi người dùng đăng xuất: Xóa phiên làm việc hiện tại nhưng giữ lại thông tin
  /// email đăng nhập gần nhất và dữ liệu xác thực vân tay để cho phép đăng nhập lại nhanh.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userIdKey);
    await prefs.remove(emailKey);
    await prefs.remove(roleKey);
  }

  /// Xóa sạch toàn bộ dữ liệu bao gồm cả vân tay và email đã nhớ
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
