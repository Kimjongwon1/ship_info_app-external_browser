import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'util/route_path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt');
  runApp(
    ProviderScope(
      child: MyApp(
        initialRoute: token == null ? RoutePath.login : RoutePath.shipList,
      ),
    ),
  );
}
