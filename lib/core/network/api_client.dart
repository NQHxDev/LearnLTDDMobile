import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../errors/api_exception.dart';
import '../storage/storage_service.dart';

class ApiClient {
  final StorageService storageService;
  final String baseUrl;
  static String? _workingBaseUrl;

  ApiClient({
    StorageService? storageService,
    String? baseUrl,
  })  : storageService = storageService ?? StorageService(),
        baseUrl = baseUrl ?? AppConstants.baseUrl;

  List<String> get _candidateBaseUrls {
    if (AppConstants.isProduction) {
      final urls = <String>[
        ?_workingBaseUrl,
        baseUrl,
      ];
      return urls.toSet().toList();
    }

    final urls = <String>[
      ?_workingBaseUrl,
      baseUrl,
      ...AppConstants.devFallbackUrls,
    ];
    return urls.toSet().toList();
  }

  Future<Map<String, String>> _headers({bool includeAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await storageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final role = await storageService.getRole();
      if (role != null && role.isNotEmpty) {
        headers['X-User-Role'] = role;
      }

      final userId = await storageService.getUserId();
      if (userId != null) {
        headers['X-User-Id'] = userId.toString();
      }

      final email = await storageService.getEmail();
      if (email != null && email.isNotEmpty) {
        headers['X-User-Name'] = Uri.encodeComponent(email);
      }
    }

    return headers;
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String targetBaseUrl, Map<String, String> headers) requestFn, {
    required bool auth,
  }) async {
    final headers = await _headers(includeAuth: auth);
    final candidates = _candidateBaseUrls;
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isLocalCandidate = candidate.contains('localhost') ||
          candidate.contains('127.0.0.1') ||
          candidate.contains('10.0.2.2') ||
          candidate.contains('192.168.');
      final timeoutDuration = isLocalCandidate && _workingBaseUrl == null
          ? const Duration(seconds: 4)
          : const Duration(seconds: AppConstants.requestTimeoutSeconds);

      try {
        final response = await requestFn(candidate, headers).timeout(timeoutDuration);
        _workingBaseUrl = candidate;
        return response;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError is TimeoutException) {
      throw const ApiException(408, 'Kết nối máy chủ quá hạn (Timeout). Vui lòng kiểm tra Server đang chạy.');
    }
    throw ApiException(503, 'Không thể kết nối tới Server Backend: $lastError');
  }

  Future<dynamic> get(
    String path, {
    bool auth = false,
  }) async {
    final response = await _sendWithFallback(
      (targetBase, headers) => http.get(Uri.parse('$targetBase$path'), headers: headers),
      auth: auth,
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final encodedBody = jsonEncode(body ?? {});
    final response = await _sendWithFallback(
      (targetBase, headers) => http.post(
        Uri.parse('$targetBase$path'),
        headers: headers,
        body: encodedBody,
      ),
      auth: auth,
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final encodedBody = jsonEncode(body ?? {});
    final response = await _sendWithFallback(
      (targetBase, headers) => http.put(
        Uri.parse('$targetBase$path'),
        headers: headers,
        body: encodedBody,
      ),
      auth: auth,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    bool auth = false,
  }) async {
    final response = await _sendWithFallback(
      (targetBase, headers) => http.delete(Uri.parse('$targetBase$path'), headers: headers),
      auth: auth,
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Có lỗi xảy ra';

    if (decoded is Map<String, dynamic>) {
      message = decoded['message'] ?? message;
    }

    if (response.statusCode == 401) {
      message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Phiên đăng nhập đã hết hạn hoặc thông tin xác thực không hợp lệ';
    } else if (response.statusCode == 403) {
      message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Bạn không có quyền thực hiện thao tác này';
    } else if (response.statusCode == 404) {
      message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Không tìm thấy tài nguyên yêu cầu';
    } else if (response.statusCode >= 500) {
      message = 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau';
    }

    throw ApiException(response.statusCode, message);
  }
}
