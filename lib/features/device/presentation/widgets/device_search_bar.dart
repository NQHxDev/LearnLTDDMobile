import 'package:flutter/material.dart';

class DeviceSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback? onClear;

  const DeviceSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm thiết bị...',
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        if (onClear != null) {
                          onClear!();
                        } else {
                          onSearch();
                        }
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSearch,
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }
}
