// lib/widget/chat_input_widget.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({super.key});

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();

  Future<void> sendMessage() async {
    final url =
        Uri.parse('http://10.0.2.2:8080/api/chat/send'); // ❗ PC에서 실제 IP로 바꿔야 함
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender": "FlutterUser",
        "message": _controller.text,
      }),
    );

    print("응답: ${response.body}");
    _controller.clear();
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
          onPressed: sendMessage,
          child: const Text("Kafka로 전송"),
        ),
      ],
    );
  }
}
