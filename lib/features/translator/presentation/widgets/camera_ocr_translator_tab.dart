import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/en_vi_translator_service.dart';

class DetectedBlockOverlay {
  final Rect boundingBox;
  final String text;

  const DetectedBlockOverlay({
    required this.boundingBox,
    required this.text,
  });
}

class CameraOcrTranslatorTab extends StatefulWidget {
  const CameraOcrTranslatorTab({super.key});

  @override
  State<CameraOcrTranslatorTab> createState() => _CameraOcrTranslatorTabState();
}

class _CameraOcrTranslatorTabState extends State<CameraOcrTranslatorTab>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final EnViTranslatorService _translatorService = EnViTranslatorService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isInitializingCamera = true;
  bool _hasPermission = false;
  bool _isProcessingFrame = false;
  bool _isTranslating = false;
  final bool _isAutoLiveScan = true;
  bool _isFrozen = false;
  bool _focusCenterBoxOnly = true;
  bool _isFlashOn = false;
  String? _errorMessage;

  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _recognizedEnglishText = '';
  String _translatedVietnameseText = '';
  String _lastTranslatedSource = '';

  List<DetectedBlockOverlay> _detectedBlocks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCameraStreamAndDispose();
    _textRecognizer.close();
    _translatorService.stopSpeaking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopCameraStreamAndDispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _stopCameraStreamAndDispose() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      setState(() {
        _isInitializingCamera = false;
        _errorMessage = 'Tính năng quét Camera OCR chỉ hỗ trợ trên thiết bị Mobile.';
      });
      return;
    }

    setState(() {
      _isInitializingCamera = true;
      _errorMessage = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _hasPermission = false;
          _isInitializingCamera = false;
          _errorMessage = 'Vui lòng cấp quyền Camera để di chuyển máy ảnh vào chữ và dịch tự động.';
        });
        return;
      }

      _hasPermission = true;
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isInitializingCamera = false;
          _errorMessage = 'Không tìm thấy Camera trên thiết bị này. Bạn có thể chọn ảnh hoặc dùng chế độ Demo.';
        });
        return;
      }

      // Ưu tiên camera sau để giơ lên quét chữ
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto).catchError((_) {});

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _isInitializingCamera = false;
      });

      if (_isAutoLiveScan && !_isFrozen) {
        await _startLiveStream();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
        _errorMessage = 'Không thể khởi tạo Camera: $e';
      });
    }
  }

  Future<void> _startLiveStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      await controller.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('Stream start warning: $e');
    }
  }

  Future<void> _stopLiveStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;

    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!_isAutoLiveScan || _isFrozen || _isProcessingFrame) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 850) return;

    final controller = _cameraController;
    if (controller == null) return;

    _isProcessingFrame = true;
    _lastScanTime = now;

    try {
      final inputImage = _convertCameraImageToInputImage(image, controller.description);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted || _isFrozen) {
        _isProcessingFrame = false;
        return;
      }

      final imgWidth = image.width.toDouble();
      final imgHeight = image.height.toDouble();

      _processRecognizedResult(
        recognizedText,
        imageSize: Size(imgWidth, imgHeight),
      );
    } catch (e) {
      debugPrint('Live OCR frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _processRecognizedResult(
    RecognizedText recognizedText, {
    Size? imageSize,
  }) {
    final List<DetectedBlockOverlay> overlays = [];
    final List<String> selectedParagraphs = [];

    for (final block in recognizedText.blocks) {
      final cleanedBlock = block.text.replaceAll('\n', ' ').trim();
      if (cleanedBlock.length < 2) continue;

      // Bỏ qua các chuỗi chỉ toàn số hoặc ký tự đặc biệt
      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(cleanedBlock)) continue;

      if (_focusCenterBoxOnly && imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
        // Kiểm tra tâm của block có nằm trong vùng ngắm (20% -> 80% chiều dọc, 10% -> 90% chiều ngang)
        final center = block.boundingBox.center;
        final normX = center.dx / imageSize.width;
        final normY = center.dy / imageSize.height;

        if (normX < 0.08 || normX > 0.92 || normY < 0.15 || normY > 0.85) {
          continue;
        }
      }

      overlays.add(
        DetectedBlockOverlay(
          boundingBox: block.boundingBox,
          text: cleanedBlock,
        ),
      );
      selectedParagraphs.add(cleanedBlock);
    }

    final combinedEnglish = selectedParagraphs.join('\n').trim();

    if (combinedEnglish.isEmpty) {
      if (mounted && _detectedBlocks.isNotEmpty) {
        setState(() {
          _detectedBlocks = [];
        });
      }
      return;
    }

    setState(() {
      _detectedBlocks = overlays;
      _recognizedEnglishText = combinedEnglish;
    });

    // Chỉ gọi API dịch khi nội dung tiếng Anh thay đổi đáng kể
    if (combinedEnglish.toLowerCase() != _lastTranslatedSource.toLowerCase()) {
      _lastTranslatedSource = combinedEnglish;
      _translateRecognizedText(combinedEnglish);
    }
  }

  Future<void> _translateRecognizedText(String englishText) async {
    if (englishText.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    final viResult = await _translatorService.translateEnToVi(englishText);
    if (!mounted) return;

    setState(() {
      _translatedVietnameseText = viResult;
      _isTranslating = false;
    });
  }

  /// Chuyển đổi CameraImage (NV21 / YUV_420_888 / BGRA8888) sang InputImage chuẩn ML Kit
  InputImage? _convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation90deg;

      if (Platform.isIOS) {
        if (image.planes.isEmpty) return null;
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }

      // Android: Xử lý cả trường hợp 1 plane (NV21) và 3 planes (YUV_420_888 trên CameraX)
      if (image.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }

      if (image.planes.length == 3) {
        final nv21Bytes = _yuv420ToNv21(image);
        return InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      }
    } catch (e) {
      debugPrint('Convert camera image error: $e');
    }
    return null;
  }

  /// Chuyển đổi 3-plane YUV_420_888 sang NV21 nguyên khối (tương thích mọi máy Android CameraX)
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    int pos = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[pos++] = yBuffer[rowStart + col * yPixelStride];
      }
    }

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      final int rowStart = row * uvRowStride;
      for (int col = 0; col < uvWidth; col++) {
        final int uvIndex = rowStart + col * uvPixelStride;
        if (uvIndex < vBuffer.length && pos < nv21.length) {
          nv21[pos++] = vBuffer[uvIndex];
        }
        if (uvIndex < uBuffer.length && pos < nv21.length) {
          nv21[pos++] = uBuffer[uvIndex];
        }
      }
    }

    return nv21;
  }

  /// Chụp khung hình độ phân giải cao và dịch ngay lập tức
  Future<void> _captureAndTranslateSnapshot() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isTranslating = true;
      _isFrozen = true;
    });

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final XFile file = await controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      final cleanedText = recognized.text.replaceAll('\n', ' ').trim();
      if (cleanedText.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy chữ Tiếng Anh trong khung hình. Hãy đưa camera lại gần chữ hơn.'),
          ),
        );
        setState(() {
          _isTranslating = false;
          _isFrozen = false;
        });
        if (_isAutoLiveScan) await _startLiveStream();
        return;
      }

      setState(() {
        _recognizedEnglishText = cleanedText;
      });

      final viResult = await _translatorService.translateEnToVi(cleanedText);
      if (!mounted) return;

      setState(() {
        _translatedVietnameseText = viResult;
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
        _isFrozen = false;
      });
      if (_isAutoLiveScan) await _startLiveStream();
    }
  }

  /// Chọn ảnh có chữ Tiếng Anh từ thư viện để quét OCR & dịch sang Tiếng Việt
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _isFrozen = true;
        _isTranslating = true;
      });
      await _stopLiveStream();

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final cleaned = recognized.text.replaceAll('\n', ' ').trim();

      if (cleaned.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận diện được văn bản tiếng Anh trong ảnh đã chọn.')),
        );
        setState(() {
          _isTranslating = false;
          _isFrozen = false;
        });
        if (_isAutoLiveScan) await _startLiveStream();
        return;
      }

      setState(() {
        _recognizedEnglishText = cleaned;
      });

      final viResult = await _translatorService.translateEnToVi(cleaned);
      if (!mounted) return;

      setState(() {
        _translatedVietnameseText = viResult;
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
      });
    }
  }

  Future<void> _toggleFreeze() async {
    final nextFrozen = !_isFrozen;
    setState(() {
      _isFrozen = nextFrozen;
    });

    if (nextFrozen) {
      await _stopLiveStream();
    } else if (_isAutoLiveScan) {
      await _startLiveStream();
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final next = !_isFlashOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() {
        _isFlashOn = next;
      });
    } catch (_) {}
  }

  /// Dữ liệu mô phỏng quét nhãn thiết bị Tiếng Anh (dành cho máy ảo Emulator)
  Future<void> _loadDemoCameraScan() async {
    const sampleEnglish =
        'Kids GPS Smart Watch K2 Pro. Waterproof IP67. Press and hold the SOS button for 3 seconds to call parents immediately in case of emergency.';
    setState(() {
      _isFrozen = true;
      _recognizedEnglishText = sampleEnglish;
      _isTranslating = true;
    });
    await _stopLiveStream();

    final vi = await _translatorService.translateEnToVi(sampleEnglish);
    if (!mounted) return;
    setState(() {
      _translatedVietnameseText = vi;
      _isTranslating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Vùng Camera Preview + Khung ngắm dịch thuật AR
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraViewport(),

                // Khung ngắm AR thông minh ở giữa màn hình
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(
                      isScanning: _isAutoLiveScan && !_isFrozen,
                      hasDetectedText: _recognizedEnglishText.isNotEmpty,
                      focusCenterOnly: _focusCenterBoxOnly,
                    ),
                  ),
                ),

                // Thanh trạng thái phía trên Camera
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(165),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isFrozen
                                ? Colors.amber
                                : const Color(0xFF38BDF8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFrozen
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.center_focus_strong_rounded,
                              size: 15,
                              color: _isFrozen ? Colors.amber : const Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isFrozen
                                  ? 'Đã giữ chữ trên màn hình'
                                  : 'Di chuyển Camera vào chữ Tiếng Anh',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Nút đổi chế độ khung ngắm / toàn màn hình
                      InkWell(
                        onTap: () {
                          setState(() {
                            _focusCenterBoxOnly = !_focusCenterBoxOnly;
                          });
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(165),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _focusCenterBoxOnly ? 'Khung ngắm' : 'Toàn màn hình',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _toggleFlash,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _isFlashOn
                                ? Colors.amber.withAlpha(220)
                                : Colors.black.withAlpha(165),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            size: 17,
                            color: _isFlashOn ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Cụm nút điều khiển nhanh dưới đáy Camera
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Chọn ảnh từ thư viện
                      _buildCameraActionChip(
                        icon: Icons.photo_library_rounded,
                        label: 'Thư viện',
                        onTap: _pickImageFromGallery,
                      ),

                      // Nút Chụp & Dịch hoặc Tiếp tục quét
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFrozen
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                        ),
                        icon: Icon(
                          _isFrozen
                              ? Icons.play_arrow_rounded
                              : Icons.camera_enhance_rounded,
                          size: 19,
                        ),
                        label: Text(
                          _isFrozen ? 'Quét tiếp' : 'Giữ / Chụp dịch',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        onPressed: _isFrozen ? _toggleFreeze : _captureAndTranslateSnapshot,
                      ),

                      // Nút Demo (Hữu ích khi chạy máy ảo không có sách tiếng Anh)
                      _buildCameraActionChip(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Thử mẫu',
                        onTap: _loadDemoCameraScan,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Bảng kết quả nhận diện Tiếng Anh -> Dịch Tiếng Việt Realtime
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _recognizedEnglishText.isEmpty
                ? _buildEmptyScanGuide()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dòng tiêu đề Tiếng Anh nhận diện được
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TIẾNG ANH (QUÉT TỪ CAMERA)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Nghe phát âm Tiếng Anh',
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                size: 20,
                                color: Color(0xFF2563EB),
                              ),
                              onPressed: () =>
                                  _translatorService.speakEnglish(_recognizedEnglishText),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Sao chép',
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 17,
                                color: Color(0xFF64748B),
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        '$_recognizedEnglishText\n-> $_translatedVietnameseText',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép văn bản gốc và bản dịch'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(
                          _recognizedEnglishText,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                        const Divider(height: 18),

                        // Dòng kết quả dịch sang Tiếng Việt Realtime
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.translate_rounded,
                                    size: 12,
                                    color: Color(0xFF059669),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'BẢN DỊCH TIẾNG VIỆT REALTIME',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (_isTranslating)
                              const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Đọc bản dịch Tiếng Việt',
                              icon: const Icon(
                                Icons.record_voice_over_rounded,
                                size: 20,
                                color: Color(0xFF059669),
                              ),
                              onPressed: () =>
                                  _translatorService.speakVietnamese(_translatedVietnameseText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _translatedVietnameseText.isEmpty && _isTranslating
                              ? 'Đang dịch sang Tiếng Việt...'
                              : _translatedVietnameseText,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraViewport() {
    if (_isInitializingCamera) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 12),
            Text(
              'Đang khởi động Camera AI nhận diện chữ...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white60, size: 42),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Camera chưa sẵn sàng',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (!_hasPermission)
                  ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Mở cài đặt quyền'),
                  ),
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(170),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanGuide() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF2563EB),
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hướng Camera vào văn bản Tiếng Anh',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Khi bạn di chuyển camera vào vùng có chữ Tiếng Anh (sách hướng dẫn, hộp thiết bị, nhãn cảnh báo...), hệ thống sẽ tự động nhận diện và dịch sang Tiếng Việt ngay lập tức.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final bool isScanning;
  final bool hasDetectedText;
  final bool focusCenterOnly;

  _ScannerOverlayPainter({
    required this.isScanning,
    required this.hasDetectedText,
    required this.focusCenterOnly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!focusCenterOnly) return;

    final boxWidth = size.width * 0.84;
    final boxHeight = size.height * 0.54;
    final left = (size.width - boxWidth) / 2;
    final top = (size.height - boxHeight) / 2;
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(16),
    );

    // Làm tối nhẹ vùng ngoài khung ngắm
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(scanRect);
    final maskPath = Path.combine(PathOperation.difference, bgPath, holePath);

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withAlpha(90),
    );

    // Viền khung ngắm
    final borderColor = hasDetectedText
        ? const Color(0xFF10B981)
        : (isScanning ? const Color(0xFF38BDF8) : Colors.amber);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawRRect(scanRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isScanning != isScanning ||
        oldDelegate.hasDetectedText != hasDetectedText ||
        oldDelegate.focusCenterOnly != focusCenterOnly;
  }
}
