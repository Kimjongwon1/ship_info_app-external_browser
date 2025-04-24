import 'package:flutter/material.dart';
import 'package:ship_info_app/widget/chat_header.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatelessWidget {
  final String roomId;

  const ChatPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('채팅하기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ChatHeader(roomId: roomId),
            Expanded(child: ChatReceiverWidget(roomId: roomId)), // ✅ 전달
            const SizedBox(height: 16),
            ChatInputWidget(roomId: roomId), // ✅ 전달
          ],
        ),
      ),
    );
  }
}
