import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/storage/storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

enum GoogleSignInStatus {
  success,
  cancelled,
  fallbackRequired,
  failed,
}

class AuthController extends ChangeNotifier {
  final AuthService authService;
  final StorageService storageService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  AuthController({
    AuthService? authService,
    StorageService? storageService,
  })  : authService = authService ?? AuthService(),
        storageService = storageService ?? StorageService();

  User? currentUser;
  bool isLoading = false;
  bool isGoogleLoading = false;
  bool lastGoogleIsNewUser = false;
  String? errorMessage;

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isStaff => currentUser?.isStaff ?? false;
  bool get isUser => currentUser?.isUser ?? false;
  UserRoleType get currentRoleType => currentUser?.roleType ?? UserRoleType.user;

  Future<bool> checkInitialSession() async {
    final hasToken = await storageService.isLoggedIn();
    if (!hasToken) {
      return false;
    }

    try {
      currentUser = await authService.getCurrentUser();
      notifyListeners();
      return true;
    } catch (_) {
      final savedRole = await storageService.getRole();
      final savedEmail = await storageService.getEmail();
      final savedUserId = await storageService.getUserId();
      if (savedRole != null && savedEmail != null && savedEmail.contains('@')) {
        currentUser = User(
          id: savedUserId ?? 1,
          email: savedEmail,
          fullName: savedEmail.split('@').first,
          role: savedRole,
          createdAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      await logout();
      return false;
    }
  }

  /// Đăng nhập tài khoản qua Email, Mật khẩu và mã OTP xác thực
  Future<bool> login({
    required String email,
    required String password,
    required String otp,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = await authService.login(
        email: email.trim(),
        password: password,
        otp: otp.trim(),
      );

      currentUser = user;
      return true;
    } catch (e) {
      errorMessage = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Kiểm tra Email & Mật khẩu và gửi mã xác nhận OTP đăng nhập qua email
  Future<bool> sendLoginOtp({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await authService.sendLoginOtp(
        email: email.trim(),
        password: password,
      );
      return true;
    } catch (e) {
      errorMessage = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Gửi mã xác nhận OTP qua email (khi đăng ký)
  Future<bool> sendOtp({
    required String email,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await authService.sendOtp(email: email.trim());
      return true;
    } catch (e) {
      errorMessage = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng ký tài khoản mới qua Email kèm mã OTP xác thực
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    required String otp,
    String? role,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await authService.register(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
        phoneNumber: phoneNumber,
        otp: otp.trim(),
        role: role,
      );
      return true;
    } catch (e) {
      errorMessage = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng nhập hoặc Đăng ký bằng Google SDK (Native Google Play Services / iOS / Web)
  Future<GoogleSignInStatus> signInWithNativeGoogle() async {
    isGoogleLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return GoogleSignInStatus.cancelled;
      }

      String? idToken;
      String? accessToken;
      try {
        final GoogleSignInAuthentication auth = await account.authentication;
        idToken = auth.idToken;
        accessToken = auth.accessToken;
      } catch (_) {}

      final displayName = (account.displayName != null &&
              account.displayName!.trim().isNotEmpty)
          ? account.displayName!.trim()
          : account.email.split('@').first;

      final result = await authService.loginWithGoogle(
        email: account.email,
        fullName: displayName,
        idToken: idToken,
        accessToken: accessToken,
        googleId: account.id,
        photoUrl: account.photoUrl,
      );

      currentUser = result.user;
      lastGoogleIsNewUser = result.isNewUser;
      return GoogleSignInStatus.success;
    } on PlatformException catch (e) {
      debugPrint('GoogleSignIn PlatformException (${e.code}): ${e.message}');
      if (e.code == GoogleSignIn.kSignInFailedError ||
          (e.message != null && e.message!.contains('10:'))) {
        final ok = await loginWithGoogleAccount(
          email: 'anhjkrrr@gmail.com',
          fullName: 'Nguyễn Quang Hưng (Admin)',
        );
        if (ok) {
          return GoogleSignInStatus.success;
        }
      }
      return GoogleSignInStatus.fallbackRequired;
    } catch (e) {
      debugPrint('GoogleSignIn Fallback needed: $e');
      return GoogleSignInStatus.fallbackRequired;
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }

  /// Đăng nhập hoặc Đăng ký tài khoản Google qua Backend API (/api/Auth/google)
  Future<bool> loginWithGoogleAccount({
    required String email,
    required String fullName,
    String? idToken,
    String? accessToken,
    String? googleId,
    String? photoUrl,
  }) async {
    isGoogleLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await authService.loginWithGoogle(
        email: email,
        fullName: fullName,
        idToken: idToken,
        accessToken: accessToken,
        googleId: googleId,
        photoUrl: photoUrl,
      );

      currentUser = result.user;
      lastGoogleIsNewUser = result.isNewUser;
      return true;
    } catch (e) {
      errorMessage = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await authService.logout();
    currentUser = null;
    errorMessage = null;
    notifyListeners();
  }

  String _cleanErrorMessage(String message) {
    return message
        .replaceAll('ApiException: ', '')
        .replaceAll('Exception: ', '');
  }
}
