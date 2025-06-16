import 'dart:convert';

import 'package:CHAT_SHIRE/app.dart';
import 'package:CHAT_SHIRE/model/private_chat_room.dart';
import 'package:CHAT_SHIRE/model/user.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
import 'package:chat_config/chat_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/chat_room.dart';

class ChatApiService {
  // 🚀 JWT 만료 처리 중복 방지 및 상태 관리
  static bool _isHandlingJWTExpired = false;
  static DateTime? _lastJWTExpiredTime;
  static const Duration _jwtExpiredCooldown = Duration(seconds: 10);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // 🚀 통합된 JWT 만료 처리 (중복 방지 + 쿨다운)
  static Future<void> _handleJWTExpired([String? additionalInfo]) async {
    final now = DateTime.now();

    // 🔥 이미 처리 중이거나 쿨다운 시간 내라면 무시
    if (_isHandlingJWTExpired ||
        (_lastJWTExpiredTime != null &&
            now.difference(_lastJWTExpiredTime!) < _jwtExpiredCooldown)) {
      print('⏸️ JWT 만료 처리 스킵 (중복 방지): ${additionalInfo ?? ''}');
      return;
    }

    _isHandlingJWTExpired = true;
    _lastJWTExpiredTime = now;

    print("🚫 JWT 만료 처리 시작: ${additionalInfo ?? ''}");

    try {
      // 토큰 및 사용자 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 로그인 페이지로 이동
      final context = MyApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RoutePath.login,
          (route) => false,
        );

        // 사용자 알림 (한 번만)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ JWT 만료 처리 중 오류: $e');
    } finally {
      // 🔥 쿨다운 후 플래그 리셋
      Future.delayed(_jwtExpiredCooldown, () {
        _isHandlingJWTExpired = false;
        print('✅ JWT 만료 처리 플래그 리셋');
      });
    }
  }

  // 🚀 통합된 응답 처리 (JWT 체크 포함)
  static Future<void> _handleResponse(http.Response response,
      [String? apiName]) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _handleJWTExpired('API: ${apiName ?? 'unknown'}');
      throw Exception('JWT expired - redirected to login');
    }
  }

  // 🚀 통합된 예외 처리 (JWT 체크 포함)
  static Future<void> _handleException(dynamic error, [String? apiName]) async {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('jwt expired') ||
        errorString.contains('jwt malformed') ||
        errorString.contains('unauthorized') ||
        errorString.contains('403') ||
        errorString.contains('401')) {
      await _handleJWTExpired(
          'Exception in ${apiName ?? 'unknown'}: $errorString');
    }
  }

  // 🚀 API 래퍼 함수 - 모든 API 호출에 공통 처리 적용
  static Future<T> _apiCall<T>(
    String apiName,
    Future<T> Function() apiFunction,
  ) async {
    try {
      return await apiFunction();
    } catch (e) {
      await _handleException(e, apiName);
      rethrow;
    }
  }

  // 🔔 ===== 기본 채팅 API들 ===== 🔔

  static Future<List<ChatRoom>> fetchRoomList() async {
    return _apiCall('fetchRoomList', () async {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getRoomListUrl()),
        headers: headers,
      );

      await _handleResponse(response, 'fetchRoomList');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => ChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('채팅방 목록 조회 실패: ${response.statusCode}');
      }
    });
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    return _apiCall('fetchChatHistory', () async {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.chatBaseUrl}/history'),
        headers: headers,
      );

      await _handleResponse(response, 'fetchChatHistory');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load chat history: ${response.statusCode}');
      }
    });
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistoryByRoom(
      String roomId) async {
    return _apiCall('fetchChatHistoryByRoom', () async {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getChatHistoryUrl(roomId)),
        headers: headers,
      );

      await _handleResponse(response, 'fetchChatHistoryByRoom');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to load chat history by room: ${response.statusCode}');
      }
    });
  }

  static Future<int> fetchParticipantCount(String roomId) async {
    return _apiCall('fetchParticipantCount', () async {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/room/$roomId/count');

      final client = http.Client();
      try {
        final response = await client.get(url, headers: headers).timeout(
              const Duration(seconds: 10),
            );

        await _handleResponse(response, 'fetchParticipantCount');

        if (response.statusCode == 200) {
          return int.parse(response.body);
        } else {
          print("❌ 참여자 수 조회 실패: ${response.statusCode}");
          return 0;
        }
      } finally {
        client.close();
      }
    });
  }

  static Future<void> createRoom(
      String name, String password, String createId) async {
    return _apiCall('createRoom', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getCreateRoomUrl());

      final response = await http.post(
        url,
        headers: headers,
        body: utf8.encode(jsonEncode(
            {"name": name, "password": password, "createId": createId})),
      );

      await _handleResponse(response, 'createRoom');

      if (response.statusCode != 200) {
        throw Exception("채팅방 생성 실패: ${response.body}");
      }
    });
  }

  static Future<void> deleteRoom(int roomId) async {
    return _apiCall('deleteRoom', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getDeleteRoomUrl(roomId));
      final response = await http.delete(url, headers: headers);

      await _handleResponse(response, 'deleteRoom');

      if (response.statusCode != 200) {
        throw Exception("삭제 실패: ${response.body}");
      }
    });
  }

  static Future<void> privatedeleteRoom(int roomId) async {
    return _apiCall('privatedeleteRoom', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getPrivateDeleteRoomUrl(roomId));
      final response = await http.delete(url, headers: headers);

      await _handleResponse(response, 'privatedeleteRoom');

      if (response.statusCode != 200) {
        throw Exception("삭제 실패: ${response.body}");
      }
    });
  }

  static Future<List<Map<String, dynamic>>> fetchPrivateChatHistoryByRoom(
      String roomId) async {
    return _apiCall('fetchPrivateChatHistoryByRoom', () async {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getPrivateChatHistoryUrl(roomId)),
        headers: headers,
      );

      await _handleResponse(response, 'fetchPrivateChatHistoryByRoom');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList =
            jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ 개인 채팅 히스토리 로드 실패: ${response.statusCode}');
        return [];
      }
    });
  }

  static Future<int> fetchParticipantCountDirect(String roomId) async {
    return _apiCall('fetchParticipantCountDirect', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getParticipantCountUrl(roomId));
      final response = await http.get(url, headers: headers);

      await _handleResponse(response, 'fetchParticipantCountDirect');

      if (response.statusCode == 200) {
        debugPrint("✅ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
        return int.parse(response.body);
      } else {
        debugPrint("❌ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
        throw Exception(
            "Failed to fetch direct participant count: ${response.statusCode}");
      }
    });
  }

  static Future<int> createPrivateRoom(
      String name, String password, String createId, String inviteId) async {
    return _apiCall('createPrivateRoom', () async {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.getCreatePrivateRoomUrl()),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'password': password,
          'createId': createId,
          'inviteId': inviteId,
        }),
      );

      await _handleResponse(response, 'createPrivateRoom');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['roomId'];
      } else {
        throw Exception('❌ 개인 채팅방 생성 실패: ${response.body}');
      }
    });
  }

  static Future<List<PrivateChatRoom>> fetchPrivateRoomList() async {
    return _apiCall('fetchPrivateRoomList', () async {
      final headers = await _authHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final response = await http.get(
        Uri.parse(ApiConfig.getPrivateRoomListUrl(userId)),
        headers: headers,
      );

      await _handleResponse(response, 'fetchPrivateRoomList');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => PrivateChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('❌ 비공개 채팅방 목록 조회 실패: ${response.statusCode}');
      }
    });
  }

  static Future<List<User>> fetchAllUsers() async {
    return _apiCall('fetchAllUsers', () async {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getUsersUrl()),
        headers: headers,
      );

      await _handleResponse(response, 'fetchAllUsers');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => User.fromJson(e)).toList();
      } else {
        throw Exception('유저 목록 조회 실패: ${response.statusCode}');
      }
    });
  }

  // 🔥 ===== 개인 채팅방 안읽은 메시지 관리 (DB 기반) ===== 🔥

  /// 개인 채팅방 안읽은 메시지 개수 (서버 DB 기준)
  static Future<int> getPrivateUnreadMessageCount(
      String roomId, String userId) async {
    return _apiCall('getPrivateUnreadMessageCount', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/private/unread/count?roomId=$roomId&userId=$userId');

      final response = await http.get(url, headers: headers);
      await _handleResponse(response, 'getPrivateUnreadMessageCount');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        print('❌ 개인 채팅방 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return 0;
      }
    });
  }

  /// 개인 채팅방 읽음 처리 API (서버 DB 업데이트)
  static Future<bool> markAsPrivateRead(String roomId, String userId) async {
    return _apiCall('markAsPrivateRead', () async {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/private/mark-as-read');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
        }),
      );

      await _handleResponse(response, 'markAsPrivateRead');

      if (response.statusCode == 200) {
        print('✅ 서버 읽음 처리 완료: 방 $roomId, 사용자 $userId');
        return true;
      } else {
        print('❌ 서버 읽음 처리 실패: ${response.statusCode}');
        return false;
      }
    });
  }

  /// 개인 채팅방 마지막 메시지 조회
  static Future<Map<String, dynamic>?> getPrivateLastMessage(
      String roomId) async {
    return _apiCall('getPrivateLastMessage', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/private/last-message?roomId=$roomId');

      final response = await http.get(url, headers: headers);
      await _handleResponse(response, 'getPrivateLastMessage');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.isNotEmpty ? data : null;
      } else {
        print('❌ 개인 채팅방 마지막 메시지 조회 실패: ${response.statusCode}');
        return null;
      }
    });
  }

  /// 개인 채팅방 배치 안읽은 메시지 개수 조회 (서버 DB 기준)
  static Future<Map<String, int>> getBatchPrivateUnreadCounts(
      List<String> roomIds, String userId) async {
    return _apiCall('getBatchPrivateUnreadCounts', () async {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/private/unread/batch');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'roomIds': roomIds,
          'userId': userId,
        }),
      );

      await _handleResponse(response, 'getBatchPrivateUnreadCounts');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, int>.from(data['unreadCounts'] ?? {});
      } else {
        print('❌ 배치 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return {};
      }
    });
  }

  // 🔔 ===== 일반 채팅방 메서드들 (기존 방식 유지) ===== 🔔

  static Future<int> getUnreadMessageCount(
      String roomId, int lastReadTime) async {
    return _apiCall('getUnreadMessageCount', () async {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/unread/count?roomId=$roomId&lastReadTime=$lastReadTime');

      final response = await http.get(url, headers: headers);
      await _handleResponse(response, 'getUnreadMessageCount');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        print('❌ 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return 0;
      }
    });
  }

  static Future<Map<String, dynamic>?> getLastMessage(String roomId) async {
    return _apiCall('getLastMessage', () async {
      final headers = await _authHeaders();
      final url =
          Uri.parse('${ApiConfig.chatBaseUrl}/last-message?roomId=$roomId');

      final response = await http.get(url, headers: headers);
      await _handleResponse(response, 'getLastMessage');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.isNotEmpty ? data : null;
      } else {
        print('❌ 마지막 메시지 조회 실패: ${response.statusCode}');
        return null;
      }
    });
  }

  static Future<Map<String, int>> getBatchUnreadCounts(
      List<String> roomIds) async {
    return _apiCall('getBatchUnreadCounts', () async {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/unread/batch');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'roomIds': roomIds,
        }),
      );

      await _handleResponse(response, 'getBatchUnreadCounts');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, int>.from(data['unreadCounts'] ?? {});
      } else {
        print('❌ 배치 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return {};
      }
    });
  }

  // 🔔 ===== 기존 메서드들 (Deprecated) ===== 🔔

  @deprecated
  static Future<bool> markAsprivateRead(String roomId, String userId) async {
    // 새 메서드 사용: markAsPrivateRead
    return markAsPrivateRead(roomId, userId);
  }

  @deprecated
  static Future<int> getPrivateUnreadMessageCount_OLD(
      String roomId, int lastReadTime) async {
    // 이 메서드는 더 이상 사용하지 않음
    // 새 메서드 사용: getPrivateUnreadMessageCount(roomId, userId)
    print('⚠️ Deprecated method called: getPrivateUnreadMessageCount_OLD');
    return 0;
  }

  // 🔥 JWT 만료 상태 리셋 (테스트용)
  static void resetJWTExpiredState() {
    _isHandlingJWTExpired = false;
    _lastJWTExpiredTime = null;
    print('🔄 JWT 만료 상태 리셋');
  }
}
