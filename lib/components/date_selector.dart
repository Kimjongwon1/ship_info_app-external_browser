import 'package:flutter/material.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPickDate;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "선택된 날짜: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: onPickDate,
          child: const Text("날짜 선택", style: TextStyle(color: Colors.black)),
        )
      ],
    );
  }
}
