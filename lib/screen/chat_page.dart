import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ship_info_app/util/route_path.dart'; // 로그인 경로로 이동할 때 필요
import 'package:ship_info_app/widget/chat_header.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatelessWidget {
  final String roomId;
  final String roomName;
  const ChatPage({super.key, required this.roomId, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$roomName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt');
              Navigator.pushReplacementNamed(context, RoutePath.login);
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
