import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth;

  // Cached state for performance optimization on lower-end devices
  bool? _isSupportedCached;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Kiểm tra thiết bị có phần cứng và hỗ trợ xác thực sinh trắc học / vân tay hay không.
  /// Kết quả được cache để tối ưu hóa hiệu năng, giảm thiểu các lệnh gọi platform channel trên máy cấu hình yếu.
  Future<bool> isBiometricSupported({bool forceRefresh = false}) async {
    if (!forceRefresh && _isSupportedCached != null) {
      return _isSupportedCached!;
    }

    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      _isSupportedCached = isSupported || canCheck;
      return _isSupportedCached!;
    } catch (e) {
      debugPrint('BiometricService.isBiometricSupported Error: $e');
      _isSupportedCached = false;
      return false;
    }
  }

  /// Lấy danh sách các loại sinh trắc học có sẵn trên thiết bị (vân tay, khuôn mặt,...)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService.getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Thực hiện quét vân tay / sinh trắc học native
  /// Tối ưu máy yếu bằng options: persistAcrossBackgrounding = true, biometricOnly = false
  Future<({bool success, String? errorMessage})> authenticate({
    String localizedReason = 'Vui lòng quét vân tay để đăng nhập nhanh vào ứng dụng',
  }) async {
    try {
      final supported = await isBiometricSupported();
      if (!supported) {
        return (
          success: false,
          errorMessage: 'Thiết bị không hỗ trợ hoặc chưa đăng ký vân tay',
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
        biometricOnly: false,
      );

      return (
        success: authenticated,
        errorMessage: authenticated ? null : 'Xác thực vân tay bị hủy hoặc thất bại',
      );
    } on LocalAuthException catch (e) {
      debugPrint('BiometricService.authenticate LocalAuthException: ${e.code} ${e.description}');
      String message;
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          message = 'Thiết bị không có phần cứng vân tay';
          break;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          message = 'Thiết bị chưa cài đặt vân tay. Vui lòng vào Cài đặt để thêm vân tay';
          break;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          message = 'Đã quét sai quá nhiều lần. Cảm biến sinh trắc học tạm khóa';
          break;
        case LocalAuthExceptionCode.noCredentialsSet:
          message = 'Thiết bị chưa cài mã PIN hoặc hình vẽ khóa màn hình';
          break;
        case LocalAuthExceptionCode.userCanceled:
          message = 'Bạn đã hủy quét vân tay';
          break;
        default:
          message = e.description ?? 'Không thể xác thực vân tay';
      }
      return (success: false, errorMessage: message);
    } catch (e) {
      debugPrint('BiometricService.authenticate Error: $e');
      return (
        success: false,
        errorMessage: 'Đã xảy ra lỗi khi xác thực vân tay',
      );
    }
  }

  /// Hủy phiên xác thực nếu đang chạy
  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
