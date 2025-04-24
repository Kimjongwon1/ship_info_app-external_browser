import 'package:flutter/material.dart';

class SubAreaFilterChips extends StatelessWidget {
  final List<String> subAreas;
  final Set<String> selected;
  final bool allSelected;
  final void Function(bool selectAll) onSelectAll;
  final void Function(String area, bool selected) onToggle;

  const SubAreaFilterChips({
    super.key,
    required this.subAreas,
    required this.selected,
    required this.allSelected,
    required this.onSelectAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (subAreas.length > 1)
          FilterChip(
            label: const Text('하위 전체 선택'),
            selected: allSelected,
            onSelected: (_) => onSelectAll(!allSelected),
          ),
        ...subAreas.map((area) {
          final isSelected = selected.contains(area);
          return FilterChip(
            label: Text(area),
            selected: isSelected,
            onSelected: (v) => onToggle(area, v),
          );
        }),
      ],
    );
  }
}
