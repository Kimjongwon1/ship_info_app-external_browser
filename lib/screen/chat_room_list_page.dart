// lib/screen/chat_room_list_page.dart
import 'package:flutter/material.dart';

import '../service/chat_api_service.dart';
import 'chat_page.dart';

class ChatRoomListPage extends StatefulWidget {
  const ChatRoomListPage({super.key});

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  late Future<List<String>> _roomFuture;

  @override
  void initState() {
    super.initState();
    _roomFuture = ChatApiService.fetchRoomList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("💬 채팅방 목록")),
      body: FutureBuilder<List<String>>(
        future: _roomFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("오류: ${snapshot.error}"));
          }

          final rooms = snapshot.data!;
          if (rooms.isEmpty) {
            return const Center(child: Text("⚠️ 채팅방이 없습니다"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final roomId = rooms[index];
              return ListTile(
                leading:
                    const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                title: Text("채팅방 ID: $roomId"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(roomId: roomId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
