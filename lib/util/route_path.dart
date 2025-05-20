import 'package:flutter/material.dart';
import 'package:ship_info_app/screen/auth/login_page.dart';
import 'package:ship_info_app/screen/chat_room_create_page.dart';
import 'package:ship_info_app/screen/chat_room_list_page.dart';

import '../screen/chat_page.dart';
import '../screen/ship_list_page.dart';

class RoutePath {
  static const String shipList = '/ship-list';
  static const String chat = '/chat';
  static const String login = '/login';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case shipList:
        return MaterialPageRoute(builder: (_) => const ShipListPage());
      case chat:
        final args = settings.arguments;
        if (args is Map<String, dynamic> && args['roomId'] != null) {
          final roomId = args['roomId'] as String;
          return MaterialPageRoute(
            builder: (_) => ChatPage(roomId: roomId),
          );
        } else {
          // 방 번호 없이 접근한 경우 에러 처리
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('❌ 채팅방이없습니다')),
            ),
          );
        }
      case '/chat-rooms':
        return MaterialPageRoute(builder: (_) => const ChatRoomListPage());
      case '/create-room':
        return MaterialPageRoute(builder: (_) => const ChatRoomCreatePage());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }
}
