import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isInactive;

  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isInactive ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0, // ✅ 그림자 제거
      ),
      child: Text(text),
    );
  }
}
