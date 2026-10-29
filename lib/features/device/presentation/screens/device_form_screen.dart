import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/device_model.dart';
import '../controllers/device_controller.dart';
import '../widgets/device_age_range_field.dart';
import '../widgets/device_category_dropdown.dart';

class DeviceFormScreen extends StatefulWidget {
  final DeviceController deviceController;
  final Device? initialDevice;

  const DeviceFormScreen({
    super.key,
    required this.deviceController,
    this.initialDevice,
  });

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minAgeController;
  late final TextEditingController _maxAgeController;
  late final TextEditingController _imageUrlController;

  Device? _editingDevice;
  late String _selectedCategory;
  bool _isAvailable = true;
  bool _loading = false;

  bool get _isEditMode => _editingDevice != null;

  @override
  void initState() {
    super.initState();
    _editingDevice = widget.initialDevice;
    final d = _editingDevice;
    _nameController = TextEditingController(text: d?.name ?? '');
    _descriptionController = TextEditingController(text: d?.description ?? '');
    _brandController = TextEditingController(text: d?.brand ?? '');
    _modelController = TextEditingController(text: d?.modelNumber ?? '');
    _priceController = TextEditingController(
      text: d != null ? d.price.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: d != null ? d.stockQuantity.toString() : '10',
    );
    _minAgeController = TextEditingController(
      text: d != null ? d.minAge.toString() : '3',
    );
    _maxAgeController = TextEditingController(
      text: d != null ? d.maxAge.toString() : '12',
    );
    _imageUrlController = TextEditingController(text: d?.imageUrl ?? '');

    if (d != null && Device.defaultCategories.contains(d.category)) {
      _selectedCategory = d.category;
    } else {
      _selectedCategory = Device.defaultCategories.first;
    }
    _isAvailable = d?.isAvailable ?? true;
  }

  void _populateFromDevice(Device d) {
    setState(() {
      _editingDevice = d;
      _nameController.text = d.name;
      _descriptionController.text = d.description ?? '';
      _brandController.text = d.brand ?? '';
      _modelController.text = d.modelNumber ?? '';
      _priceController.text = d.price.toStringAsFixed(0);
      _stockController.text = d.stockQuantity.toString();
      _minAgeController.text = d.minAge.toString();
      _maxAgeController.text = d.maxAge.toString();
      _imageUrlController.text = d.imageUrl ?? '';
      _selectedCategory = Device.defaultCategories.contains(d.category)
          ? d.category
          : Device.defaultCategories.first;
      _isAvailable = d.isAvailable;
    });
  }

