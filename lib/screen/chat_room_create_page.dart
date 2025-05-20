import 'package:flutter/material.dart';

import '../service/chat_api_service.dart';

class ChatRoomCreatePage extends StatefulWidget {
  const ChatRoomCreatePage({super.key});

  @override
  State<ChatRoomCreatePage> createState() => _ChatRoomCreatePageState();
}

class _ChatRoomCreatePageState extends State<ChatRoomCreatePage> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("방 이름을 입력해주세요")),
      );
      return;
    }

    try {
      await ChatApiService.createRoom(name, password);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🆕 채팅방 생성")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "방 이름"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "비밀번호 (선택)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createRoom,
              child: const Text("방 만들기"),
            ),
          ],
        ),
      ),
    );
  }
}
