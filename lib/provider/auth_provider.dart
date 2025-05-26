import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);

  Future<bool> login(String username, String password) async {
    // 🔍 요청할 username 확인

    final response = await http.post(
      Uri.parse('https://11e7-118-131-64-204.ngrok-free.app/api/login'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8', // 🔧 charset 추가
        'Accept-Charset': 'utf-8', // 🔧 응답 charset 명시
      },
      body: jsonEncode({'username': username, 'password': password}),
    );


    if (response.statusCode == 200) {
      final token =
          response.headers['authorization']?.replaceFirst('Bearer ', '');


      // 🔧 UTF-8로 명시적 디코딩 시도
      String responseBodyUtf8;
      try {
        responseBodyUtf8 = utf8.decode(response.bodyBytes);
      } catch (e) {
        print('❌ UTF-8 디코딩 실패: $e');
        responseBodyUtf8 = response.body; // 원본 사용
      }

      final jsonBody = jsonDecode(responseBodyUtf8);
      final role = jsonBody['role'];
      final responseUsername = jsonBody['username'];
      final userId = jsonBody['id'];


      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', token);

        // 🔧 UTF-8 처리된 username 저장
        await prefs.setString('username', responseUsername);
        await prefs.setString('userId', userId.toString());


        if (role != null) {
          await prefs.setString('role', role);
        }
        state = true;
        return true;
      }
    }

    return false;
  }
}
