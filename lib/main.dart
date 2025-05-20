import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'util/route_path.dart'; // RoutePath.login 등 정의된 곳

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt'); // ✅ 여기서 null이어야 로그인 페이지 감
  runApp(
    ProviderScope(
      child: MyApp(
        initialRoute: token == null ? RoutePath.login : RoutePath.shipList,
      ),
    ),
  );
}
