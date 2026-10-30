import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyen_quang_hung/core/storage/storage_service.dart';
import 'package:nguyen_quang_hung/core/errors/api_exception.dart';
import 'package:nguyen_quang_hung/features/auth/data/models/user_model.dart';
import 'package:nguyen_quang_hung/features/auth/data/services/auth_service.dart';
import 'package:nguyen_quang_hung/features/auth/presentation/controllers/auth_controller.dart';

class MockAuthService extends AuthService {
  User? mockUser;
  bool shouldThrow = false;
  String throwMessage = 'Mật khẩu hiện tại không chính xác';

  MockAuthService({this.mockUser});

  @override
  Future<User> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? currentPassword,
    String? newPassword,
  }) async {
    if (shouldThrow) {
      throw ApiException(401, throwMessage);
    }
    if (fullName.trim().isEmpty) {
      throw const ApiException(400, 'Họ và tên không được để trống');
    }

    final updated = (mockUser ?? const User(
      id: 1,
      email: 'test@example.com',
      fullName: 'Original Name',
      role: 'User',
    )).copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber,
    );
    mockUser = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Update Profile Tests', () {
    test('updateProfile updates currentUser in AuthController successfully', () async {
      final initialUser = const User(
        id: 1,
        email: 'anhjkr@gmail.com',
        fullName: 'Nguyễn Quang Hưng',
        phoneNumber: '0901234567',
        role: 'User',
      );

      final fakeAuthService = MockAuthService(mockUser: initialUser);
      final authController = AuthController(authService: fakeAuthService);
      authController.currentUser = initialUser;

      final success = await authController.updateProfile(
        fullName: 'Nguyễn Quang Hưng (Mới)',
        phoneNumber: '0988888888',
      );

      expect(success, true);
      expect(authController.currentUser?.fullName, 'Nguyễn Quang Hưng (Mới)');
      expect(authController.currentUser?.phoneNumber, '0988888888');
      expect(authController.errorMessage, isNull);
    });

    test('updateProfile sets errorMessage when current password is wrong', () async {
      final initialUser = const User(
        id: 1,
        email: 'anhjkr@gmail.com',
        fullName: 'Nguyễn Quang Hưng',
        role: 'User',
      );

      final fakeAuthService = MockAuthService(mockUser: initialUser)
        ..shouldThrow = true
        ..throwMessage = 'Mật khẩu hiện tại không chính xác';

      final authController = AuthController(authService: fakeAuthService);
      authController.currentUser = initialUser;

      final success = await authController.updateProfile(
        fullName: 'Nguyễn Quang Hưng',
        currentPassword: 'wrong_password',
        newPassword: 'new_password_123',
      );

      expect(success, false);
      expect(authController.errorMessage, 'Mật khẩu hiện tại không chính xác');
      expect(authController.currentUser?.fullName, 'Nguyễn Quang Hưng');
    });

    test('updateStoredProfile updates biometric full name in SharedPreferences', () async {
      final storage = StorageService();
      await storage.saveAuth(
        token: 'initial_token',
        userId: 1,
        email: 'test@gmail.com',
        role: 'User',
        fullName: 'Họ tên cũ',
      );

      expect(await storage.getBiometricFullName(), 'Họ tên cũ');

      await storage.updateStoredProfile(
        fullName: 'Họ tên mới',
        token: 'refreshed_token',
      );

      expect(await storage.getBiometricFullName(), 'Họ tên mới');
      expect(await storage.getToken(), 'refreshed_token');
    });
  });
}

