import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ship_info_app/app.dart';
import 'package:ship_info_app/util/route_path.dart';

import '../model/chat_room.dart';

class ChatApiService {
  static const String baseUrl = 'https://c095-118-131-64-204.ngrok-free.app/api/chat';
  static const String roomBaseUrl = 'https://c095-118-131-64-204.ngrok-free.app/api/room';

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

  static Future<void> createRoom(String name, String password) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$roomBaseUrl/create');

    final response = await http.post(
      url,
      headers: headers,
      body: utf8.encode(jsonEncode({"name": name, "password": password})),
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
}
