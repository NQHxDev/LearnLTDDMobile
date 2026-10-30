import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyen_quang_hung/core/storage/storage_service.dart';
import 'package:nguyen_quang_hung/core/services/biometric_service.dart';
import 'package:nguyen_quang_hung/features/auth/presentation/controllers/auth_controller.dart';
import 'package:nguyen_quang_hung/features/auth/data/services/auth_service.dart';

class FakeBiometricService extends BiometricService {
  bool shouldSucceed;
  FakeBiometricService({this.shouldSucceed = true});

  @override
  Future<bool> isBiometricSupported({bool forceRefresh = false}) async => true;

  @override
  Future<({bool success, String? errorMessage})> authenticate({
    String localizedReason = 'Vui lòng quét vân tay để đăng nhập nhanh vào ứng dụng',
  }) async {
    if (shouldSucceed) {
      return (success: true, errorMessage: null);
    } else {
      return (success: false, errorMessage: 'Xác thực vân tay thất bại');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Biometric Auth & StorageService Tests', () {
    test('saveAuth preserves last_email and biometric info when user logs in', () async {
      final storage = StorageService();

      await storage.saveAuth(
        token: 'test_token_123',
        userId: 3,
        email: 'anhjkr@gmail.com',
        role: 'User',
        fullName: 'Nguyễn Quang Hưng (User)',
      );

      expect(await storage.getToken(), 'test_token_123');
      expect(await storage.getEmail(), 'anhjkr@gmail.com');
      expect(await storage.getLastEmail(), 'anhjkr@gmail.com');
      expect(await storage.isBiometricEnabled(), true);
      expect(await storage.getBiometricEmail(), 'anhjkr@gmail.com');
      expect(await storage.getBiometricFullName(), 'Nguyễn Quang Hưng (User)');
    });

    test('clear() on logout removes active token but retains last email for next biometric login', () async {
      final storage = StorageService();

      await storage.saveAuth(
        token: 'test_token_123',
        userId: 3,
        email: 'anhjkr@gmail.com',
        role: 'User',
      );

      expect(await storage.isLoggedIn(), true);

      // User logs out
      await storage.clear();

      // Active session is cleared
      expect(await storage.isLoggedIn(), false);
      expect(await storage.getToken(), isNull);
      expect(await storage.getEmail(), isNull);

      // But last email and biometric settings remain for fast re-login
      expect(await storage.getLastEmail(), 'anhjkr@gmail.com');
      expect(await storage.isBiometricEnabled(), true);
    });

    test('AuthController logs in via biometrics without password or OTP', () async {
      final storage = StorageService();
      final fakeBiometric = FakeBiometricService(shouldSucceed: true);
      final authService = AuthService(storageService: storage);

      final controller = AuthController(
        authService: authService,
        storageService: storage,
        biometricService: fakeBiometric,
      );

      // Pre-save previous login
      await storage.saveAuth(
        token: 'old_token',
        userId: 3,
        email: 'anhjkr@gmail.com',
        role: 'User',
        fullName: 'Nguyễn Quang Hưng (User)',
      );
      await storage.clear(); // Log out

      final lastEmail = await controller.getLastLoggedInEmail();
      expect(lastEmail, 'anhjkr@gmail.com');

      // Login with biometrics (skipping OTP and password)
      final success = await controller.loginWithBiometrics(email: lastEmail);

      expect(success, true);
      expect(controller.isLoggedIn, true);
      expect(controller.currentUser?.email, 'anhjkr@gmail.com');
      expect(controller.currentUser?.role, 'User');
      expect(await storage.isLoggedIn(), true);
    });

    test('AuthController fails gracefully if biometric scan fails', () async {
      final storage = StorageService();
      final fakeBiometric = FakeBiometricService(shouldSucceed: false);
      final authService = AuthService(storageService: storage);

      final controller = AuthController(
        authService: authService,
        storageService: storage,
        biometricService: fakeBiometric,
      );

      await storage.setLastEmail('anhjkr@gmail.com');

      final success = await controller.loginWithBiometrics(email: 'anhjkr@gmail.com');

      expect(success, false);
      expect(controller.isLoggedIn, false);
      expect(controller.errorMessage, 'Xác thực vân tay thất bại');
    });
  });
}
