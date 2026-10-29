import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../data/models/call_models.dart';
import '../../data/services/video_call_service.dart';

enum CallType { oneToOne, group, support }

class VideoCallScreen extends StatefulWidget {
  final VideoCallToken token;
  final String participantName;
  final String participantRole;
  final CallType callType;
  final bool isHost;
  final bool initialAudioOnly;

  const VideoCallScreen({
    super.key,
    required this.token,
    required this.participantName,
    this.participantRole = 'USER',
    this.callType = CallType.support,
    this.isHost = false,
    this.initialAudioOnly = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoCallService _callService = VideoCallService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _isConnecting = true;
  String? _errorMessage;
  bool _isMicMuted = false;
  late bool _isCameraOff;
  bool _isSpeakerOn = true;
  bool _isLeaving = false;

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _isCameraOff = widget.initialAudioOnly || widget.token.isAudioOnly;
    _connectToRoom();
    _startTimer();
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isConnecting && _errorMessage == null) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _extractParticipantRole(Participant p) {
    try {
      if (p.metadata != null && p.metadata!.isNotEmpty) {
        final decoded = jsonDecode(p.metadata!);
        if (decoded is Map && decoded['role'] != null) {
          return decoded['role'].toString().toUpperCase();
        }
      }
    } catch (_) {}
    if (p.identity.toLowerCase().contains('staff')) return 'STAFF';
    return 'USER';
  }

  Future<void> _connectToRoom() async {
    // Chặn tuyệt đối nếu Role là ADMIN
    if (widget.participantRole.trim().toUpperCase() == 'ADMIN' ||
        widget.token.participantRole.trim().toUpperCase() == 'ADMIN') {
      setState(() {
        _isConnecting = false;
        _errorMessage =
            'Tài khoản Admin không có chức năng gọi điện. Chức năng này chỉ dành cho User và Staff.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            maxFrameRate: 30,
          ),
        ),
      );

      _room = room;
      _listener = room.createListener();

      _listener!
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted && !_isLeaving) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cuộc gọi đã kết thúc')),
            );
            Navigator.of(context).pop();
          }
        })
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) {
            final pName = event.participant.name.isNotEmpty
                ? event.participant.name
                : event.participant.identity;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF059669),
                content: Text('$pName đã tham gia cuộc gọi'),
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {});
          }
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) {
            final pName = event.participant.name.isNotEmpty
                ? event.participant.name
                : event.participant.identity;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('$pName đã rời cuộc gọi'),
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {});
          }
        })
        ..on<TrackSubscribedEvent>((_) => setState(() {}))
        ..on<TrackUnsubscribedEvent>((_) => setState(() {}))
        ..on<LocalTrackPublishedEvent>((_) => setState(() {}))
        ..on<LocalTrackUnpublishedEvent>((_) => setState(() {}))
        ..on<TrackMutedEvent>((_) => setState(() {}))
        ..on<TrackUnmutedEvent>((_) => setState(() {}));

      // Kết nối tới LiveKit Server bằng Token do Server cấp
      await room.connect(
        widget.token.wsUrl,
        widget.token.token,
      );

      try {
        // ignore: deprecated_member_use
        await room.setSpeakerOn(_isSpeakerOn);
      } catch (_) {}

      // Bật Microphone (và Camera nếu không phải gọi thoại thuần túy)
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (!_isCameraOff) {
          await room.localParticipant?.setCameraEnabled(true);
        }
      } catch (e) {
        debugPrint('Không thể truy cập camera/micro: $e');
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Không thể kết nối cuộc gọi: $e';
        });
      }
    }
  }

  Future<void> _toggleMic() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    final newState = !_isMicMuted;
    try {
      await participant.setMicrophoneEnabled(!newState);
      setState(() => _isMicMuted = newState);
    } catch (e) {
      debugPrint('Lỗi bật/tắt mic: $e');
    }
  }

  Future<void> _toggleCamera() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    final newState = !_isCameraOff;
    try {
      await participant.setCameraEnabled(!newState);
      setState(() => _isCameraOff = newState);
    } catch (e) {
      debugPrint('Lỗi bật/tắt camera: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    try {
      // ignore: deprecated_member_use
      await _room?.setSpeakerOn(newState);
      setState(() => _isSpeakerOn = newState);
    } catch (e) {
      debugPrint('Lỗi chuyển đổi loa ngoài: $e');
    }
  }

  Future<void> _switchCamera() async {
    final track = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track is LocalVideoTrack) {
      final options = track.currentOptions;
      if (options is CameraCaptureOptions) {
        try {
          final currentPos = options.cameraPosition;
          final newPos = currentPos.switched();
          await track.restartTrack(options.copyWith(cameraPosition: newPos));
          setState(() {});
        } catch (e) {
          debugPrint('Lỗi đảo camera: $e');
        }
      }
    }
  }

  void _showParticipantsSheet() {
    final room = _room;
    if (room == null) return;

    final remotes = room.remoteParticipants.values.toList();
    final localRole = widget.participantRole.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thành viên trong cuộc gọi (${remotes.length + 1})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.token.roomName));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép mã phòng: ${widget.token.roomName}'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.blueAccent),
                    label: Text(
                      widget.token.roomName,
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: localRole == 'STAFF'
                      ? const Color(0xFF059669)
                      : const Color(0xFF2563EB),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  '${widget.participantName} (Bạn)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Vai trò: $localRole',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _isMicMuted ? Colors.redAccent : Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      color: _isCameraOff ? Colors.redAccent : Colors.greenAccent,
                      size: 18,
                    ),
                  ],
                ),
              ),
              ...remotes.map((r) {
                final rRole = _extractParticipantRole(r);
                final rName = r.name.isNotEmpty ? r.name : r.identity;
                final rMic = r.isMicrophoneEnabled();
                final rCam = r.isCameraEnabled();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: rRole == 'STAFF'
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    child: const Icon(Icons.person_outline, color: Colors.white),
                  ),
                  title: Text(
                    rName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Vai trò: $rRole',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rMic ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: rMic ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        rCam ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        color: rCam ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleEndCall() async {
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Kết thúc cuộc gọi'),
        content: Text(
          widget.isHost
              ? 'Bạn có muốn rời khỏi cuộc gọi hay đóng phòng gọi cho tất cả mọi người?'
              : 'Bạn có chắc chắn muốn rời cuộc gọi này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Ở lại'),
          ),
          if (widget.isHost)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'end_all'),
              child: const Text(
                'Đóng phòng gọi',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'leave'),
            child: const Text('Rời cuộc gọi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == 'end_all') {
      await _callService.endRoom(widget.token.roomName);
      await _cleanupAndLeave();
    } else if (confirmed == 'leave') {
      await _cleanupAndLeave();
    }
  }

  Future<void> _cleanupAndLeave() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _callTimer?.cancel();
    try {
      await _callService.leaveRoom(widget.token.roomName);
    } catch (_) {}
    try {
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    if (!_isLeaving) {
      _callService.leaveRoom(widget.token.roomName);
      _room?.disconnect();
      _room?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleEndCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: _isConnecting
              ? _buildConnectingView()
              : _errorMessage != null
                  ? _buildErrorView()
                  : _buildCallLayout(),
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            _isCameraOff
                ? 'Đang kết nối Cuộc gọi Thoại (User - Staff)...'
                : 'Đang kết nối Video Call (User - Staff)...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phòng: ${widget.token.roomName} • Vai trò: ${widget.participantRole.toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 30),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: _cleanupAndLeave,
            child: const Text('Hủy kết nối'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 54),
            const SizedBox(height: 16),
            const Text(
              'Không thể tham gia cuộc gọi',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: _cleanupAndLeave,
                  child: const Text('Quay lại'),
                ),
                const SizedBox(width: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: _connectToRoom,
                  child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallLayout() {
    final room = _room;
    if (room == null) return const SizedBox();

    final remoteParticipants = room.remoteParticipants.values.toList();
    final isGroup = widget.callType == CallType.group || remoteParticipants.length > 1;

    return Stack(
      children: [
        // Main Video Area
        Positioned.fill(
          child: isGroup
              ? _buildGroupVideoGrid(room, remoteParticipants)
              : _buildOneToOneVideoView(room, remoteParticipants),
        ),

        // Top Header Overlay
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _buildTopHeader(remoteParticipants.length + 1),
        ),

        // Bottom Controls Overlay
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _buildTopHeader(int totalParticipants) {
    final isStaff = widget.participantRole.toUpperCase() == 'STAFF';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(155),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isStaff ? const Color(0xFF059669) : const Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCameraOff ? Icons.phone_in_talk_rounded : Icons.videocam_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _showParticipantsSheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Phòng: ${widget.token.roomName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isStaff
                              ? const Color(0xFF059669).withAlpha(80)
                              : const Color(0xFF2563EB).withAlpha(80),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.participantRole.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$totalParticipants người tham gia • Chạm để xem danh sách',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sao chép mã phòng',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.token.roomName));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Đã sao chép mã phòng: ${widget.token.roomName}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_callDurationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1-1 Layout: Remote full screen + Local in PiP
  Widget _buildOneToOneVideoView(Room room, List<RemoteParticipant> remotes) {
    final localTrack =
        room.localParticipant?.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    final isStaff = widget.participantRole.toUpperCase() == 'STAFF';

    if (remotes.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: (isStaff ? const Color(0xFF059669) : const Color(0xFF2563EB))
                          .withAlpha(35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isStaff ? const Color(0xFF10B981) : Colors.blueAccent)
                            .withAlpha(120),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isStaff ? Icons.support_agent_rounded : Icons.family_restroom_rounded,
                      size: 48,
                      color: isStaff ? const Color(0xFF34D399) : Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isStaff
                        ? 'Đang chờ Phụ huynh (USER) tham gia phòng...'
                        : 'Đang kết nối tới Nhân viên hỗ trợ (STAFF) / Thiết bị...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'Mã phòng: ${widget.token.roomName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đối phương chỉ cần chọn đúng phòng này trong mục Gọi Điện để đàm thoại trực tiếp.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Local camera preview in PiP corner
          Positioned(
            right: 16,
            bottom: 100,
            width: 115,
            height: 165,
            child: _buildPiPCard(
              localTrack,
              '${widget.participantName} (${widget.participantRole.toUpperCase()})',
            ),
          ),
        ],
      );
    }

    final remote = remotes.first;
    final remoteTrack = remote.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    final remoteRole = _extractParticipantRole(remote);
    final remoteName = remote.name.isNotEmpty ? remote.name : remote.identity;

    return Stack(
      children: [
        // Full screen remote participant
        Positioned.fill(
          child: remoteTrack != null && remote.isCameraEnabled()
              ? VideoTrackRenderer(remoteTrack, fit: VideoViewFit.cover)
              : _buildAvatarTile('$remoteName ($remoteRole)', role: remoteRole),
        ),

        // Local video PiP
        Positioned(
          right: 16,
          bottom: 100,
          width: 115,
          height: 165,
          child: _buildPiPCard(
            localTrack,
            '${widget.participantName} (Bạn)',
          ),
        ),
      ],
    );
  }

  Widget _buildPiPCard(VideoTrack? track, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (track != null && !_isCameraOff)
            VideoTrackRenderer(track, fit: VideoViewFit.cover)
          else
            _buildAvatarTile(label, small: true, role: widget.participantRole),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 9.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Group Call: Responsive Grid
  Widget _buildGroupVideoGrid(Room room, List<RemoteParticipant> remotes) {
    final localTrack =
        room.localParticipant?.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    final localName = '${widget.participantName} (Bạn • ${widget.participantRole.toUpperCase()})';

    final allParticipants = <Widget>[
      _buildParticipantTile(
        track: _isCameraOff ? null : localTrack,
        name: localName,
        role: widget.participantRole.toUpperCase(),
        isMuted: _isMicMuted,
        isLocal: true,
      ),
      ...remotes.map((remote) {
        final track = remote.videoTrackPublications.firstOrNull?.track as VideoTrack?;
        final isMuted = !remote.isMicrophoneEnabled();
        final role = _extractParticipantRole(remote);
        final name = remote.name.isNotEmpty ? remote.name : remote.identity;
        return _buildParticipantTile(
          track: remote.isCameraEnabled() ? track : null,
          name: '$name ($role)',
          role: role,
          isMuted: isMuted,
          isLocal: false,
        );
      }),
    ];

    final count = allParticipants.length;
    int crossAxisCount = 1;
    if (count >= 3) crossAxisCount = 2;

    return Padding(
      padding: const EdgeInsets.only(top: 74, bottom: 94, left: 10, right: 10),
      child: GridView.builder(
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: count == 2 ? 1.15 : 0.9,
        ),
        itemBuilder: (context, index) => allParticipants[index],
      ),
    );
  }

  Widget _buildParticipantTile({
    required VideoTrack? track,
    required String name,
    required String role,
    required bool isMuted,
    required bool isLocal,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: role == 'STAFF'
              ? const Color(0xFF10B981).withAlpha(100)
              : Colors.white12,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: track != null
                ? VideoTrackRenderer(track, fit: VideoViewFit.cover)
                : _buildAvatarTile(name, role: role),
          ),
          // Name and mic badge
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isMuted ? Colors.red.withAlpha(200) : Colors.black.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarTile(String name, {bool small = false, String role = 'USER'}) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    final isStaff = role.toUpperCase() == 'STAFF';
    final color = isStaff ? const Color(0xFF10B981) : Colors.blueAccent;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: small ? 20 : 38,
            backgroundColor: color.withAlpha(45),
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: small ? 16 : 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!small) ...[
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isCameraOff ? 'Đang gọi thoại âm thanh hai chiều' : 'Camera đang tắt',
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(185),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic Button
          _buildControlButton(
            icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _isMicMuted ? Colors.redAccent : Colors.white,
            bgColor: _isMicMuted ? Colors.redAccent.withAlpha(40) : Colors.white12,
            tooltip: _isMicMuted ? 'Bật mic' : 'Tắt mic',
            onTap: _toggleMic,
          ),

          // Camera Button
          _buildControlButton(
            icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            color: _isCameraOff ? Colors.redAccent : Colors.white,
            bgColor: _isCameraOff ? Colors.redAccent.withAlpha(40) : Colors.white12,
            tooltip: _isCameraOff ? 'Bật camera' : 'Tắt camera',
            onTap: _toggleCamera,
          ),

          // Speaker Button
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            color: _isSpeakerOn ? Colors.greenAccent : Colors.white,
            bgColor: _isSpeakerOn ? Colors.greenAccent.withAlpha(35) : Colors.white12,
            tooltip: _isSpeakerOn ? 'Loa ngoài: Bật' : 'Loa trong',
            onTap: _toggleSpeaker,
          ),

          // Switch Camera Flip Button
          _buildControlButton(
            icon: Icons.flip_camera_ios_rounded,
            color: Colors.white,
            bgColor: Colors.white12,
            tooltip: 'Đổi camera trước/sau',
            onTap: _switchCamera,
          ),

          // Participants List Button
          _buildControlButton(
            icon: Icons.people_alt_rounded,
            color: Colors.white,
            bgColor: Colors.white12,
            tooltip: 'Thành viên trong phòng',
            onTap: _showParticipantsSheet,
          ),

          // End Call Hangup Button
          _buildControlButton(
            icon: Icons.call_end_rounded,
            color: Colors.white,
            bgColor: Colors.red,
            tooltip: 'Kết thúc cuộc gọi',
            onTap: _handleEndCall,
            isBig: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
    bool isBig = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: isBig ? 52 : 44,
          height: isBig ? 52 : 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: isBig ? 24 : 20),
        ),
      ),
    );
  }
}
