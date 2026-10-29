import 'package:flutter/material.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';

class DeviceAgeRangeField extends StatelessWidget {
  final TextEditingController minAgeController;
  final TextEditingController maxAgeController;

  const DeviceAgeRangeField({
    super.key,
    required this.minAgeController,
    required this.maxAgeController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: minAgeController,
            label: 'Tuổi nhỏ nhất',
            icon: Icons.child_friendly_rounded,
            keyboardType: TextInputType.number,
            validator: (val) => Validators.nonNegativeNumber(val, 'Độ tuổi nhỏ nhất'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppTextField(
            controller: maxAgeController,
            label: 'Tuổi lớn nhất',
            icon: Icons.escalator_warning_rounded,
            keyboardType: TextInputType.number,
            validator: (val) {
              final error = Validators.nonNegativeNumber(val, 'Độ tuổi lớn nhất');
              if (error != null) return error;

              final min = int.tryParse(minAgeController.text) ?? 0;
              final max = int.tryParse(val!) ?? 0;
              if (max < min) {
                return 'Phải >= $min';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
