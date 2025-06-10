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
    print(
        "🧪 ChatReceiverWidget init → roomId: ${widget.roomId}, isPrivate: ${widget.isPrivate}");
    _initUserAndConnect();
    _loadHistory();
  }

  Future<void> _initUserAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'UnknownUser';
    currentUser = username;

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

        // ✅ reverse ListView에서는 새 메시지가 맨 위에 추가되므로 스크롤 불필요
        // 필요시에만 맨 위로 스크롤
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      },
      onConnected: () {
        setState(() => stompReady = true);

        if (widget.isPrivate) {
          print("🛑 개인 채팅방 → 참여자 수 구독 생략");
          return;
        }

        _sendJoinEvent();
        subscribeParticipantCount(widget.roomId, (count) {
          debugPrint("👥 참여자 수 업데이트: $count");
        }, isPrivate: widget.isPrivate);
      },
      isPrivate: widget.isPrivate,
    );
  }

  void _sendJoinEvent() {
    if (stompClient.connected) {
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

    // ✅ reverse ListView는 자동으로 아래에서 시작하므로 스크롤 불필요
  }

  void _sortMessages() {
    // ✅ reverse ListView를 위해 최신 메시지부터 정렬 (내림차순)
    messages.sort((a, b) => DateTime.parse(b['timestamp'])
        .compareTo(DateTime.parse(a['timestamp'])));
  }

  // ✅ 맨 아래로 확실히 이동하는 함수
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && messages.isNotEmpty) {
        // 여러 번 시도해서 확실히 맨 아래로 이동
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    if (stompClient.connected) {
      sendLeaveEvent(widget.roomId, currentUser);
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
      reverse: true, // ✅ 리스트를 뒤집어서 최신 메시지가 아래에 오도록
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
