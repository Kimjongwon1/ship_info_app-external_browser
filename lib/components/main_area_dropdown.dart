import 'package:flutter/material.dart';

class MainAreaDropdown extends StatelessWidget {
  final String? selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const MainAreaDropdown({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selected,
      hint: const Text('메인 지역 선택'),
      isExpanded: true,
      items: options.map((area) {
        return DropdownMenuItem<String>(
          value: area,
          child: Text(area),
        );
      }).toList(),
      onChanged: (area) {
        if (area != null) onSelected(area);
      },
    );
  }
}
