import 'package:flutter/material.dart';
import '../widgets/camera_ocr_translator_tab.dart';
import '../widgets/voice_conversation_translator_tab.dart';

/// Màn hình / Widget Dịch thuật AI Thông minh dành cho Người dùng (USER) trên Mobile:
/// 1. Quét Camera OCR Realtime (Di chuyển Camera vào chữ Tiếng Anh -> Dịch sang Tiếng Việt)
/// 2. Phát âm & Nghe Hội thoại Realtime (Tiếng Anh -> Tiếng Việt)
class SmartTranslatorScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool isEmbeddedInTab;
  final bool isActiveTab;

  const SmartTranslatorScreen({
    super.key,
    this.initialTabIndex = 0,
    this.isEmbeddedInTab = false,
    this.isActiveTab = true,
  });

  /// Mở trực tiếp màn hình Dịch Camera / Hội thoại toàn màn hình
  static void open(
    BuildContext context, {
    int initialTabIndex = 0,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartTranslatorScreen(
          initialTabIndex: initialTabIndex,
          isEmbeddedInTab: false,
          isActiveTab: true,
        ),
      ),
    );
  }

  @override
  State<SmartTranslatorScreen> createState() => _SmartTranslatorScreenState();
}

class _SmartTranslatorScreenState extends State<SmartTranslatorScreen> {
  late int _selectedMode; // 0: Camera OCR, 1: Hội thoại & Phát âm

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Thanh chuyển đổi 2 chế độ: Dịch Camera OCR & Dịch Hội Thoại Realtime (EN -> VI)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeSegmentButton(
                  index: 0,
                  icon: Icons.camera_alt_rounded,
                  title: 'Camera Dịch Chữ (EN→VI)',
                ),
              ),
              Expanded(
                child: _buildModeSegmentButton(
                  index: 1,
                  icon: Icons.record_voice_over_rounded,
                  title: 'Dịch Hội Thoại & Phát Âm',
                ),
              ),
            ],
          ),
        ),

        // Nội dung chế độ đang chọn
        Expanded(
          child: !widget.isActiveTab
              ? const Center(
                  child: Text('Chuyển sang tab Dịch AI để kích hoạt Camera / Micro'),
                )
              : (_selectedMode == 0
                  ? const CameraOcrTranslatorTab()
                  : const VoiceConversationTranslatorTab()),
        ),
      ],
    );

    if (widget.isEmbeddedInTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trợ Lý Dịch Thuật AI (Anh → Việt)',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            Text(
              'Quét chữ bằng Camera & Dịch hội thoại Realtime trên Mobile',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _buildModeSegmentButton({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withAlpha(45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

