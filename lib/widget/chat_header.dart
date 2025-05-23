import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';

class ChatHeader extends StatefulWidget {
  final String roomId;
  final bool isPrivate;
  const ChatHeader({super.key, required this.roomId,this.isPrivate = false, });

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  int participantCount = 0;
  String currentUser = '';
  bool subscribed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant ChatHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roomId != oldWidget.roomId) {
      subscribed = false;
      _init(); // 다시 초기화
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    currentUser = prefs.getString('username') ?? 'UnknownUser';

    await _fetchInitialCount();
    await _waitAndSubscribe();
  }

  Future<void> _fetchInitialCount() async {
    try {
      final count =
          await ChatApiService.fetchParticipantCountDirect(widget.roomId);
      if (mounted) {
        setState(() => participantCount = count);
        debugPrint("🔢 초기 참여자 수: $count");
      }
    } catch (e) {
      debugPrint("❌ 초기 참여자 수 가져오기 실패: $e");
    }
  }

  Future<void> _waitAndSubscribe() async {
    int retries = 10;
    while (!stompClient.connected && retries-- > 0) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    if (!stompClient.connected) {
      debugPrint("❌ STOMP 연결 실패 → 참여자 수 구독 못함");
      return;
    }

    debugPrint("📡 STOMP 연결됨 → 참여자 수 구독 시작");

    // ✅ 브로드캐스트용 실시간 구독
    subscribeParticipantCount(widget.roomId, (count) {
      if (mounted) {
        setState(() => participantCount = count);
      }
    });
    // await Future.delayed(const Duration(milliseconds: 200));
    try {
      final count =
          await ChatApiService.fetchParticipantCountDirect(widget.roomId);
      if (mounted) {
        setState(() => participantCount = count);
        debugPrint("🔢 STOMP 연결 이후 초기 참여자 수: $count");
      }
    } catch (e) {
      debugPrint("❌ 참여자 수 조회 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text("👥 현재 참여자: $participantCount명",
          style: const TextStyle(fontSize: 16)),
    );
  }
}
