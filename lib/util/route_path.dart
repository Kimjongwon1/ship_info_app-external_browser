import 'package:flutter/material.dart';

import '../screen/chat_page.dart';
import '../screen/ship_list_page.dart';

class RoutePath {
  static const String shipList = '/ship-list';
  static const String chat = '/chat';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case shipList:
        return MaterialPageRoute(builder: (_) => const ShipListPage());
      case chat:
        return MaterialPageRoute(builder: (_) => const ChatPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }
}
