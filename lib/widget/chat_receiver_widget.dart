import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';
import 'chat_message_widget.dart';

class ChatReceiverWidget extends StatefulWidget {
  final String roomId;

  const ChatReceiverWidget({super.key, required this.roomId});

  @override
  State<ChatReceiverWidget> createState() => _ChatReceiverWidgetState();
}

class _ChatReceiverWidgetState extends State<ChatReceiverWidget> {
  final List<Map<String, dynamic>> messages = [];
  String currentUser = '';
  final ScrollController _scrollController = ScrollController();
  bool stompReady = false;

  @override
  void initState() {
    super.initState();
    _initUserAndConnect();
    _loadHistory();
  }

  Future<void> _initUserAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'UnknownUser';
    currentUser = username;

    // 🔍 현재 사용자명 로그
    print('🔍 현재 사용자: $currentUser');

    connectStomp(
      widget.roomId,
      (data) {
        final timestamp = data['timestamp'] ?? DateTime.now().toIso8601String();

        setState(() {
          messages.add({
            'sender': data['sender'],
            'message': data['message'],
            'timestamp': timestamp,
          });
          _sortMessages();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      },
      onConnected: () {
        setState(() => stompReady = true);
        _sendJoinEvent(); // ✅ 연결 후 join 보냄
      },
    );
  }

  void _sendJoinEvent() {
    if (stompClient.connected) {
      // 🔍 하드코딩으로 테스트
      final testUsername = "한글"; // DB에 있는 username 직접 사용

      print('🔍 전송할 username: $testUsername');
      print('🔍 username UTF-8 바이트: ${utf8.encode(testUsername)}');

      stompClient.send(
        destination: '/pub/chat/join',
        body: jsonEncode({
          'roomId': widget.roomId,
          'username': testUsername,
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<void> _loadHistory() async {
    final history = await ChatApiService.fetchChatHistoryByRoom(widget.roomId);
    setState(() {
      messages.addAll(history);
      _sortMessages();
    });

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
    if (stompClient.connected) {
      // 🔧 수정된 sendLeaveEvent 함수 사용 (UTF-8 헤더 포함)
      sendLeaveEvent(widget.roomId, currentUser);
      debugPrint("📤 leave sent: $currentUser → ${widget.roomId}");
    }

    stompClient.deactivate();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!stompReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
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
