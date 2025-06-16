// lib/services/unread_message_manager.dart
import 'package:CHAT_SHIRE/service/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnreadMessageManager {
  // 🔔 오프라인 캐시용 키 (네트워크 장애 시에만 사용)
  static const String _cachePrefix = 'unread_cache_';

  static String? _currentUserId;

  // 현재 로그인한 사용자 ID 설정
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

  // 🔥 ===== 새로운 DB 기반 메서드들 ===== 🔥

  /// 안읽은 메시지 개수 계산 (개인 채팅방, 서버 DB 기준)
  static Future<int> getPrivateUnreadCount(String roomId,
      {String? userId}) async {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      print('❌ 사용자 ID가 설정되지 않았습니다.');
      return 0;
    }

    try {
      // 🔥 서버에 userId와 roomId만 전달 (DB 기준으로 계산)
      final count = await ChatApiService.getPrivateUnreadMessageCount(
          roomId, userIdToUse);

      // 🔥 결과를 캐시에 저장 (오프라인 대비)
      await _cacheUnreadCount(roomId, userIdToUse, count);

      return count;
    } catch (e) {
      print('❌ 서버에서 안읽은 메시지 개수 조회 실패: $e');

      // 🔥 네트워크 오류 시 캐시에서 읽기
      return await _getCachedUnreadCount(roomId, userIdToUse);
    }
  }

  /// 읽음 처리 (서버 DB에 업데이트)
  static Future<void> markAsRead(String roomId, {String? userId}) async {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      print('❌ 사용자 ID가 설정되지 않았습니다.');
      return;
    }

    try {
      // 🔥 서버에 읽음 처리 알림 (DB 업데이트)
      await ChatApiService.markAsPrivateRead(roomId, userIdToUse);

      // 🔥 성공 시 로컬 캐시도 0으로 설정
      await _cacheUnreadCount(roomId, userIdToUse, 0);

      print('✅ 읽음 처리 완료 - 사용자: $userIdToUse, 방: $roomId');
    } catch (e) {
      print('❌ 읽음 처리 실패: $e');
      // 🔥 실패해도 로컬에서는 읽음으로 표시 (다음 동기화 때 수정됨)
      await _cacheUnreadCount(roomId, userIdToUse, 0);
    }
  }

  /// 마지막 메시지 정보 가져오기 (개인 채팅방)
  static Future<Map<String, dynamic>?> getPrivateLastMessage(
      String roomId) async {
    try {
      return await ChatApiService.getPrivateLastMessage(roomId);
    } catch (e) {
      print('❌ 개인 채팅방 마지막 메시지 조회 실패: $e');
      return null;
    }
  }

  /// 여러 방의 안읽은 개수 일괄 조회 (서버 DB 기준)
  static Future<Map<String, int>> getBatchUnreadCounts(List<String> roomIds,
      {String? userId}) async {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null || roomIds.isEmpty) return {};

    try {
      // 🔥 서버에 배치 요청 (userId 기준)
      final result = await ChatApiService.getBatchPrivateUnreadCounts(
          roomIds, userIdToUse);

      // 🔥 결과를 캐시에 저장
      for (final entry in result.entries) {
        await _cacheUnreadCount(entry.key, userIdToUse, entry.value);
      }

      return result;
    } catch (e) {
      print('❌ 배치 안읽은 개수 조회 실패: $e');

      // 🔥 실패 시 캐시에서 읽기
      Map<String, int> cachedResults = {};
      for (String roomId in roomIds) {
        cachedResults[roomId] =
            await _getCachedUnreadCount(roomId, userIdToUse);
      }
      return cachedResults;
    }
  }

  // 🔔 ===== 호환성을 위한 기존 메서드들 (일반 채팅방용) ===== 🔔

  /// 안읽은 메시지 개수 계산 (일반 채팅방, 기존 방식)
  static Future<int> getUnreadCount(String roomId, {String? userId}) async {
    try {
      final lastReadTime = await getLastReadTime(roomId, userId: userId);
      final count =
          await ChatApiService.getUnreadMessageCount(roomId, lastReadTime);
      return count;
    } catch (e) {
      print('❌ 일반 채팅방 안읽은 메시지 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 마지막 메시지 정보 가져오기 (일반 채팅방)
  static Future<Map<String, dynamic>?> getLastMessage(String roomId) async {
    try {
      return await ChatApiService.getLastMessage(roomId);
    } catch (e) {
      print('❌ 일반 채팅방 마지막 메시지 조회 실패: $e');
      return null;
    }
  }

  /// 특정 방의 마지막 읽은 시간 가져오기 (기존 방식)
  static Future<int> getLastReadTime(String roomId, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _generateKey(roomId, userId);
      final result = prefs.getInt(key) ?? 0;
      return result;
    } catch (e) {
      print('❌ 마지막 읽은 시간 조회 실패: $e');
      return 0;
    }
  }

  // 🔔 ===== 내부 유틸리티 메서드들 ===== 🔔

  /// 오프라인 캐시 저장
  static Future<void> _cacheUnreadCount(
      String roomId, String userId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${userId}_$roomId';
      await prefs.setInt(key, count);
    } catch (e) {
      print('❌ 캐시 저장 실패: $e');
    }
  }

  /// 오프라인 캐시 읽기
  static Future<int> _getCachedUnreadCount(String roomId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${userId}_$roomId';
      final cached = prefs.getInt(key) ?? 0;
      print('📦 캐시에서 안읽은 메시지 개수 조회: $cached');
      return cached;
    } catch (e) {
      print('❌ 캐시 읽기 실패: $e');
      return 0;
    }
  }

  /// 키 생성 함수 (기존 방식용)
  static String _generateKey(String roomId, String? userId) {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      throw Exception('사용자 ID가 설정되지 않았습니다.');
    }
    return 'last_read_${userIdToUse}_$roomId';
  }

  // 🔔 ===== 캐시 및 데이터 관리 ===== 🔔

  /// 캐시 정리 (로그아웃 시)
  static Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith('$_cachePrefix$userId') ||
            key.startsWith('last_read_$userId')) {
          await prefs.remove(key);
        }
      }

      print('✅ 사용자 $userId의 캐시 정리 완료');
    } catch (e) {
      print('❌ 캐시 정리 실패: $e');
    }
  }

  /// 현재 사용자의 캐시 정리
  static Future<void> clearCurrentUserCache() async {
    if (_currentUserId != null) {
      await clearUserCache(_currentUserId!);
    }
  }

  /// 모든 읽음 상태 초기화 (앱 재설치 시 등)
  static Future<void> clearAllReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith('last_read_') || key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }

      print('✅ 모든 읽음 상태 초기화 완료');
    } catch (e) {
      print('❌ 읽음 상태 초기화 실패: $e');
    }
  }

  /// 오래된 읽음 상태 정리 (30일 이상 된 데이터 삭제)
  static Future<void> cleanupOldReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final thirtyDaysAgo =
          DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;

      int cleanedCount = 0;
      for (String key in keys) {
        if (key.startsWith('last_read_') || key.startsWith(_cachePrefix)) {
          final timestamp = prefs.getInt(key) ?? 0;
          if (timestamp > 0 && timestamp < thirtyDaysAgo) {
            await prefs.remove(key);
            cleanedCount++;
          }
        }
      }

      print('✅ 오래된 읽음 상태 정리 완료: $cleanedCount개 삭제');
    } catch (e) {
      print('❌ 오래된 읽음 상태 정리 실패: $e');
    }
  }

  /// 동기화 (앱 시작 시 또는 네트워크 복구 시)
  static Future<void> syncWithServer(List<String> roomIds) async {
    if (_currentUserId == null) return;

    try {
      print('🔄 서버와 동기화 시작...');
      final serverCounts = await getBatchUnreadCounts(roomIds);
      print('✅ 서버와 동기화 완료: ${serverCounts.length}개 방');
    } catch (e) {
      print('❌ 서버와 동기화 실패: $e');
    }
  }

  /// 서버와 로컬 읽음 시간 동기화 (ChatPage용 - 호환성)
  static Future<void> syncReadTimeWithServer(String roomId) async {
    // 🔥 새로운 방식에서는 서버에 읽음 처리만 하면 됨 (DB에서 관리)
    await markAsRead(roomId);
  }

  // 🔔 ===== 유틸리티 함수들 ===== 🔔

  /// 시간 포맷팅 유틸리티
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

  /// 메시지 텍스트 정리 (길이 제한 + 특수문자 처리)
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

  // 🔔 ===== 디버깅용 메서드들 ===== 🔔

  /// 캐시 상태 출력 (디버깅용)
  static Future<void> debugPrintCacheStatus() async {
    if (_currentUserId == null) {
      print('❌ 현재 사용자 ID가 설정되지 않았습니다.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== 캐시 상태 (사용자: $_currentUserId) ===');
      for (String key in keys) {
        if (key.startsWith('$_cachePrefix$_currentUserId')) {
          final value = prefs.getInt(key);
          final roomId = key.replaceFirst('$_cachePrefix$_currentUserId', '');
          print('방 $roomId: $value');
        }
      }
      print('====================');
    } catch (e) {
      print('❌ 캐시 상태 출력 실패: $e');
    }
  }

  /// 읽음 상태 출력 (디버깅용) - 호환성
  static Future<void> debugPrintCurrentUserReadStatus() async {
    await debugPrintCacheStatus();
  }

  /// 모든 읽음 상태 출력 (디버깅용)
  static Future<void> debugPrintAllReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== 모든 읽음 상태 ===');
      for (String key in keys) {
        if (key.startsWith('last_read_') || key.startsWith(_cachePrefix)) {
          final value = prefs.getInt(key);
          print('키: $key, 값: $value');
        }
      }
      print('====================');
    } catch (e) {
      print('❌ 읽음 상태 디버그 출력 실패: $e');
    }
  }

  // 🔔 ===== Deprecated 메서드들 (호환성) ===== 🔔

  @deprecated
  static Future<void> clearUserReadStatus(String userId) async {
    await clearUserCache(userId);
  }

  @deprecated
  static Future<void> clearCurrentUserReadStatus() async {
    await clearCurrentUserCache();
  }

  @deprecated
  static Future<void> debugPrintUserReadStatus(String userId) async {
    print(
        '⚠️ Deprecated method: debugPrintUserReadStatus. Use debugPrintCacheStatus instead.');
    await debugPrintCacheStatus();
  }
}
