import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';

class DeviceCategoryDropdown extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String?> onChanged;
  final List<String> categories;

  const DeviceCategoryDropdown({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
    this.categories = Device.defaultCategories,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Danh mục thiết bị',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: categories
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
