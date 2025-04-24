import 'package:flutter/material.dart';

import '../service/chat_stomp_service.dart'; // STOMP 전송 함수 위치

class ChatInputWidget extends StatefulWidget {
  final String roomId; // ✅ roomId 전달받음

  const ChatInputWidget({super.key, required this.roomId});

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();

  void _sendStompMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      sendMessage("FlutterUser", text, widget.roomId); // ✅ roomId 포함해서 전송
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
