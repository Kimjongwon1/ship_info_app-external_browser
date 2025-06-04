import 'package:CHAT_SHIRE/widget/chat_header.dart';
import 'package:flutter/material.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool isPrivate; // ✅ 개인 채팅 여부

  const ChatPage({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isPrivate = false, // 기본값은 일반 채팅방
  });

  @override
  Widget build(BuildContext context) {
    print('🚪 ChatPage 진입 → roomId: $roomId / isPrivate: $isPrivate');

    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ChatHeader(roomId: roomId, isPrivate: isPrivate), 
            Expanded(
              child: ChatReceiverWidget(
                roomId: roomId,
                isPrivate: isPrivate,
              ),
            ),
            const SizedBox(height: 16),
            ChatInputWidget(
              roomId: roomId,
              isPrivate: isPrivate, 
            ),
          ],
        ),
      ),
    );
  }
}
