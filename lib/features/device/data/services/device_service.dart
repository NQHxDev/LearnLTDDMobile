import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/device_model.dart';

class DeviceService {
  final ApiClient apiClient;

  DeviceService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<List<Device>> getDevices({
    int pageNumber = 1,
    int pageSize = 100,
    String? search,
    String? category,
    int? minAge,
    int? maxAge,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    if (category != null && category.trim().isNotEmpty && category != 'Tất cả') {
      queryParameters['category'] = category;
    }

    if (minAge != null) {
      queryParameters['minAge'] = minAge.toString();
    }

    if (maxAge != null) {
      queryParameters['maxAge'] = maxAge.toString();
    }

    final query = Uri(queryParameters: queryParameters).query;
    final response = await apiClient.get(
      '${ApiEndpoints.devices}?$query',
    );

    final data = response['data'];
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Device> getDevice(int id) async {
    final response = await apiClient.get(ApiEndpoints.deviceDetail(id));
    return Device.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Device> createDevice({
    required String name,
    required String description,
    required String category,
    required double price,
    required String brand,
    required String modelNumber,
    required int stockQuantity,
    required int minAge,
    required int maxAge,
    String? imageUrl,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.devices,
      auth: true,
      body: {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'brand': brand,
        'modelNumber': modelNumber,
        'imageUrl': imageUrl,
        'stockQuantity': stockQuantity,
        'minAge': minAge,
        'maxAge': maxAge,
      },
    );

    return Device.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Device> updateDevice({
    required int id,
    required String name,
    required String description,
    required String category,
    required double price,
    required String brand,
    required String modelNumber,
    required int stockQuantity,
    required int minAge,
    required int maxAge,
    String? imageUrl,
    bool? isAvailable,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.deviceDetail(id),
      auth: true,
      body: {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'brand': brand,
        'modelNumber': modelNumber,
        'imageUrl': imageUrl ?? '',
        'stockQuantity': stockQuantity,
        'minAge': minAge,
        'maxAge': maxAge,
        'isAvailable': ?isAvailable,
      },
    );

    return Device.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDevice(int id) async {
    await apiClient.delete(
      ApiEndpoints.deviceDetail(id),
      auth: true,
    );
  }
}
