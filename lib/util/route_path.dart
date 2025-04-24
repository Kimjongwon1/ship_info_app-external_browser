import 'package:flutter/material.dart';
import '../screen/ship_list_page.dart';

class RoutePath {
  static const String shipList = '/ship-list';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case shipList:
        return MaterialPageRoute(builder: (_) => const ShipListPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }
}
