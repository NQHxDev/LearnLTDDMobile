import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/location_models.dart';

class LocationMapPreviewWidget extends StatefulWidget {
  final GpsPositionModel position;
  final List<KidLocationModel> kidLocations;
  final bool isLiveSharing;
  final ValueChanged<Offset>? onTapPinCoordinate;
  final VoidCallback onRecenterHardwareGps;
  final VoidCallback onOpenExternalMaps;

  const LocationMapPreviewWidget({
    super.key,
    required this.position,
    this.kidLocations = const [],
    this.isLiveSharing = false,
    this.onTapPinCoordinate,
    required this.onRecenterHardwareGps,
    required this.onOpenExternalMaps,
  });

  @override
  State<LocationMapPreviewWidget> createState() =>
      _LocationMapPreviewWidgetState();
}

class _LocationMapPreviewWidgetState extends State<LocationMapPreviewWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _zoom = 16; // Mức zoom chi tiết từng con đường (13 -> 18)

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Chuyển đổi Vĩ độ / Kinh độ sang tọa độ Pixel toàn cầu theo chuẩn Web Mercator (EPSG:3857)
  static Offset _latLngToWorldPixel(double lat, double lng, int zoom) {
    final scale = 256.0 * (1 << zoom);
    final x = (lng + 180.0) / 360.0 * scale;
    final sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final y =
        (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
            scale;
    return Offset(x, y);
  }

  // Ngược lại: Chuyển đổi từ tọa độ Pixel toàn cầu sang (Latitude, Longitude) chuẩn xác
  static Offset _worldPixelToLatLng(double worldX, double worldY, int zoom) {
    final scale = 256.0 * (1 << zoom);
    final lng = (worldX / scale) * 360.0 - 180.0;
    final n = math.pi - (2.0 * math.pi * worldY) / scale;
    final lat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return Offset(lat.clamp(-85.0, 85.0), lng.clamp(-180.0, 180.0));
  }

  // Tính số mét thực tế trên mỗi Pixel tại vĩ độ hiện tại
  static double _metersPerPixel(double latitude, int zoom) {
    return (156543.03392 * math.cos(latitude * math.pi / 180.0)) / (1 << zoom);
  }

  void _handleMapTap(TapUpDetails details, Size mapSize) {
    if (widget.onTapPinCoordinate == null) return;

    final centerPixel = _latLngToWorldPixel(
      widget.position.latitude,
      widget.position.longitude,
      _zoom,
    );
    final dx = details.localPosition.dx - (mapSize.width / 2.0);
    final dy = details.localPosition.dy - (mapSize.height / 2.0);

    final tappedLatLng = _worldPixelToLatLng(
      centerPixel.dx + dx,
      centerPixel.dy + dy,
      _zoom,
    );
    widget.onTapPinCoordinate!(tappedLatLng);
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final metersPerPx = _metersPerPixel(pos.latitude, _zoom);
    final accuracyRadiusPx =
        (pos.accuracyMeters / metersPerPx).clamp(16.0, 95.0);

    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLiveSharing
              ? const Color(0xFF10B981)
              : const Color(0xFFBFDBFE),
          width: widget.isLiveSharing ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final centerWorld =
                _latLngToWorldPixel(pos.latitude, pos.longitude, _zoom);

            return GestureDetector(
              onTapUp: (details) => _handleMapTap(details, size),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Lưới tọa độ Radar nền phòng khi chưa tải xong Tile
                  CustomPaint(
                    painter: _TacticalGpsGridPainter(),
                  ),

                  // 2. Lớp bản đồ đường phố thực tế OpenStreetMap (3x3 Tiles chuẩn Mercator)
                  _buildOsmTileGrid(size, centerWorld),

                  // 3. Vòng bán kính sai số GPS & Marker của các Bé + User
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _GpsOverlayPainter(
                          pulseValue: _pulseController.value,
                          accuracyRadiusPx: accuracyRadiusPx,
                          bearingDegrees: pos.bearingDegrees,
                          isLiveSharing: widget.isLiveSharing,
                        ),
                      );
                    },
                  ),

                  // 4. Các điểm đánh dấu của các Bé nếu nằm trong vùng hiển thị bản đồ
                  ..._buildKidMarkersOnMap(size, centerWorld),

                  // 5. Điểm ghim trung tâm (Vị trí của User)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isLiveSharing
                                ? const Color(0xFF059669)
                                : const Color(0xFF1E40AF),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(65),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isLiveSharing
                                    ? Icons.sensors_rounded
                                    : Icons.my_location_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isLiveSharing
                                    ? 'LIVE GPS • ±${pos.accuracyMeters.toStringAsFixed(1)}m'
                                    : 'Bạn (USER) • ±${pos.accuracyMeters.toStringAsFixed(1)}m',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: widget.isLiveSharing
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(80),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),

                  // 6. Thanh trạng thái Tín hiệu Vệ tinh ở góc trên trái
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 56,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withAlpha(215),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.satellite_alt_rounded,
                                color: Color(0xFF38BDF8),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${pos.providerVietnameseLabel} (${pos.satellites} vệ tinh)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withAlpha(215),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Plus: ${pos.plusCode}',
                            style: const TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 7. Cụm nút Zoom (+/-) và Khóa lại Tâm Vệ Tinh ở góc phải
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _buildMapIconButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Phóng to bản đồ',
                          onTap: () {
                            if (_zoom < 18) {
                              setState(() => _zoom++);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildMapIconButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Thu nhỏ bản đồ',
                          onTap: () {
                            if (_zoom > 13) {
                              setState(() => _zoom--);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildMapIconButton(
                          icon: Icons.gps_fixed_rounded,
                          tooltip: 'Lấy lại tâm GPS Vệ tinh chuẩn',
                          color: const Color(0xFF2563EB),
                          onTap: widget.onRecenterHardwareGps,
                        ),
                      ],
                    ),
                  ),

                  // 8. Thanh hướng dẫn chạm tinh chỉnh ghim & mở Google Maps ở đáy bản đồ
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withAlpha(215),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  color: Color(0xFF38BDF8),
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Chạm lên bản đồ nếu muốn dời ghim chính xác từng mét',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: widget.onOpenExternalMaps,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Google Maps',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOsmTileGrid(Size size, Offset centerWorld) {
    final centerTileX = (centerWorld.dx / 256.0).floor();
    final centerTileY = (centerWorld.dy / 256.0).floor();
    final maxTileIndex = (1 << _zoom) - 1;

    final offsetInCenterTileX = centerWorld.dx - (centerTileX * 256.0);
    final offsetInCenterTileY = centerWorld.dy - (centerTileY * 256.0);

    final centerTileScreenLeft = (size.width / 2.0) - offsetInCenterTileX;
    final centerTileScreenTop = (size.height / 2.0) - offsetInCenterTileY;

    final tiles = <Widget>[];
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final tileX = (centerTileX + dx) % (1 << _zoom);
        final wrappedX = tileX < 0 ? tileX + (1 << _zoom) : tileX;
        final tileY = (centerTileY + dy).clamp(0, maxTileIndex);

        final left = centerTileScreenLeft + (dx * 256.0);
        final top = centerTileScreenTop + (dy * 256.0);

        if (left + 256 < 0 ||
            left > size.width ||
            top + 256 < 0 ||
            top > size.height) {
          continue;
        }

        final url =
            'https://tile.openstreetmap.org/$_zoom/$wrappedX/$tileY.png';

        tiles.add(
          Positioned(
            left: left,
            top: top,
            width: 256.5,
            height: 256.5,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              headers: const {
                'User-Agent': 'NguyenQuangHungApp/1.0',
              },
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      }
    }

    return Stack(children: tiles);
  }

  List<Widget> _buildKidMarkersOnMap(Size size, Offset centerWorld) {
    final widgets = <Widget>[];

    for (final kid in widget.kidLocations) {
      final kidWorld =
          _latLngToWorldPixel(kid.latitude, kid.longitude, _zoom);
      final screenX = (size.width / 2.0) + (kidWorld.dx - centerWorld.dx);
      final screenY = (size.height / 2.0) + (kidWorld.dy - centerWorld.dy);

      if (screenX < 20 ||
          screenX > size.width - 20 ||
          screenY < 20 ||
          screenY > size.height - 20) {
        continue;
      }

      widgets.add(
        Positioned(
          left: screenX - 45,
          top: screenY - 36,
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  kid.kidName.split('(').first.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildMapIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: color ?? const Color(0xFF0F172A).withAlpha(215),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _TacticalGpsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = const Color(0xFF38BDF8).withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 45, ringPaint);
    canvas.drawCircle(center, 95, ringPaint);
    canvas.drawCircle(center, 145, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GpsOverlayPainter extends CustomPainter {
  final double pulseValue;
  final double accuracyRadiusPx;
  final double bearingDegrees;
  final bool isLiveSharing;

  _GpsOverlayPainter({
    required this.pulseValue,
    required this.accuracyRadiusPx,
    required this.bearingDegrees,
    required this.isLiveSharing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor =
        isLiveSharing ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    // Vòng bán kính độ chính xác thực tế của GPS (±X mét)
    final accuracyFill = Paint()
      ..color = baseColor.withAlpha(38)
      ..style = PaintingStyle.fill;
    final accuracyStroke = Paint()
      ..color = baseColor.withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, accuracyRadiusPx, accuracyFill);
    canvas.drawCircle(center, accuracyRadiusPx, accuracyStroke);

    // Sóng Radar lan tỏa
    final pulseRadius = 14.0 + (pulseValue * 58.0);
    final pulseAlpha = ((1.0 - pulseValue) * 140).round().clamp(0, 255);
    final pulsePaint = Paint()
      ..color = baseColor.withAlpha(pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, pulseRadius, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _GpsOverlayPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accuracyRadiusPx != accuracyRadiusPx ||
        oldDelegate.isLiveSharing != isLiveSharing;
  }
}

