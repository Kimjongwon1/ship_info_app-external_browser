// lib/services/unread_message_manager.dart
import 'package:CHAT_SHIRE/service/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnreadMessageManager {
  static const String _keyPrefix = 'last_read_';
  static const String _batchKeyPrefix = 'batch_last_read_';

  // 🔔 특정 방의 마지막 읽은 메시지 시간 저장
  static Future<void> markAsRead(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('$_keyPrefix$roomId', now);
      print('✅ 방 $roomId 읽음 처리: $now');
    } catch (e) {
      print('❌ 읽음 처리 저장 실패: $e');
    }
  }

  // 🔔 특정 방의 마지막 읽은 시간 가져오기
  static Future<int> getLastReadTime(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_keyPrefix$roomId') ?? 0;
    } catch (e) {
      print('❌ 마지막 읽은 시간 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 안읽은 메시지 개수 계산 (일반 채팅방)
  static Future<int> getUnreadCount(String roomId) async {
    try {
      final lastReadTime = await getLastReadTime(roomId);

      // 서버에서 해당 시간 이후의 메시지 개수를 가져옴
      final count =
          await ChatApiService.getUnreadMessageCount(roomId, lastReadTime);
      return count;
    } catch (e) {
      print('❌ 안읽은 메시지 개수 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 안읽은 메시지 개수 계산 (개인 채팅방)
  static Future<int> getPrivateUnreadCount(String roomId) async {
    try {
      final lastReadTime = await getLastReadTime(roomId);

      // 개인 채팅방 전용 API 호출
      final count = await ChatApiService.getPrivateUnreadMessageCount(
          roomId, lastReadTime);
      return count;
    } catch (e) {
      print('❌ 개인 채팅방 안읽은 메시지 개수 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 마지막 메시지 정보 가져오기 (일반 채팅방)
  static Future<Map<String, dynamic>?> getLastMessage(String roomId) async {
    try {
      return await ChatApiService.getLastMessage(roomId);
    } catch (e) {
      print('❌ 마지막 메시지 조회 실패: $e');
      return null;
    }
  }

  // 🔔 마지막 메시지 정보 가져오기 (개인 채팅방)
  static Future<Map<String, dynamic>?> getPrivateLastMessage(
      String roomId) async {
    try {
      return await ChatApiService.getPrivateLastMessage(roomId);
    } catch (e) {
      print('❌ 개인 채팅방 마지막 메시지 조회 실패: $e');
      return null;
    }
  }

  // 🔔 여러 방의 안읽은 개수 일괄 조회 (성능 최적화)
  static Future<Map<String, int>> getBatchUnreadCounts(
      List<String> roomIds) async {
    try {
      if (roomIds.isEmpty) return {};

      // 각 방의 마지막 읽은 시간 조회
      Map<String, int> lastReadTimes = {};
      for (String roomId in roomIds) {
        lastReadTimes[roomId] = await getLastReadTime(roomId);
      }

      // 서버에서 배치로 안읽은 개수 조회
      final unreadCounts = await ChatApiService.getBatchUnreadCounts(roomIds);

      return unreadCounts;
    } catch (e) {
      print('❌ 배치 안읽은 개수 조회 실패: $e');
      return {};
    }
  }

  // 🔔 시간 포맷팅 유틸리티
  static String formatTime(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.month}/${dateTime.day}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      print('❌ 시간 포맷팅 실패: $e');
      return '';
    }
  }

  // 🔔 메시지 텍스트 정리 (길이 제한 + 특수문자 처리)
  static String cleanMessageText(String message, {int maxLength = 30}) {
    try {
      // 줄바꿈 문자를 공백으로 변경
      String cleaned = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

      // 연속된 공백을 하나로 합치기
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

      // 앞뒤 공백 제거
      cleaned = cleaned.trim();

      // 길이 제한
      if (cleaned.length > maxLength) {
        cleaned = '${cleaned.substring(0, maxLength)}...';
      }

      return cleaned;
    } catch (e) {
      print('❌ 메시지 텍스트 정리 실패: $e');
      return message;
    }
  }

  // 🔔 모든 읽음 상태 초기화 (로그아웃 시 사용)
  static Future<void> clearAllReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // last_read_ 로 시작하는 모든 키 삭제
      for (String key in keys) {
        if (key.startsWith(_keyPrefix) || key.startsWith(_batchKeyPrefix)) {
          await prefs.remove(key);
        }
      }

      print('✅ 모든 읽음 상태 초기화 완료');
    } catch (e) {
      print('❌ 읽음 상태 초기화 실패: $e');
    }
  }

  // 🔔 디버깅용 - 현재 저장된 읽음 상태 출력
  static Future<void> debugPrintReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== 현재 읽음 상태 ===');
      for (String key in keys) {
        if (key.startsWith(_keyPrefix)) {
          final value = prefs.getInt(key);
          final roomId = key.replaceFirst(_keyPrefix, '');
          final dateTime = DateTime.fromMillisecondsSinceEpoch(value ?? 0);
          print('방 $roomId: $dateTime');
        }
      }
      print('====================');
    } catch (e) {
      print('❌ 읽음 상태 디버그 출력 실패: $e');
    }
  }
}
