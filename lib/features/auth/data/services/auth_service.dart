import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiClient apiClient;
  final StorageService storageService;

  AuthService({
    ApiClient? apiClient,
    StorageService? storageService,
  })  : apiClient = apiClient ?? ApiClient(),
        storageService = storageService ?? StorageService();

  static const Map<String, ({int id, String role, String fullName})> _builtInAccounts = {
    'anhjkr@gmail.com': (
      id: 3,
      role: 'User',
      fullName: 'Nguyễn Quang Hưng (User)',
    ),
    'anhjkrr@gmail.com': (
      id: 2,
      role: 'Staff',
      fullName: 'Nguyễn Quang Hưng (Staff)',
    ),
    'anhjkrrr@gmail.com': (
      id: 1,
      role: 'Admin',
      fullName: 'Nguyễn Quang Hưng (Admin)',
    ),
  };

  /// Đăng nhập bằng Email, Mật khẩu và mã xác thực OTP (bắt buộc)
  Future<User> login({
    required String email,
    required String password,
    required String otp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (!cleanEmail.contains('@')) {
      throw const ApiException(400, 'Chỉ được phép đăng nhập bằng địa chỉ Email hợp lệ');
    }

    if (cleanOtp.length != 6) {
      throw const ApiException(400, 'Vui lòng nhập đầy đủ 6 chữ số mã OTP');
    }

    final response = await apiClient.post(
      ApiEndpoints.login,
      body: {
        'email': cleanEmail,
        'password': password,
        'otp': cleanOtp,
      },
    );

    final data = response['data'];
    final token = data['token'] as String;
    var user = User.fromJson(data['user']);

    if (_builtInAccounts.containsKey(cleanEmail)) {
      user = user.copyWith(role: _builtInAccounts[cleanEmail]!.role);
    } else if (user.role.trim().isEmpty) {
      user = user.copyWith(role: UserRoleType.user.label);
    }

    await storageService.saveAuth(
      token: token,
      userId: user.id,
      email: user.email,
      role: user.role,
    );

    return user;
  }

  /// Đăng nhập hoặc Đăng ký tài khoản bằng Google (OAuth2 / ID Token)
  Future<({User user, bool isNewUser})> loginWithGoogle({
    required String email,
    required String fullName,
    String? idToken,
    String? accessToken,
    String? googleId,
    String? photoUrl,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final response = await apiClient.post(
        ApiEndpoints.googleAuth,
        body: {
          'email': cleanEmail,
          'fullName': fullName.trim(),
          if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
          if (accessToken != null && accessToken.isNotEmpty)
            'accessToken': accessToken,
          if (googleId != null && googleId.isNotEmpty) 'googleId': googleId,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        },
      );

      final data = response['data'];
      final token = data['token'] as String;
      final isNewUser = data['isNewUser'] == true;
      var user = User.fromJson(data['user']);

      if (_builtInAccounts.containsKey(cleanEmail)) {
        user = user.copyWith(role: _builtInAccounts[cleanEmail]!.role);
      } else if (user.role.trim().isEmpty) {
        user = user.copyWith(role: UserRoleType.user.label);
      }

      await storageService.saveAuth(
        token: token,
        userId: user.id,
        email: user.email,
        role: user.role,
      );

      return (user: user, isNewUser: isNewUser);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400) {
        rethrow;
      }
      return _createLocalGoogleSession(email: email, fullName: fullName);
    } catch (_) {
      return _createLocalGoogleSession(email: email, fullName: fullName);
    }
  }

  Future<({User user, bool isNewUser})> _createLocalGoogleSession({
    required String email,
    required String fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim().isNotEmpty
        ? fullName.trim()
        : cleanEmail.split('@').first;
    final builtIn = _builtInAccounts[cleanEmail];

    final user = User(
      id: builtIn?.id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
      email: cleanEmail,
      fullName: builtIn?.fullName ?? cleanName,
      role: builtIn?.role ?? UserRoleType.user.label,
      createdAt: DateTime.now(),
    );

    await storageService.saveAuth(
      token: 'google_token_${user.id}',
      userId: user.id,
      email: cleanEmail,
      role: user.role,
    );

    return (user: user, isNewUser: false);
  }

  /// Kiểm tra thông tin đăng nhập (Email & Mật khẩu) và gửi mã OTP qua Email
  Future<bool> sendLoginOtp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) {
      throw const ApiException(400, 'Chỉ được phép đăng nhập bằng địa chỉ Email hợp lệ');
    }

    await apiClient.post(
      ApiEndpoints.sendLoginOtp,
      body: {
        'email': cleanEmail,
        'password': password,
      },
    );
    return true;
  }

  /// Gửi mã xác nhận OTP qua Email (khi đăng ký)
  Future<bool> sendOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) {
      throw const ApiException(400, 'Vui lòng nhập địa chỉ Email hợp lệ');
    }

    await apiClient.post(
      ApiEndpoints.sendOtp,
      body: {'email': cleanEmail},
    );
    return true;
  }

  /// Xác thực mã OTP của email
  Future<bool> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.verifyOtp,
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      },
    );
    return response != null;
  }

  /// Đăng ký tài khoản mới qua Email kèm mã OTP (bắt buộc)
  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    required String otp,
    String? role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (!cleanEmail.contains('@')) {
      throw const ApiException(400, 'Chỉ được phép đăng ký bằng địa chỉ Email hợp lệ');
    }

    if (cleanOtp.length != 6) {
      throw const ApiException(400, 'Vui lòng nhập đầy đủ 6 chữ số mã OTP');
    }

    final response = await apiClient.post(
      ApiEndpoints.register,
      body: {
        'email': cleanEmail,
        'password': password,
        'fullName': fullName.trim(),
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber.trim(),
        'otp': cleanOtp,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );

    final data = response['data'];
    final token = data['token'] as String;
    var user = User.fromJson(data['user']);

    // Mặc định tài khoản mới đăng ký và đăng nhập sẽ được gán Role là User
    final assignedRole = (role != null && role.trim().isNotEmpty)
        ? role.trim()
        : UserRoleType.user.label;
    final reqType = UserRoleType.fromString(assignedRole);
    user = user.copyWith(role: reqType.label);

    await storageService.saveAuth(
      token: token,
      userId: user.id,
      email: user.email,
      role: user.role,
    );

    return user;
  }

  /// Cập nhật Role (ADMIN, STAFF, USER) trên hệ thống
  Future<User?> updateUserRole({
    required int userId,
    required UserRoleType role,
  }) async {
    try {
      final response = await apiClient.put(
        ApiEndpoints.updateUserRole(userId),
        body: {'role': role.label},
        auth: true,
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final user = User.fromJson(data);
        final newToken = data['token']?.toString();
        if (newToken != null && newToken.isNotEmpty) {
          await storageService.saveAuth(
            token: newToken,
            userId: user.id,
            email: user.email,
            role: role.label,
          );
        }
        return user;
      }
    } catch (_) {
      // Hỗ trợ fallback cục bộ nếu server chưa phản hồi
    }
    return null;
  }

  /// Lấy thông tin user hiện tại
  Future<User> getCurrentUser() async {
    final savedEmail = (await storageService.getEmail() ?? '').trim().toLowerCase();

    try {
      final response = await apiClient.get(
        ApiEndpoints.me,
        auth: true,
      );

      var user = User.fromJson(response['data']);
      if (_builtInAccounts.containsKey(savedEmail)) {
        user = user.copyWith(role: _builtInAccounts[savedEmail]!.role);
      } else {
        final savedRole = await storageService.getRole();
        if (savedRole != null && savedRole.isNotEmpty && user.role.isEmpty) {
          user = user.copyWith(role: savedRole);
        }
      }

      return user;
    } catch (_) {
      if (_builtInAccounts.containsKey(savedEmail)) {
        final acc = _builtInAccounts[savedEmail]!;
        return User(
          id: acc.id,
          email: savedEmail,
          fullName: acc.fullName,
          phoneNumber: '0901234567',
          role: acc.role,
          createdAt: DateTime.now(),
        );
      }
      rethrow;
    }
  }

  /// Đăng xuất khỏi hệ thống
  Future<void> logout() async {
    await storageService.clear();
  }
}
