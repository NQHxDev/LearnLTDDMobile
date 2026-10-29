import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/call_models.dart';

class VideoCallService {
  final ApiClient _apiClient;
  final StorageService _storageService;

  VideoCallService({
    ApiClient? apiClient,
    StorageService? storageService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService();

  /// Đảm bảo chỉ User và Staff mới được phép sử dụng tính năng gọi điện (Admin bị chặn hoàn toàn)
  Future<void> _ensureCallRoleAllowed([UserRoleType? explicitRole]) async {
    final roleType = explicitRole ??
        UserRoleType.fromString(await _storageService.getRole());

    if (roleType == UserRoleType.admin) {
      throw const ApiException(
        403,
        'Tài khoản Admin không có chức năng gọi điện. Chức năng gọi điện chỉ dành cho User và Staff.',
      );
    }
  }

  /// Lấy danh sách các phòng gọi đang hoạt động trên Server
  Future<List<VideoCallRoom>> getActiveRooms({UserRoleType? currentRole}) async {
    await _ensureCallRoleAllowed(currentRole);

    final response = await _apiClient.get(
      ApiEndpoints.videoCallRooms,
      auth: true,
    );

    final list = response['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(VideoCallRoom.fromJson)
        .toList();
  }

  /// Tạo hoặc kích hoạt phòng gọi trên Server
  Future<VideoCallRoom> createRoom({
    required String roomName,
    int maxParticipants = 10,
    String callType = 'support',
    String? description,
    UserRoleType? currentRole,
  }) async {
    await _ensureCallRoleAllowed(currentRole);

    final response = await _apiClient.post(
      ApiEndpoints.videoCallCreate,
      body: {
        'roomName': roomName.trim(),
        'maxParticipants': maxParticipants,
        'callType': callType,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
      auth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return VideoCallRoom.fromJson(data);
  }

  /// Tham gia phòng gọi và nhận LiveKit Token từ Server
  Future<VideoCallToken> joinRoom({
    required String roomName,
    required String participantName,
    bool isAudioOnly = false,
    UserRoleType? currentRole,
  }) async {
    await _ensureCallRoleAllowed(currentRole);

    final response = await _apiClient.post(
      ApiEndpoints.videoCallJoin,
      body: {
        'roomName': roomName.trim(),
        'participantName': participantName.trim(),
        'isAudioOnly': isAudioOnly,
      },
      auth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return VideoCallToken.fromJson(data);
  }

  /// Khởi tạo (nếu chưa có) và tham gia ngay vào phòng gọi giữa User và Staff
  Future<VideoCallToken> startOrJoinCall({
    required String roomName,
    required String participantName,
    required UserRoleType currentRole,
    String callType = 'support',
    String? description,
    int maxParticipants = 10,
    bool isAudioOnly = false,
  }) async {
    await _ensureCallRoleAllowed(currentRole);

    try {
      await createRoom(
        roomName: roomName,
        maxParticipants: maxParticipants,
        callType: callType,
        description: description,
        currentRole: currentRole,
      );
    } catch (_) {
      // Nếu phòng đã tồn tại trên Server, tiếp tục joinRoom để lấy token
    }

    return joinRoom(
      roomName: roomName,
      participantName: participantName,
      isAudioOnly: isAudioOnly,
      currentRole: currentRole,
    );
  }

  /// Rời khỏi phòng gọi trên Server
  Future<void> leaveRoom(String roomName) async {
    try {
      await _apiClient.post(
        ApiEndpoints.videoCallLeave,
        body: {'roomName': roomName.trim()},
        auth: true,
      );
    } catch (_) {}
  }

  /// Lấy thông tin chi tiết phòng gọi
  Future<VideoCallRoom?> getRoomInfo(String roomName) async {
    await _ensureCallRoleAllowed();
    try {
      final response = await _apiClient.get(
        ApiEndpoints.videoCallRoom(roomName.trim()),
        auth: true,
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return VideoCallRoom.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách người đang tham gia trong phòng
  Future<List<CallParticipant>> getParticipants(String roomName) async {
    await _ensureCallRoleAllowed();
    final response = await _apiClient.get(
      ApiEndpoints.videoCallParticipants(roomName.trim()),
      auth: true,
    );
    final list = response['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CallParticipant.fromJson)
        .toList();
  }

  /// Kết thúc phòng gọi (chỉ dành cho User và Staff)
  Future<bool> endRoom(String roomName) async {
    await _ensureCallRoleAllowed();
    try {
      await _apiClient.delete(
        ApiEndpoints.videoCallEnd(roomName.trim()),
        auth: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
