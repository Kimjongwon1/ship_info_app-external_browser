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
    try {
      // 🔍 요청할 username 확인
      final response = await http.post(
        Uri.parse('https://f4ab-118-131-64-204.ngrok-free.app/api/login'),
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // 🚀 인증 실패 (아이디/비밀번호 틀림) - false 반환
        print('❌ 인증 실패: ${response.statusCode}');
        return false;
      } else if (response.statusCode >= 500) {
        // 🚀 서버 오류 - 예외 던지기
        throw Exception('서버 내부 오류가 발생했습니다. (${response.statusCode})');
      } else {
        // 🚀 기타 HTTP 오류 - 예외 던지기
        throw Exception('서버 오류가 발생했습니다. (${response.statusCode})');
      }

      return false;
    } on http.ClientException catch (e) {
      // 🚀 네트워크 연결 실패
      print('❌ 네트워크 오류: $e');
      throw Exception('네트워크 연결에 실패했습니다. 인터넷 연결을 확인해주세요.');
    } on FormatException catch (e) {
      // 🚀 JSON 파싱 오류
      print('❌ 데이터 형식 오류: $e');
      throw Exception('서버에서 잘못된 응답을 받았습니다.');
    } catch (e) {
      // 🚀 기타 예외
      print('❌ 예상치 못한 오류: $e');

      // 에러 메시지 분석해서 더 구체적인 예외 던지기
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('socket') ||
          errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('host lookup') ||
          errorString.contains('unreachable')) {
        throw Exception('서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.');
      } else if (errorString.contains('timeout')) {
        throw Exception('서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.');
      } else {
        throw Exception('예상치 못한 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      }
    }
  }
}
