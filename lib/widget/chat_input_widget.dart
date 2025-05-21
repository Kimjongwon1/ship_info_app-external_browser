import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/chat_stomp_service.dart'; // STOMP 전송 함수 위치

class ChatInputWidget extends StatefulWidget {
  final String roomId; // ✅ roomId 전달받음

  const ChatInputWidget({super.key, required this.roomId});

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _sendStompMessage() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'Unknown';
      sendMessage(username, text, widget.roomId);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: "채팅 메시지 입력",
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _sendStompMessage(),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _sendStompMessage,
          child: const Text("전송"),
        ),
      ],
    );
  }
}
