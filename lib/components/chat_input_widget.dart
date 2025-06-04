import 'package:flutter/material.dart';

class ChatInputWidget extends StatelessWidget {
  const ChatInputWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '채팅 메시지 입력',
      ),
      onSubmitted: (value) {
        // Kafka Producer 연동 예정
        print('보낸 메시지: $value');
      },
    );
  }
}
