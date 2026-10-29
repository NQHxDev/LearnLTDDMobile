import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../data/services/en_vi_translator_service.dart';

class ConversationTurn {
  final String speaker;
  final String englishText;
  final String vietnameseText;
  final DateTime timestamp;

  const ConversationTurn({
    required this.speaker,
    required this.englishText,
    required this.vietnameseText,
    required this.timestamp,
  });
}

class SampleDialogueScenario {
  final String title;
  final String subtitle;
  final List<Map<String, String>> lines;

  const SampleDialogueScenario({
    required this.title,
    required this.subtitle,
    required this.lines,
  });
}

class VoiceConversationTranslatorTab extends StatefulWidget {
  const VoiceConversationTranslatorTab({super.key});

  @override
  State<VoiceConversationTranslatorTab> createState() =>
      _VoiceConversationTranslatorTabState();
}

class _VoiceConversationTranslatorTabState
    extends State<VoiceConversationTranslatorTab> {
  final SpeechToText _speechToText = SpeechToText();
  final EnViTranslatorService _translatorService = EnViTranslatorService();
  final TextEditingController _manualInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _speechAvailable = false;
  bool _isListening = false;
  final bool _isContinuousMode = true;
  bool _autoSpeakVietnamese = false;
  bool _isPlayingSampleDialogue = false;
  double _soundLevel = 0.0;

  String _livePartialEnglish = '';
  String _livePartialVietnamese = '';
  bool _isTranslatingLive = false;
  Timer? _debounceTimer;
  int _selectedScenarioIndex = 0;

  final List<ConversationTurn> _conversationTurns = [];

  static const List<SampleDialogueScenario> _sampleScenarios = [
    SampleDialogueScenario(
      title: 'Hội thoại Phụ huynh & Giáo viên Tiếng Anh',
      subtitle: 'Trao đổi tình hình học tập và an toàn của bé ở trường',
      lines: [
        {
          'speaker': 'Teacher (GV)',
          'en': 'Good afternoon! Minh An did a wonderful job in English class today.',
        },
        {
          'speaker': 'Parent (PH)',
          'en': 'Thank you teacher! Did he wear his GPS smart watch during outdoor activities?',
        },
        {
          'speaker': 'Teacher (GV)',
          'en': 'Yes, he kept it on all day and knows how to press the SOS button if needed.',
        },
      ],
    ),
    SampleDialogueScenario(
      title: 'Hướng dẫn bé dùng Đồng hồ thông minh',
      subtitle: 'Đoạn hội thoại hướng dẫn kỹ năng an toàn cho trẻ',
      lines: [
        {
          'speaker': 'Mom (Mẹ)',
          'en': 'Sweetie, if you ever get lost at the supermarket, do not panic.',
        },
        {
          'speaker': 'Kid (Bé)',
          'en': 'I will press the red SOS button on my watch to call you right away!',
        },
        {
          'speaker': 'Mom (Mẹ)',
          'en': 'That is right! Your location will be sent to my phone immediately.',
        },
      ],
    ),
    SampleDialogueScenario(
      title: 'Tư vấn Kỹ thuật Thiết bị Trẻ em',
      subtitle: 'Hội thoại kiểm tra pin, chống nước và định vị',
      lines: [
        {
          'speaker': 'Support',
          'en': 'This sleep monitor camera tracks your baby breathing and room temperature in real time.',
        },
        {
          'speaker': 'Parent',
          'en': 'Does it send an alert to my mobile phone when my baby wakes up?',
        },
        {
          'speaker': 'Support',
          'en': 'Yes, you will receive an instant notification with live video and audio.',
        },
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initSpeechRecognizer();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _speechToText.cancel();
    _translatorService.stopSpeaking();
    _manualInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return;
      }

      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: (err) {
          debugPrint('Speech error: ${err.errorMsg}');
          if (mounted) {
            setState(() {
              _isListening = false;
              _soundLevel = 0.0;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('Speech init warning: $e');
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      // Nếu có câu đang nói dở khi kết thúc phiên nghe, lưu vào lịch sử hội thoại
      if (_livePartialEnglish.trim().isNotEmpty) {
        _commitLiveTurnToHistory(
          speaker: 'Mic (Giọng nói EN)',
          english: _livePartialEnglish,
          vietnamese: _livePartialVietnamese,
        );
      }

      if (_isContinuousMode && _isListening && !_isPlayingSampleDialogue) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _isListening) {
            _startListeningSession();
          }
        });
      } else {
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
        });
      }
    }
  }

  Future<void> _toggleMicrophoneListening() async {
    if (_isPlayingSampleDialogue) {
      setState(() {
        _isPlayingSampleDialogue = false;
      });
      await _translatorService.stopSpeaking();
    }

    if (_isListening) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      await _speechToText.stop();
      if (_livePartialEnglish.trim().isNotEmpty) {
        await _commitLiveTurnToHistory(
          speaker: 'Mic (Giọng nói EN)',
          english: _livePartialEnglish,
          vietnamese: _livePartialVietnamese,
        );
      }
      return;
    }

    if (!_speechAvailable) {
      await _initSpeechRecognizer();
    }

    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thiết bị/Máy ảo chưa bật dịch vụ nhận diện giọng nói. Bạn có thể bấm "Phát âm & Dịch Hội thoại mẫu" bên dưới để trải nghiệm realtime!',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _livePartialEnglish = '';
      _livePartialVietnamese = '';
    });

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'en_US',
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 45),
        ),
      );
    } catch (e) {
      debugPrint('Start listen error: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords.trim();
    if (recognizedWords.isEmpty) return;

    setState(() {
      _livePartialEnglish = recognizedWords;
      _isTranslatingLive = true;
    });

    // Dịch realtime ngay khi người nói đang phát âm (Debounce 300ms)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final vi = await _translatorService.translateEnToVi(recognizedWords);
      if (!mounted) return;
      setState(() {
        _livePartialVietnamese = vi;
        _isTranslatingLive = false;
      });

      if (result.finalResult) {
        await _commitLiveTurnToHistory(
          speaker: 'Mic (Giọng nói EN)',
          english: recognizedWords,
          vietnamese: vi,
        );
      }
    });
  }

  Future<void> _commitLiveTurnToHistory({
    required String speaker,
    required String english,
    required String vietnamese,
  }) async {
    final cleanEn = english.trim();
    if (cleanEn.isEmpty) return;

    String cleanVi = vietnamese.trim();
    if (cleanVi.isEmpty) {
      cleanVi = await _translatorService.translateEnToVi(cleanEn);
    }

    if (!mounted) return;

    // Tránh lưu trùng lặp liên tiếp cùng 1 câu
    if (_conversationTurns.isNotEmpty &&
        _conversationTurns.first.englishText.toLowerCase() == cleanEn.toLowerCase()) {
      setState(() {
        _livePartialEnglish = '';
        _livePartialVietnamese = '';
      });
      return;
    }

    setState(() {
      _conversationTurns.insert(
        0,
        ConversationTurn(
          speaker: speaker,
          englishText: cleanEn,
          vietnameseText: cleanVi,
          timestamp: DateTime.now(),
        ),
      );
      _livePartialEnglish = '';
      _livePartialVietnamese = '';
    });

    if (_autoSpeakVietnamese && cleanVi.isNotEmpty) {
      await _translatorService.speakVietnamese(cleanVi);
    }
  }

  /// Phát âm từng câu trong đoạn hội thoại Tiếng Anh và dịch Realtime sang Tiếng Việt
  Future<void> _playAndTranslateSampleDialogue() async {
    if (_isPlayingSampleDialogue) {
      setState(() {
        _isPlayingSampleDialogue = false;
      });
      await _translatorService.stopSpeaking();
      return;
    }

    if (_isListening) {
      setState(() {
        _isListening = false;
      });
      await _speechToText.stop();
    }

    final scenario = _sampleScenarios[_selectedScenarioIndex];
    setState(() {
      _isPlayingSampleDialogue = true;
    });

    for (final line in scenario.lines) {
      if (!mounted || !_isPlayingSampleDialogue) break;

      final speaker = line['speaker'] ?? 'Speaker';
      final fullEn = line['en'] ?? '';
      final words = fullEn.split(' ');

      // Phát âm câu tiếng Anh qua loa thiết bị
      await _translatorService.speakEnglish(fullEn);

      // Mô phỏng luồng nhận diện từng cụm từ khi đang phát âm và dịch realtime sang Tiếng Việt
      final buffer = StringBuffer();
      for (int i = 0; i < words.length; i++) {
        if (!mounted || !_isPlayingSampleDialogue) break;
        if (i > 0) buffer.write(' ');
        buffer.write(words[i]);

        final currentPartial = buffer.toString();
        setState(() {
          _livePartialEnglish = currentPartial;
          _isTranslatingLive = true;
        });

        // Dịch cụm từ realtime sau mỗi 3 từ hoặc từ cuối cùng
        if ((i + 1) % 3 == 0 || i == words.length - 1) {
          final partialVi = await _translatorService.translateEnToVi(currentPartial);
          if (!mounted || !_isPlayingSampleDialogue) break;
          setState(() {
            _livePartialVietnamese = partialVi;
            _isTranslatingLive = false;
          });
        }

        await Future.delayed(const Duration(milliseconds: 220));
      }

      if (!mounted || !_isPlayingSampleDialogue) break;

      final finalVi = await _translatorService.translateEnToVi(fullEn);
      if (!mounted) break;

      await _commitLiveTurnToHistory(
        speaker: speaker,
        english: fullEn,
        vietnamese: finalVi,
      );

      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (mounted) {
      setState(() {
        _isPlayingSampleDialogue = false;
      });
    }
  }

  /// Dịch nhanh câu hội thoại nhập tay & phát âm
  Future<void> _translateAndSpeakManualInput() async {
    final text = _manualInputController.text.trim();
    if (text.isEmpty) return;

    _manualInputController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _livePartialEnglish = text;
      _isTranslatingLive = true;
    });

    await _translatorService.speakEnglish(text);
    final vi = await _translatorService.translateEnToVi(text);
    if (!mounted) return;

    setState(() {
      _livePartialVietnamese = vi;
      _isTranslatingLive = false;
    });

    await _commitLiveTurnToHistory(
      speaker: 'Hội thoại EN',
      english: text,
      vietnamese: vi,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Khung Trạng Thái Nghe / Phát Âm & Dịch Realtime Hiện Tại
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isListening || _isPlayingSampleDialogue
                  ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withAlpha(35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_isListening || _isPlayingSampleDialogue)
                          ? const Color(0xFF10B981).withAlpha(45)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_isListening || _isPlayingSampleDialogue)
                            ? const Color(0xFF34D399)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isListening
                              ? Icons.graphic_eq_rounded
                              : (_isPlayingSampleDialogue
                                  ? Icons.record_voice_over_rounded
                                  : Icons.mic_none_rounded),
                          size: 14,
                          color: (_isListening || _isPlayingSampleDialogue)
                              ? const Color(0xFF34D399)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isListening
                              ? 'ĐANG NGHE TIẾNG ANH REALTIME...'
                              : (_isPlayingSampleDialogue
                                  ? 'ĐANG PHÁT ÂM & DỊCH HỘI THOẠI...'
                                  : 'SẴN SÀNG NGHE HOẶC PHÁT ÂM EN -> VI'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Công tắc tự động đọc Tiếng Việt
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoSpeakVietnamese = !_autoSpeakVietnamese;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _autoSpeakVietnamese
                            ? const Color(0xFF2563EB)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoSpeakVietnamese
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Đọc VI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Câu Tiếng Anh đang được phát âm / nhận diện trực tiếp
              Text(
                _livePartialEnglish.isEmpty
                    ? 'Hãy bấm nút Micro để nói Tiếng Anh hoặc chọn phát âm đoạn hội thoại bên dưới...'
                    : '🇬🇧 "$_livePartialEnglish"',
                style: TextStyle(
                  color: _livePartialEnglish.isEmpty ? Colors.white60 : Colors.white,
                  fontSize: 13.5,
                  fontStyle:
                      _livePartialEnglish.isEmpty ? FontStyle.italic : FontStyle.normal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),

              // Bản dịch Tiếng Việt nhảy chữ theo thời gian thực
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🇻🇳 ', style: TextStyle(fontSize: 15)),
                    Expanded(
                      child: Text(
                        _livePartialVietnamese.isEmpty
                            ? (_isTranslatingLive
                                ? 'Đang dịch sang Tiếng Việt...'
                                : 'Bản dịch Tiếng Việt realtime sẽ hiện ngay tại đây')
                            : _livePartialVietnamese,
                        style: TextStyle(
                          color: _livePartialVietnamese.isEmpty
                              ? Colors.white60
                              : const Color(0xFF6EE7B7),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (_isTranslatingLive)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Thanh chọn Đoạn Hội Thoại Mẫu để Phát âm & Dịch Realtime
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Phát âm từ đoạn hội thoại Tiếng Anh & Dịch Realtime:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlayingSampleDialogue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      _isPlayingSampleDialogue
                          ? Icons.stop_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isPlayingSampleDialogue ? 'Dừng phát' : 'Phát âm & Dịch',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _playAndTranslateSampleDialogue,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_sampleScenarios.length, (index) {
                    final item = _sampleScenarios[index];
                    final isSelected = _selectedScenarioIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (_) {
                          setState(() {
                            _selectedScenarioIndex = index;
                          });
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        // 3. Danh sách Lịch sử Đoạn Hội Thoại Song Ngữ (EN -> VI)
        Expanded(
          child: _conversationTurns.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 42,
                          color: Colors.blueGrey.shade200,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chưa có câu hội thoại nào',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Bấm nút Micro bên dưới để thu âm hội thoại Tiếng Anh hoặc bấm "Phát âm & Dịch" để nghe đoạn hội thoại mẫu và xem dịch sang Tiếng Việt theo thời gian thực.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: _conversationTurns.length,
                  itemBuilder: (context, index) {
                    final turn = _conversationTurns[index];
                    return _buildConversationTurnCard(turn);
                  },
                ),
        ),

        // 4. Thanh điều khiển Micro + Nhập nhanh câu hội thoại Tiếng Anh
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // Ô nhập câu Tiếng Anh để phát âm & dịch
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _translateAndSpeakManualInput(),
                  decoration: InputDecoration(
                    hintText: 'Nhập câu Tiếng Anh để phát âm & dịch...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Phát âm & Dịch sang Tiếng Việt',
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      onPressed: _translateAndSpeakManualInput,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Nút Micro Thu Âm Hội Thoại Realtime
              GestureDetector(
                onTap: _toggleMicrophoneListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF2563EB))
                            .withAlpha(70),
                        blurRadius: _isListening ? 12 + (_soundLevel.abs() * 0.5) : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening ? 'Dừng nghe' : 'Mic EN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
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
    );
  }

  Widget _buildConversationTurnCard(ConversationTurn turn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  turn.speaker,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _translatorService.speakEnglish(turn.englishText),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.volume_up_rounded, size: 15, color: Color(0xFF2563EB)),
                      SizedBox(width: 3),
                      Text(
                        'Phát âm EN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _translatorService.speakVietnamese(turn.vietnameseText),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over_rounded, size: 15, color: Color(0xFF059669)),
                      SizedBox(width: 3),
                      Text(
                        'Đọc VI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '🇬🇧 ${turn.englishText}',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1FAE5)),
            ),
            child: Text(
              '🇻🇳 ${turn.vietnameseText}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
