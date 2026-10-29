import 'package:flutter/foundation.dart';
import '../../data/models/device_model.dart';
import '../../data/services/device_service.dart';

class DeviceController extends ChangeNotifier {
  final DeviceService deviceService;

  DeviceController({DeviceService? deviceService})
      : deviceService = deviceService ?? DeviceService();

  List<Device> devices = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadDevices({
    String? search,
    String? category,
    int? minAge,
    int? maxAge,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      devices = await deviceService.getDevices(
        search: search,
        category: category,
        minAge: minAge,
        maxAge: maxAge,
      );
    } catch (e) {
      errorMessage = _cleanError(e.toString());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDevice({
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
    errorMessage = null;
    try {
      final newDevice = await deviceService.createDevice(
        name: name,
        description: description,
        category: category,
        price: price,
        brand: brand,
        modelNumber: modelNumber,
        stockQuantity: stockQuantity,
        minAge: minAge,
        maxAge: maxAge,
        imageUrl: imageUrl,
      );
      devices.insert(0, newDevice);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDevice({
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
    errorMessage = null;
    try {
      final updatedDevice = await deviceService.updateDevice(
        id: id,
        name: name,
        description: description,
        category: category,
        price: price,
        brand: brand,
        modelNumber: modelNumber,
        stockQuantity: stockQuantity,
        minAge: minAge,
        maxAge: maxAge,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );
      final index = devices.indexWhere((device) => device.id == id);
      if (index != -1) {
        devices[index] = updatedDevice;
      } else {
        devices.insert(0, updatedDevice);
      }
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDevice(int id) async {
    errorMessage = null;
    try {
      await deviceService.deleteDevice(id);
      devices.removeWhere((device) => device.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    }
  }

  String _cleanError(String raw) {
    return raw
        .replaceAll('ApiException: ', '')
        .replaceAll('Exception: ', '');
  }
}
