import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/chat_api_service.dart';

class ChatRoomCreatePage extends StatefulWidget {
  const ChatRoomCreatePage({super.key});

  @override
  State<ChatRoomCreatePage> createState() => _ChatRoomCreatePageState();
}

class _ChatRoomCreatePageState extends State<ChatRoomCreatePage> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String createId = ''; // 🔧 변수 선언 추가

  @override
  void initState() {
    super.initState();
    _loadUserId(); // 🔧 initState에서 사용자 ID 로드
  }

  // 🔧 사용자 ID를 로드하는 별도 함수
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      createId = prefs.getString('userId') ?? '';
    });
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("방 이름을 입력해주세요")),
      );
      return;
    }

    if (createId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("사용자 정보를 불러오는 중입니다. 잠시만 기다려주세요.")),
      );
      return;
    }

    try {
      await ChatApiService.createRoom(name, password, createId); // 🔧 세미콜론 수정
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러: $e")),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
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