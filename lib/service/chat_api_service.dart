import 'dart:convert';

import 'package:CHAT_SHIRE/app.dart';
import 'package:CHAT_SHIRE/model/private_chat_room.dart';
import 'package:CHAT_SHIRE/model/user.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/chat_room.dart';

class ChatApiService {
  static const String baseUrl =
      'https://c341-118-131-64-204.ngrok-free.app/api/chat';
  static const String roomBaseUrl =
      'https://c341-118-131-64-204.ngrok-free.app/api/room';

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

  static Future<List<ChatRoom>> fetchRoomList() async {
    final headers = await _authHeaders();
    final response =
        await http.get(Uri.parse('$roomBaseUrl/list'), headers: headers);
    // print("📦 요청 헤더: $headers");
    // print("🌐 상태코드: ${response.statusCode}");
    print("📄 응답본문: ${response.body}");
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => ChatRoom.fromJson(e)).toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      print("🚫 인증 실패 → 로그인으로 이동");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt');

      MyApp.navigatorKey.currentState?.pushReplacementNamed(RoutePath.login);
      throw Exception('unauthorized');
    } else {
      throw Exception('채팅방 목록 조회 실패');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    final headers = await _authHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/history'), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistoryByRoom(
      String roomId) async {
    final headers = await _authHeaders();
    final response =
        await http.get(Uri.parse('$baseUrl/history/$roomId'), headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chat history by room');
    }
  }

  static Future<int> fetchParticipantCount(String roomId) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$baseUrl/room/$roomId/count');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw Exception("Failed to fetch participant count");
    }
  }

  static Future<void> createRoom(
      String name, String password, String createId) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$roomBaseUrl/create');
    print('🔍 방 생성 요청2 - createId: $createId');
    final response = await http.post(
      url,
      headers: headers,
      body: utf8.encode(jsonEncode(
          {"name": name, "password": password, "createId": createId})),
    );

    if (response.statusCode != 200) {
      throw Exception("채팅방 생성 실패: ${response.body}");
    }
  }

  static Future<void> deleteRoom(int roomId) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$roomBaseUrl/delete/$roomId');
    final response = await http.delete(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception("삭제 실패: ${response.body}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPrivateChatHistoryByRoom(
      String roomId) async {
    final headers = await _authHeaders();

    final response = await http
        .get(Uri.parse('$baseUrl/history/private/$roomId'), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList =
          jsonDecode(utf8.decode(response.bodyBytes));
      return jsonList.cast<Map<String, dynamic>>();
    } else {
      debugPrint('❌ 개인 채팅 히스토리 로드 실패: ${response.statusCode}');
      return [];
    }
  }

  static Future<int> fetchParticipantCountDirect(String roomId) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
        'https://c341-118-131-64-204.ngrok-free.app/api/chat/participants/count?roomId=$roomId');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      debugPrint("❌ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
      return int.parse(response.body);
    } else {
      debugPrint("❌ 서버 응답코드: ${response.statusCode}, 응답본문: ${response.body}");
      throw Exception("Failed to fetch direct participant count");
    }
  }

  static Future<int> createPrivateRoom(
      String name, String password, String createId, String inviteId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(
          'https://c341-118-131-64-204.ngrok-free.app/api/room/private/create'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'password': password,
        'createId': createId,
        'inviteId': inviteId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['roomId']; // 생성된 방 id 리턴
    } else {
      throw Exception('❌ 개인 채팅방 생성 실패: ${response.body}');
    }
  }

  static Future<List<PrivateChatRoom>> fetchPrivateRoomList() async {
    final headers = await _authHeaders();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    print('🧪 userId: $userId');

    final response = await http.get(
      Uri.parse(
          'https://c341-118-131-64-204.ngrok-free.app/api/room/myprivateroom/list?userId=$userId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => PrivateChatRoom.fromJson(e)).toList();
    } else {
      throw Exception('❌ 비공개 채팅방 목록 조회 실패: ${response.statusCode}');
    }
  }

  static Future<List<User>> fetchAllUsers() async {
    final headers = await _authHeaders();
    final response =
        await http.get(Uri.parse('$roomBaseUrl/users'), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception('유저 목록 조회 실패: ${response.statusCode}');
    }
  }
}
