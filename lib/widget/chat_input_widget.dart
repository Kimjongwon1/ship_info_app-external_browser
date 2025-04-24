import 'package:flutter/material.dart';

import '../service/chat_stomp_service.dart'; // 여기를 import

class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({super.key});

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();

  void _sendStompMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      sendMessage("FlutterUser", text); // STOMP 방식 전송
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
