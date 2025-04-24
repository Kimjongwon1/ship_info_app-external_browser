import 'package:flutter/material.dart';

import '../service/chat_api_service.dart'; // 🔥 히스토리 API
import '../service/chat_stomp_service.dart'; // ✅ STOMP 방식으로 교체
import 'chat_message_widget.dart';

class ChatReceiverWidget extends StatefulWidget {
  const ChatReceiverWidget({super.key});

  @override
  State<ChatReceiverWidget> createState() => _ChatReceiverWidgetState();
}

class _ChatReceiverWidgetState extends State<ChatReceiverWidget> {
  final List<Map<String, dynamic>> messages = [];
  final String currentUser = 'FlutterUser';
  final ScrollController _scrollController =
      ScrollController(); // ✅ 스크롤 컨트롤러 추가

  @override
  void initState() {
    super.initState();
    _loadHistory();

    connectStomp((data) {
      final timestamp = data['timestamp'] ?? DateTime.now().toIso8601String();

      setState(() {
        messages.add({
          'sender': data['sender'],
          'message': data['message'],
          'timestamp': timestamp,
        });
        _sortMessages();
      });

      // ✅ 메시지 추가 후 가장 아래로 점프
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  Future<void> _loadHistory() async {
    final history = await ChatApiService.fetchChatHistory();
    setState(() {
      messages.addAll(history);
      _sortMessages();
    });

    // ✅ 히스토리 불러온 뒤에도 아래로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sortMessages() {
    messages.sort((a, b) => DateTime.parse(a['timestamp'])
        .compareTo(DateTime.parse(b['timestamp'])));
  }

  @override
  void dispose() {
    stompClient.deactivate();
    _scrollController.dispose(); // ✅ 리소스 정리
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController, // ✅ 연결
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final msg = messages[index];
        final isMe = msg['sender'] == currentUser;

        return ChatMessageWidget(
          sender: msg['sender'],
          message: msg['message'],
          timestamp: msg['timestamp'],
          isMe: isMe,
        );
      },
    );
  }
}
