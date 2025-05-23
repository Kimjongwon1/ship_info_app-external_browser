import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';
import 'chat_message_widget.dart';

class ChatReceiverWidget extends StatefulWidget {
  final String roomId;
  final bool isPrivate;
  const ChatReceiverWidget({
    super.key,
    required this.roomId,
    this.isPrivate = false,
  });

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

    // 🔍 현재 사용자명 확인 (정상 동작 확인용 - 나중에 제거 가능)
    // print('🔍 현재 사용자: $currentUser');

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
        if (!widget.isPrivate) {
          _sendJoinEvent(); // 공개방일 때만
          subscribeParticipantCount(widget.roomId, (count) {
            debugPrint("👥 참여자 수 업데이트: $count");
          });
        }
      },
    );
  }

  void _sendJoinEvent() {
    if (stompClient.connected) {
      // ✅ SharedPreferences에서 가져온 currentUser 그대로 사용
      sendJoinEvent(widget.roomId, currentUser);
      debugPrint("📥 join sent: $currentUser → ${widget.roomId}");
    }
  }

  Future<void> _loadHistory() async {
    final history = widget.isPrivate
        ? await ChatApiService.fetchPrivateChatHistoryByRoom(widget.roomId)
        : await ChatApiService.fetchChatHistoryByRoom(widget.roomId);

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
      // ✅ SharedPreferences에서 가져온 currentUser 그대로 사용
      sendLeaveEvent(widget.roomId, currentUser);
      // debugPrint("📤 leave sent: $currentUser → ${widget.roomId}");
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
