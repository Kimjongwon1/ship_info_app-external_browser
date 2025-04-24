import 'package:flutter/material.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('채팅하기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            Expanded(child: ChatReceiverWidget()), // 실시간 메시지 표시
            SizedBox(height: 16),
            ChatInputWidget(), // 메시지 전송 입력창
          ],
        ),
      ),
    );
  }
}
