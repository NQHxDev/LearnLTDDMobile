import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DeviceEmptyView extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String message;

  const DeviceEmptyView({
    super.key,
    this.onRefresh,
    this.message = 'Chưa có thiết bị nào trong danh sách',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.devices_other_rounded,
                size: 54,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tải lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
