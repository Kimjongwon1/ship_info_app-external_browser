// lib/services/unread_message_manager.dart
import 'package:CHAT_SHIRE/service/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnreadMessageManager {
  static const String _keyPrefix = 'last_read_';
  static const String _batchKeyPrefix = 'batch_last_read_';

  // 🔑 사용자 ID 저장/조회
  static String? _currentUserId;

  // 현재 로그인한 사용자 ID 설정 (로그인 시 호출)
  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
    print('✅ 현재 사용자 ID 설정: $userId');
  }

  // 앱 시작 시 자동으로 사용자 ID 로드
  static Future<void> loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('userId');
      if (savedUserId != null && savedUserId.isNotEmpty) {
        _currentUserId = savedUserId;
        print('✅ 저장된 사용자 ID 로드: $savedUserId');
      }
    } catch (e) {
      print('❌ 사용자 ID 로드 실패: $e');
    }
  }

  // 현재 사용자 ID 조회
  static String? getCurrentUserId() {
    return _currentUserId;
  }

  // 🔑 키 생성 함수 (userId_roomId 형태)
  static String _generateKey(String roomId, String? userId) {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      throw Exception('사용자 ID가 설정되지 않았습니다. setCurrentUserId()를 먼저 호출하세요.');
    }
    return '$_keyPrefix${userIdToUse}_$roomId';
  }

  // 🔑 배치 키 생성 함수
  static String _generateBatchKey(String roomId, String? userId) {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      throw Exception('사용자 ID가 설정되지 않았습니다.');
    }
    return '$_batchKeyPrefix${userIdToUse}_$roomId';
  }

  // 🔔 특정 방의 마지막 읽은 메시지 시간 저장 (기기별)
  static Future<void> markAsRead(String roomId, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final key = _generateKey(roomId, userId);

      await prefs.setInt(key, now);
      print(
          '✅ 기기별 읽음 처리 - 사용자: ${userId ?? _currentUserId}, 방: $roomId, 시간: $now');
    } catch (e) {
      print('❌ 읽음 처리 저장 실패: $e');
    }
  }

  // 🔔 특정 방의 마지막 읽은 시간 가져오기 (기기별)
  static Future<int> getLastReadTime(String roomId, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _generateKey(roomId, userId);
      final result = prefs.getInt(key) ?? 0;

      print(
          '📖 기기별 읽음 시간 조회 - 사용자: ${userId ?? _currentUserId}, 방: $roomId, 시간: $result');
      return result;
    } catch (e) {
      print('❌ 마지막 읽은 시간 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 안읽은 메시지 개수 계산 (일반 채팅방, 기기별)
  static Future<int> getUnreadCount(String roomId, {String? userId}) async {
    try {
      final lastReadTime = await getLastReadTime(roomId, userId: userId);

      // 서버에서 해당 시간 이후의 메시지 개수를 가져옴
      final count =
          await ChatApiService.getUnreadMessageCount(roomId, lastReadTime);
      return count;
    } catch (e) {
      print('❌ 안읽은 메시지 개수 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 안읽은 메시지 개수 계산 (개인 채팅방, 기기별)
  static Future<int> getPrivateUnreadCount(String roomId,
      {String? userId}) async {
    try {
      final lastReadTime = await getLastReadTime(roomId, userId: userId);

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

  // 🔔 여러 방의 안읽은 개수 일괄 조회 (성능 최적화, 기기별)
  static Future<Map<String, int>> getBatchUnreadCounts(List<String> roomIds,
      {String? userId}) async {
    try {
      if (roomIds.isEmpty) return {};

      // 각 방의 마지막 읽은 시간 조회 (기기별)
      Map<String, int> lastReadTimes = {};
      for (String roomId in roomIds) {
        lastReadTimes[roomId] = await getLastReadTime(roomId, userId: userId);
      }

      // 서버에서 배치로 안읽은 개수 조회
      final unreadCounts = await ChatApiService.getBatchUnreadCounts(roomIds);

      return unreadCounts;
    } catch (e) {
      print('❌ 배치 안읽은 개수 조회 실패: $e');
      return {};
    }
  }

  // 🔔 특정 사용자의 모든 읽음 상태 삭제 (계정 전환 시 사용)
  static Future<void> clearUserReadStatus(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // 해당 사용자의 키만 삭제
      for (String key in keys) {
        if (key.startsWith('$_keyPrefix$userId') ||
            key.startsWith('$_batchKeyPrefix$userId')) {
          await prefs.remove(key);
        }
      }

      print('✅ 사용자 $userId의 읽음 상태 초기화 완료');
    } catch (e) {
      print('❌ 사용자 읽음 상태 초기화 실패: $e');
    }
  }

  // 🔔 현재 사용자의 읽음 상태 초기화 (필요시 사용)
  static Future<void> clearCurrentUserReadStatus() async {
    if (_currentUserId != null) {
      await clearUserReadStatus(_currentUserId!);
    }
  }

  // 🔔 모든 읽음 상태 초기화 (앱 재설치 시 등)
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

  // 🔔 오래된 읽음 상태 정리 (30일 이상 된 데이터 삭제)
  static Future<void> cleanupOldReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final thirtyDaysAgo =
          DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;

      for (String key in keys) {
        if (key.startsWith(_keyPrefix)) {
          final timestamp = prefs.getInt(key) ?? 0;
          if (timestamp > 0 && timestamp < thirtyDaysAgo) {
            await prefs.remove(key);
            print('🗑️ 오래된 읽음 상태 삭제: $key');
          }
        }
      }

      print('✅ 오래된 읽음 상태 정리 완료');
    } catch (e) {
      print('❌ 오래된 읽음 상태 정리 실패: $e');
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

  // 🔔 디버깅용 - 특정 사용자의 읽음 상태 출력
  static Future<void> debugPrintUserReadStatus(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== 사용자 $userId 읽음 상태 ===');
      for (String key in keys) {
        if (key.startsWith('$_keyPrefix$userId')) {
          final value = prefs.getInt(key);
          final roomId = key.replaceFirst('$_keyPrefix$userId', '');
          final dateTime = DateTime.fromMillisecondsSinceEpoch(value ?? 0);
          print('방 $roomId: $dateTime');
        }
      }
      print('====================');
    } catch (e) {
      print('❌ 읽음 상태 디버그 출력 실패: $e');
    }
  }

  // 🔔 디버깅용 - 현재 사용자의 읽음 상태 출력
  static Future<void> debugPrintCurrentUserReadStatus() async {
    if (_currentUserId != null) {
      await debugPrintUserReadStatus(_currentUserId!);
    } else {
      print('❌ 현재 사용자 ID가 설정되지 않았습니다.');
    }
  }

  // 🔔 디버깅용 - 모든 읽음 상태 출력
  static Future<void> debugPrintAllReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== 모든 읽음 상태 ===');
      for (String key in keys) {
        if (key.startsWith(_keyPrefix)) {
          final value = prefs.getInt(key);
          final dateTime = DateTime.fromMillisecondsSinceEpoch(value ?? 0);
          print('키: $key, 시간: $dateTime');
        }
      }
      print('====================');
    } catch (e) {
      print('❌ 읽음 상태 디버그 출력 실패: $e');
    }
  }

  // 🔔 서버와 로컬 읽음 시간 동기화
  static Future<void> syncReadTimeWithServer(String roomId) async {
    try {
      final serverTime = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      final key = _generateKey(roomId, null);

      // 서버 시간으로 강제 업데이트
      await prefs.setInt(key, serverTime);
      print('✅ 서버와 읽음 시간 동기화: $roomId → $serverTime');
    } catch (e) {
      print('❌ 읽음 시간 동기화 실패: $e');
    }
  }
}
