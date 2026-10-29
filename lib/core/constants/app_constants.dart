class AppConstants {
  // Cấu hình môi trường mạng backend
  // - Flutter Web/Windows: 'http://localhost:5057/api'
  // - Android Emulator: 'http://10.0.2.2:5057/api'
  // - Điện thoại thật (Wi-Fi LAN): 'http://192.168.1.106:5057/api'
  static const String baseUrl = 'http://192.168.1.106:5057/api';

  static const String appName = 'Child Devices';
  static const int requestTimeoutSeconds = 30;
}
