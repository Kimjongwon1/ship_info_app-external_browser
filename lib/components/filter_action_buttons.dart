import 'package:flutter/material.dart';

class FilterActionButtons extends StatelessWidget {
  final VoidCallback onApply;
  final VoidCallback onReset;

  const FilterActionButtons({
    super.key,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onApply,
            child: const Text('필터 적용'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onReset,
          child: const Text('초기화'),
        ),
      ],
    );
  }
}
