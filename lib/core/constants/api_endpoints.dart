class ApiEndpoints {
  // Auth endpoints
  static const String login = '/Auth/login';
  static const String register = '/Auth/register';
  static const String googleAuth = '/Auth/google';
  static const String sendOtp = '/Auth/send-otp';
  static const String sendLoginOtp = '/Auth/send-login-otp';
  static const String verifyOtp = '/Auth/verify-otp';
  static const String me = '/Auth/me';
  static const String users = '/Auth/users';
  static String updateUserRole(int userId) => '/Auth/users/$userId/role';

  // Device endpoints
  static const String devices = '/Devices';
  static String deviceDetail(int id) => '/Devices/$id';

  // Video Call endpoints (LiveKit - Chỉ dành cho User và Staff)
  static const String videoCallRooms = '/VideoCall/rooms';
  static const String videoCallCreate = '/VideoCall/create-room';
  static const String videoCallJoin = '/VideoCall/join';
  static const String videoCallLeave = '/VideoCall/leave';
  static String videoCallRoom(String roomName) => '/VideoCall/rooms/$roomName';
  static String videoCallParticipants(String roomName) => '/VideoCall/rooms/$roomName/participants';
  static String videoCallEnd(String roomName) => '/VideoCall/rooms/$roomName';

  // Location Sharing endpoints (Chỉ dành riêng cho User)
  static const String locationDashboard = '/Location/dashboard';
  static const String locationShare = '/Location/share';
  static const String locationLiveUpdate = '/Location/live';
  static const String locationStopLive = '/Location/stop-live';
  static String locationByCode(String code) => '/Location/code/$code';
  static String locationDelete(String id) => '/Location/$id';
}
