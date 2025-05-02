import 'package:flutter/material.dart';

class Toast {
  static void show(BuildContext context, String text,
      {Duration duration = const Duration(seconds: 2)}) {
    final overlay = Overlay.of(context, rootOverlay: true);

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(duration, () => entry.remove());
  }
}
