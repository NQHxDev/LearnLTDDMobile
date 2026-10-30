import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/appearance_settings_modal.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/device_model.dart';
import '../controllers/device_controller.dart';
import '../widgets/device_card.dart';
import '../widgets/device_empty_view.dart';
import '../widgets/device_search_bar.dart';
import 'device_form_screen.dart';

class DevicesScreen extends StatefulWidget {
  final AuthController authController;

  const DevicesScreen({
    super.key,
    required this.authController,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _deviceController = DeviceController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deviceController.loadDevices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    await _deviceController.loadDevices(
      search: _searchController.text,
    );
  }

  Future<void> _handleEdit(Device device) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormScreen(
          deviceController: _deviceController,
          initialDevice: device,
        ),
      ),
    );

    if (updated == true) {
      _deviceController.loadDevices(
        search: _searchController.text,
      );
    }
  }

  Future<void> _handleDelete(int deviceId, String deviceName) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Xóa thiết bị',
      content: 'Bạn có chắc chắn muốn xóa thiết bị "$deviceName" không?',
      confirmText: 'Xóa',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final deleted = await _deviceController.deleteDevice(deviceId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Đã xóa thiết bị thành công' : 'Xóa thiết bị thất bại',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.authController.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách thiết bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: 'Đổi màu nền Mobile',
            onPressed: () => AppearanceSettingsModal.show(context),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm thiết bị mới',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceFormScreen(
                      deviceController: _deviceController,
                    ),
                  ),
                );

                if (created == true) {
                  _deviceController.loadDevices();
                }
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _deviceController,
        builder: (context, _) {
          if (_deviceController.isLoading && _deviceController.devices.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _deviceController.loadDevices(
              search: _searchController.text,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DeviceSearchBar(
                  controller: _searchController,
                  onSearch: _handleSearch,
                  onClear: () {
                    _searchController.clear();
                    _deviceController.loadDevices();
                  },
                ),
                const SizedBox(height: 16),
                if (_deviceController.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _deviceController.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (_deviceController.devices.isEmpty)
                  DeviceEmptyView(
                    onRefresh: () => _deviceController.loadDevices(
                      search: _searchController.text,
                    ),
                  )
                else
                  ..._deviceController.devices.map(
                    (device) => DeviceCard(
                      device: device,
                      isAdmin: isAdmin,
                      onEdit: isAdmin ? () => _handleEdit(device) : null,
                      onDelete: isAdmin
                          ? () => _handleDelete(device.id, device.name)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
