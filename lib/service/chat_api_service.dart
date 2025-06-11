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
  // 🚀 JWT 만료 처리 중복 방지
  static bool _isHandlingJWTExpired = false;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    // print("🪪 SharedPreferences에 저장된 JWT: $token");
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // 🚀 JWT 만료 체크 및 자동 로그아웃 처리 (중복 방지)
  static Future<void> _handleUnauthorized(http.Response response) async {
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        !_isHandlingJWTExpired) {
      _isHandlingJWTExpired = true; // 🚀 중복 처리 방지

      print("🚫 JWT 만료 또는 인증 실패 → 자동 로그아웃");

      // 토큰 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // 또는 특정 키만: await prefs.remove('jwt');

      // 로그인 페이지로 이동
      final context = MyApp.navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RoutePath.login,
          (route) => false,
        );

        // 사용자에게 알림 (한 번만)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 잠시 후 플래그 리셋 (새로운 세션을 위해)
      Future.delayed(const Duration(seconds: 5), () {
        _isHandlingJWTExpired = false;
      });

      throw Exception('JWT expired - redirected to login');
    }
  }

  // 🚀 에러 메시지에서 JWT 만료 체크 (중복 방지)
  static Future<void> _checkJWTExpiredInError(dynamic error) async {
    if (_isHandlingJWTExpired) return; // 🚀 이미 처리 중이면 무시

    final errorString = error.toString();

    if (errorString.contains('JWT expired') ||
        errorString.contains('JWT malformed') ||
        errorString.contains('Unauthorized')) {
      _isHandlingJWTExpired = true; // 🚀 중복 처리 방지

      print("❌ JWT 만료 감지: $errorString");

      // 토큰 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 로그인 페이지로 이동
      final context = MyApp.navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RoutePath.login,
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 잠시 후 플래그 리셋
      Future.delayed(const Duration(seconds: 5), () {
        _isHandlingJWTExpired = false;
      });
    }
  }

  static Future<List<ChatRoom>> fetchRoomList() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(Uri.parse(ApiConfig.getRoomListUrl()),
          headers: headers); // 🚀 전역 설정!
      // print("📦 요청 헤더: $headers");
      // print("🌐 상태코드: ${response.statusCode}");
      print("📄 응답본문: ${response.body}");

      // 🚀 JWT 만료 체크 (기존 코드 유지 + 중복 방지)
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          !_isHandlingJWTExpired) {
        _isHandlingJWTExpired = true;

        print("🚫 인증 실패 → 로그인으로 이동");
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final context = MyApp.navigatorKey.currentContext;
        if (context != null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            RoutePath.login,
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }

        Future.delayed(const Duration(seconds: 5), () {
          _isHandlingJWTExpired = false;
        });

        throw Exception('unauthorized');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => ChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('채팅방 목록 조회 실패');
      }
    } catch (e) {
      // 🚀 에러 메시지에서 JWT 만료 체크
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
          Uri.parse('${ApiConfig.chatBaseUrl}/history'),
          headers: headers); // 🚀 전역 설정!

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load chat history');
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistoryByRoom(
      String roomId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
          Uri.parse(ApiConfig.getChatHistoryUrl(roomId)),
          headers: headers); // 🚀 전역 설정!

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load chat history by room');
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<int> fetchParticipantCount(String roomId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/room/$roomId/count');

      // 🔥 HTTP 클라이언트에 SSL 검증 비활성화 (개발용)
      final client = http.Client();
      final response = await client.get(url, headers: headers).timeout(
            const Duration(seconds: 10), // 타임아웃 추가
          );
      client.close();

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        return int.parse(response.body);
      } else {
        print("❌ 참여자 수 조회 실패: ${response.statusCode}");
        return 0; // 🔥 실패 시 0 반환 (앱이 멈추지 않도록)
      }
    } catch (e) {
      print('❌ 참여자 수 조회 오류 (무시함): $e');
      return 0; // 🔥 오류 시 0 반환
    }
  }

  static Future<void> createRoom(
      String name, String password, String createId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getCreateRoomUrl()); // 🚀 전역 설정!
      print('🔍 방 생성 요청2 - createId: $createId');
      final response = await http.post(
        url,
        headers: headers,
        body: utf8.encode(jsonEncode(
            {"name": name, "password": password, "createId": createId})),
      );

      await _handleUnauthorized(response);

      if (response.statusCode != 200) {
        throw Exception("채팅방 생성 실패: ${response.body}");
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<void> deleteRoom(int roomId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConfig.getDeleteRoomUrl(roomId)); // 🚀 전역 설정!
      final response = await http.delete(url, headers: headers);

      await _handleUnauthorized(response);

      if (response.statusCode != 200) {
        throw Exception("삭제 실패: ${response.body}");
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<void> privatedeleteRoom(int roomId) async {
    try {
      final headers = await _authHeaders();
      final url =
          Uri.parse(ApiConfig.getPrivateDeleteRoomUrl(roomId)); // 🚀 전역 설정!
      final response = await http.delete(url, headers: headers);

      await _handleUnauthorized(response);

      if (response.statusCode != 200) {
        throw Exception("삭제 실패: ${response.body}");
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPrivateChatHistoryByRoom(
      String roomId) async {
    try {
      final headers = await _authHeaders();

      final response = await http.get(
          Uri.parse(ApiConfig.getPrivateChatHistoryUrl(roomId)),
          headers: headers); // 🚀 전역 설정!

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList =
            jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ 개인 채팅 히스토리 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<int> fetchParticipantCountDirect(String roomId) async {
    try {
      final headers = await _authHeaders();
      final url =
          Uri.parse(ApiConfig.getParticipantCountUrl(roomId)); // 🚀 전역 설정!
      final response = await http.get(url, headers: headers);

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        debugPrint("✅ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
        return int.parse(response.body);
      } else {
        debugPrint("❌ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
        throw Exception("Failed to fetch direct participant count");
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<int> createPrivateRoom(
      String name, String password, String createId, String inviteId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.getCreatePrivateRoomUrl()), // 🚀 전역 설정!
        headers: headers,
        body: jsonEncode({
          'name': name,
          'password': password,
          'createId': createId,
          'inviteId': inviteId,
        }),
      );

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['roomId']; // 생성된 방 id 리턴
      } else {
        throw Exception('❌ 개인 채팅방 생성 실패: ${response.body}');
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<List<PrivateChatRoom>> fetchPrivateRoomList() async {
    try {
      final headers = await _authHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      print('🧪 userId: $userId');

      final response = await http.get(
        Uri.parse(ApiConfig.getPrivateRoomListUrl(userId)), // 🚀 전역 설정!
        headers: headers,
      );

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => PrivateChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('❌ 비공개 채팅방 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<List<User>> fetchAllUsers() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(Uri.parse(ApiConfig.getUsersUrl()),
          headers: headers); // 🚀 전역 설정!

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => User.fromJson(e)).toList();
      } else {
        throw Exception('유저 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      rethrow;
    }
  }

  static Future<int> getUnreadMessageCount(
      String roomId, int lastReadTime) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/unread/count?roomId=$roomId&lastReadTime=$lastReadTime');

      final response = await http.get(url, headers: headers);
      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        print('❌ 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 안읽은 메시지 개수 API 오류: $e');
      return 0;
    }
  }

  // 🔔 마지막 메시지 정보 조회
  static Future<Map<String, dynamic>?> getLastMessage(String roomId) async {
    try {
      final headers = await _authHeaders();
      final url =
          Uri.parse('${ApiConfig.chatBaseUrl}/last-message?roomId=$roomId');

      final response = await http.get(url, headers: headers);
      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.isNotEmpty ? data : null;
      } else {
        print('❌ 마지막 메시지 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 마지막 메시지 API 오류: $e');
      return null;
    }
  }

  // 🔔 읽음 처리 API (선택사항 - 서버에서 읽음 상태를 관리하는 경우)
  static Future<bool> markAsRead(String roomId, String userId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/mark-as-read');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
        }),
      );

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        print('✅ 읽음 처리 완료: 방 $roomId');
        return true;
      } else {
        print('❌ 읽음 처리 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 읽음 처리 API 오류: $e');
      return false;
    }
  }

  // 🔔 특정 시간 이후의 안읽은 메시지 개수 (개인 채팅방용)
  static Future<int> getPrivateUnreadMessageCount(
      String roomId, int lastReadTime) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/private/unread/count?roomId=$roomId&lastReadTime=$lastReadTime');

      final response = await http.get(url, headers: headers);
      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        print('❌ 개인 채팅방 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 개인 채팅방 안읽은 메시지 개수 API 오류: $e');
      return 0;
    }
  }

  // 🔔 개인 채팅방 마지막 메시지 조회
  static Future<Map<String, dynamic>?> getPrivateLastMessage(
      String roomId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '${ApiConfig.chatBaseUrl}/private/last-message?roomId=$roomId');

      final response = await http.get(url, headers: headers);
      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.isNotEmpty ? data : null;
      } else {
        print('❌ 개인 채팅방 마지막 메시지 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 개인 채팅방 마지막 메시지 API 오류: $e');
      return null;
    }
  }

  // 🔔 전체 채팅방의 안읽은 메시지 요약 조회 (효율적인 배치 처리)
  static Future<Map<String, int>> getBatchUnreadCounts(
      List<String> roomIds) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConfig.chatBaseUrl}/unread/batch');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'roomIds': roomIds,
        }),
      );

      await _handleUnauthorized(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, int>.from(data['unreadCounts'] ?? {});
      } else {
        print('❌ 배치 안읽은 메시지 개수 조회 실패: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      await _checkJWTExpiredInError(e);
      print('❌ 배치 안읽은 메시지 개수 API 오류: $e');
      return {};
    }
  }
}
