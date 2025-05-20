import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ship_info_app/util/route_path.dart'; // 로그인 경로로 이동할 때 필요
import 'package:ship_info_app/widget/chat_header.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatelessWidget {
  final String roomId;

  const ChatPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅하기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt'); // ✅ JWT 제거
              Navigator.pushReplacementNamed(
                  context, RoutePath.login); // ✅ 로그인으로 이동
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ChatHeader(roomId: roomId),
            Expanded(child: ChatReceiverWidget(roomId: roomId)),
            const SizedBox(height: 16),
            ChatInputWidget(roomId: roomId),
          ],
        ),
      ),
    );
  }
}
