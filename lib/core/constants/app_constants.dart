import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

enum AppEnvironment {
  development,
  production,
}

class AppConstants {
  static final Map<String, String> _envValues = {};

  static const String _defaultDevBaseUrl = 'http://localhost:5057/api';
  static const String _defaultProdBaseUrl = 'https://mobile.zeion.online/api';

  // URLs fallback cho môi trường Development khi thử nghiệm
  static const List<String> devFallbackUrls = [
    'http://localhost:5057/api',
    'http://127.0.0.1:5057/api',
    'http://10.0.2.2:5057/api', // Dành cho Android Emulator
  ];

  static const String appName = 'NguyenQuangHung';
  static const int requestTimeoutSeconds = 30;

  /// Đọc cấu hình từ file `.env` được khai báo trong assets
  static Future<void> init() async {
    try {
      final content = await rootBundle.loadString('.env');
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final separatorIndex = trimmed.indexOf('=');
        if (separatorIndex != -1) {
          final key = trimmed.substring(0, separatorIndex).trim();
          final value = trimmed.substring(separatorIndex + 1).trim();
          _envValues[key] = value;
        }
      }
      debugPrint('[AppConstants] Đã tải .env thành công. Môi trường: ${environment.name} | BaseUrl: $baseUrl');
    } catch (e) {
      debugPrint('[AppConstants] Không tìm thấy file .env trong assets (sử dụng compile-time define hoặc mặc định): $e');
    }
  }

  /// Lấy giá trị biến môi trường theo độ ưu tiên:
  /// 1. File .env (runtime qua AppConstants.init)
  /// 2. --dart-define / --dart-define-from-file (compile time)
  /// 3. Giá trị mặc định [defaultValue]
  static String getEnv(String key, {String defaultValue = ''}) {
    final fromRuntime = _envValues[key]?.trim();
    if (fromRuntime != null && fromRuntime.isNotEmpty) {
      return fromRuntime;
    }

    if (key == 'ENVIRONMENT') {
      const v = String.fromEnvironment('ENVIRONMENT');
      if (v.isNotEmpty) return v;
      const v2 = String.fromEnvironment('ENV');
      if (v2.isNotEmpty) return v2;
    } else if (key == 'BASE_API_URL') {
      const v = String.fromEnvironment('BASE_API_URL');
      if (v.isNotEmpty) return v;
    } else if (key == 'DEV_API_URL') {
      const v = String.fromEnvironment('DEV_API_URL');
      if (v.isNotEmpty) return v;
    } else if (key == 'PROD_API_URL') {
      const v = String.fromEnvironment('PROD_API_URL');
      if (v.isNotEmpty) return v;
    }

    return defaultValue;
  }

  /// Cờ môi trường hiện tại được xác định từ .env
  static AppEnvironment get environment {
    final env = getEnv('ENVIRONMENT', defaultValue: 'development').toLowerCase();
    if (env == 'prod' || env == 'production') {
      return AppEnvironment.production;
    }
    return AppEnvironment.development;
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => !isProduction;

  /// Base URL động theo cấu hình file .env
  static String get baseUrl {
    // 1. Kiểm tra nếu có biến BASE_API_URL được set cụ thể
    final explicitUrl = getEnv('BASE_API_URL');
    if (explicitUrl.isNotEmpty) {
      return explicitUrl;
    }

    // 2. Lấy URL theo cờ ENVIRONMENT
    if (isProduction) {
      return getEnv('PROD_API_URL', defaultValue: _defaultProdBaseUrl);
    } else {
      return getEnv('DEV_API_URL', defaultValue: _defaultDevBaseUrl);
    }
  }
}