  void _adjustStock(int delta) {
    final current = int.tryParse(_stockController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999999);
    setState(() {
      _stockController.text = next.toString();
      if (next == 0) {
        _isAvailable = false;
      } else if (current == 0 && next > 0) {
        _isAvailable = true;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final brand = _brandController.text.trim();
      final modelNumber = _modelController.text.trim();
      final stockQuantity = int.tryParse(_stockController.text.trim()) ?? 0;
      final minAge = int.tryParse(_minAgeController.text.trim()) ?? 0;
      final maxAge = int.tryParse(_maxAgeController.text.trim()) ?? 0;
      final imageUrl = _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim();

      final bool success;
      if (_isEditMode) {
        success = await widget.deviceController.updateDevice(
          id: _editingDevice!.id,
          name: name,
          description: description,
          category: _selectedCategory,
          price: price,
          brand: brand,
          modelNumber: modelNumber,
          stockQuantity: stockQuantity,
          minAge: minAge,
          maxAge: maxAge,
          imageUrl: imageUrl,
          isAvailable: _isAvailable,
        );
      } else {
        success = await widget.deviceController.createDevice(
          name: name,
          description: description,
          category: _selectedCategory,
          price: price,
          brand: brand,
          modelNumber: modelNumber,
          stockQuantity: stockQuantity,
          minAge: minAge,
          maxAge: maxAge,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              _isEditMode
                  ? 'Đã cập nhật sản phẩm "$name" thành công!'
                  : 'Đã thêm sản phẩm "$name" thành công!',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              widget.deviceController.errorMessage ??
                  (_isEditMode
                      ? 'Cập nhật sản phẩm thất bại'
                      : 'Tạo sản phẩm thất bại'),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDevices = widget.deviceController.devices;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? 'Chỉnh sửa sản phẩm #${_editingDevice!.id}'
              : 'Thêm sản phẩm mới',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode && allDevices.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: allDevices.any((d) => d.id == _editingDevice!.id)
                          ? _editingDevice!.id
                          : null,
                      isExpanded: true,
                      icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                      hint: const Text('Đổi nhanh sản phẩm cần chỉnh sửa'),
                      items: allDevices.map((item) {
                        return DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(
                            'SP #${item.id}: ${item.name} (${item.price.toStringAsFixed(0)} đ)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (selectedId) {
                        if (selectedId == null) return;
                        final target = allDevices.firstWhere(
                          (e) => e.id == selectedId,
                          orElse: () => _editingDevice!,
                        );
                        _populateFromDevice(target);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_isEditMode) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _imageUrlController.text.trim().isEmpty
                            ? const Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 28,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _imageUrlController.text.trim(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.inventory_2_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'MÃ SP: #${_editingDevice!.id}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isAvailable
                                        ? const Color(0xFF10B981).withAlpha(50)
                                        : const Color(0xFFEF4444).withAlpha(50),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _isAvailable ? 'Đang mở bán' : 'Ngừng bán',
                                    style: TextStyle(
                                      color: _isAvailable
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFFFCA5A5),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _nameController.text.isEmpty
                                  ? _editingDevice!.name
                                  : _nameController.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Danh mục: $_selectedCategory • Tồn kho: ${_stockController.text}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                controller: _nameController,
                label: 'Tên sản phẩm / thiết bị',
                icon: Icons.devices_rounded,
                validator: (val) => Validators.required(val, 'tên sản phẩm'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descriptionController,
                label: 'Mô tả chi tiết sản phẩm',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DeviceCategoryDropdown(
                selectedCategory: _selectedCategory,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _priceController,
                label: 'Giá bán (VNĐ)',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                validator: (val) => Validators.nonNegativeNumber(val, 'Giá bán'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _brandController,
                label: 'Thương hiệu (Hãng sản xuất)',
                icon: Icons.branding_watermark_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _modelController,
                label: 'Mã Model sản phẩm',
                icon: Icons.model_training_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _stockController,
                label: 'Số lượng tồn kho',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
                validator: (val) =>
                    Validators.nonNegativeNumber(val, 'Số lượng tồn kho'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Điều chỉnh nhanh kho:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStockQuickBtn('-10', () => _adjustStock(-10)),
                  const SizedBox(width: 6),
                  _buildStockQuickBtn('-1', () => _adjustStock(-1)),
                  const SizedBox(width: 6),
                  _buildStockQuickBtn('+1', () => _adjustStock(1)),
                  const SizedBox(width: 6),
                  _buildStockQuickBtn('+10', () => _adjustStock(10)),
                ],
              ),
              const SizedBox(height: 12),
              DeviceAgeRangeField(
                minAgeController: _minAgeController,
                maxAgeController: _maxAgeController,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _imageUrlController,
                label: 'URL hình ảnh sản phẩm (Tùy chọn)',
                icon: Icons.image_outlined,
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    value: _isAvailable,
                    activeThumbColor: AppColors.primary,
                    title: const Text(
                      'Trạng thái kinh doanh (Mở bán sản phẩm)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      _isAvailable
                          ? 'Đang mở bán trên hệ thống'
                          : 'Tạm ngừng kinh doanh / Ẩn sản phẩm',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isAvailable ? AppColors.success : AppColors.error,
                      ),
                    ),
                    onChanged: (val) => setState(() => _isAvailable = val),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                text: _isEditMode ? 'Lưu cập nhật sản phẩm' : 'Tạo sản phẩm mới',
                loading: _loading,
                icon: _isEditMode ? Icons.check_circle_rounded : Icons.save_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockQuickBtn(String label, VoidCallback onTap) {
    final isPositive = label.startsWith('+');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPositive
              ? AppColors.primary.withAlpha(20)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPositive
                ? AppColors.primary.withAlpha(80)
                : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isPositive ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
