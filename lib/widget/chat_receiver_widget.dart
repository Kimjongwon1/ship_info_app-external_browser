import 'package:flutter/material.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';
import 'chat_message_widget.dart';

class ChatReceiverWidget extends StatefulWidget {
  final String roomId; // ✅ roomId 추가

  const ChatReceiverWidget({super.key, required this.roomId});

  @override
  State<ChatReceiverWidget> createState() => _ChatReceiverWidgetState();
}

class _ChatReceiverWidgetState extends State<ChatReceiverWidget> {
  final List<Map<String, dynamic>> messages = [];
  final String currentUser = 'FlutterUser';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();

    connectStomp(widget.roomId, (data) {
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
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
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
    messages.sort((a, b) =>
        DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
  }

  @override
  void dispose() {
    stompClient.deactivate();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
