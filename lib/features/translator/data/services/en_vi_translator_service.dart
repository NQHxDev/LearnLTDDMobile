import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Dịch vụ dịch thuật Tiếng Anh -> Tiếng Việt theo thời gian thực (Realtime EN -> VI)
/// Kết hợp phát âm Text-To-Speech (TTS) song ngữ cho người dùng Mobile.
class EnViTranslatorService {
  static final EnViTranslatorService _instance = EnViTranslatorService._internal();
  factory EnViTranslatorService() => _instance;
  EnViTranslatorService._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, String> _translationCache = {};
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setErrorHandler((_) {
        _isSpeaking = false;
      });
    } catch (e) {
      debugPrint('TTS Init warning: $e');
    }
  }

  /// Dịch văn bản từ Tiếng Anh (en) sang Tiếng Việt (vi) theo thời gian thực
  Future<String> translateEnToVi(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return '';

    // Kiểm tra bộ nhớ đệm (Cache) để tăng tốc khi quét camera liên tục
    final cacheKey = cleaned.toLowerCase();
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    // 1. Dịch trực tuyến qua Google Translate GTX API (Nhanh < 150ms, chuẩn ngữ cảnh)
    try {
      final encoded = Uri.encodeComponent(cleaned);
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=$encoded',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final buffer = StringBuffer();
          for (final item in decoded[0]) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              buffer.write(item[0].toString());
            }
          }
          final result = buffer.toString().trim();
          if (result.isNotEmpty) {
            _saveToCache(cacheKey, result);
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('Primary translate fallback: $e');
    }

    // 2. Fallback qua MyMemory Translation API
    try {
      final encoded = Uri.encodeComponent(cleaned);
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=$encoded&langpair=en|vi',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final translated = data['responseData']?['translatedText']?.toString().trim();
        if (translated != null && translated.isNotEmpty) {
          _saveToCache(cacheKey, translated);
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Secondary translate fallback: $e');
    }

    // 3. Fallback từ điển Offline cơ bản nếu mất mạng
    final offlineResult = _offlineFallbackTranslate(cleaned);
    return offlineResult;
  }

  void _saveToCache(String key, String value) {
    if (_translationCache.length > 300) {
      _translationCache.remove(_translationCache.keys.first);
    }
    _translationCache[key] = value;
  }

  /// Phát âm câu Tiếng Anh (Hỗ trợ luyện nghe / phát âm hội thoại)
  Future<void> speakEnglish(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.speak(text.trim());
    } catch (e) {
      debugPrint('Speak EN error: $e');
    }
  }

  /// Đọc bản dịch Tiếng Việt
  Future<void> speakVietnamese(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage('vi-VN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text.trim());
    } catch (e) {
      debugPrint('Speak VI error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (_) {}
  }

  String _offlineFallbackTranslate(String input) {
    final lower = input.toLowerCase().trim();
    const Map<String, String> dictionary = {
      'hello': 'Xin chào',
      'good morning': 'Chào buổi sáng',
      'good afternoon': 'Chào buổi chiều',
      'good evening': 'Chào buổi tối',
      'how are you': 'Bạn có khỏe không?',
      'thank you': 'Cảm ơn bạn',
      'warning': 'Cảnh báo',
      'caution': 'Chú ý',
      'keep out of reach of children': 'Để xa tầm tay trẻ em',
      'made in': 'Sản xuất tại',
      'battery': 'Pin',
      'waterproof': 'Chống nước',
      'smart watch': 'Đồng hồ thông minh',
      'user manual': 'Hướng dẫn sử dụng',
      'emergency': 'Khẩn cấp',
      'power on': 'Bật nguồn',
      'power off': 'Tắt nguồn',
      'charging': 'Đang sạc',
      'safe zone': 'Vùng an toàn',
    };

    if (dictionary.containsKey(lower)) {
      return dictionary[lower]!;
    }

    String output = input;
    dictionary.forEach((en, vi) {
      output = output.replaceAll(RegExp(en, caseSensitive: false), vi);
    });
    return output;
  }
}

