import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../model/ship.dart';

class ShipService {
  /// ✅ 정확한 지역 하나만 조회할 때 사용
  static Future<List<Ship>> fetchAll(String regionText) async {
    try {
      final areaRes = await http.get(
        Uri.parse('https://api.sunsang24.com/ship/filter_area/general'),
      );
      final rawAreas = jsonDecode(areaRes.body)['area'] ?? [];

      final List<Map<String, String>> areas = [];

      for (final region in rawAreas) {
        final mainArea =
            region['area']?.toString() ?? region['no']?.toString() ?? '';
        final mainTitle = region['title']?.toString() ?? '';

        areas.add({'area': mainArea, 'area_text': mainTitle});

        final items = region['items'];
        if (items is List) {
          for (final item in items) {
            areas.add({
              'area': item['area']?.toString() ?? item['no']?.toString() ?? '',
              'area_text': item['name']?.toString() ?? '',
            });
          }
        }
      }

      final input = regionText.toLowerCase().replaceAll(' ', '');

      final target = areas.firstWhere(
        (a) {
          final text = a['area_text']?.toLowerCase().replaceAll(' ', '') ?? '';
          return text.contains(input) || input.contains(text);
        },
        orElse: () => {},
      );

      if (target.isEmpty) {
        debugPrint('❗ $regionText 지역 코드 찾을 수 없음');
        return [];
      }

      List<Ship> allShips = [];
      int page = 1;
      while (true) {
        final uri = Uri.parse('https://api.sunsang24.com/ship/list').replace(
          queryParameters: {
            'area': target['area'],
            'area_text': target['area_text'],
            'area_type': 'area',
            'page': page.toString(),
            'type': 'general',
          },
        );

        final res = await http.get(uri);
        final list = jsonDecode(res.body)['list'] ?? [];

        final ships = list
            .where((s) =>
                s['remain_embarkation_num'] != null &&
                s['remain_embarkation_num'] > 0)
            .map<Ship>((s) => Ship.fromJson({
                  'shipNo': s['ship']?['no'] ?? 0,
                  'name': s['ship']?['name'] ?? '이름없음',
                  'areaMain': s['ship']?['area_main'] ?? '지역미정',
                  'areaSub': s['ship']?['area_sub'] ?? '지역미정',
                  'fishType': s['fish_type'] ?? '어종 미상',
                  'remain': s['remain_embarkation_num'],
                }))
            .toList();

        allShips.addAll(ships);
        if (list.length < 20) break;
        page++;
      }

      return allShips;
    } catch (e) {
      debugPrint('❌ fetchAll 오류: $e');
      return [];
    }
  }

  /// ✅ areaSub 기반 → areaMain 전체 지역 선박 목록 가져옴
  static Future<(String?, List<Ship>)> fetchBySubArea(
      String subAreaText) async {
    try {
      final areaRes = await http.get(
        Uri.parse('https://api.sunsang24.com/ship/filter_area/general'),
      );
      final rawAreas = jsonDecode(areaRes.body)['area'] ?? [];

      Map<String, dynamic>? targetRegion;

      for (final region in rawAreas) {
        final title = region['title']?.toString().toLowerCase() ?? '';
        final items = region['items'] as List<dynamic>? ?? [];

        if (title.contains(subAreaText.toLowerCase())) {
          targetRegion = region;
          break;
        }

        for (final item in items) {
          final name = item['name']?.toString().toLowerCase();
          if (name != null && name.contains(subAreaText.toLowerCase())) {
            targetRegion = region;
            break;
          }
        }

        if (targetRegion != null) break;
      }

      if (targetRegion == null) {
        debugPrint('❌ $subAreaText 를 포함하는 지역을 찾을 수 없음');
        return (null, <Ship>[]);
      }

      final areaMainTitle = targetRegion['title']?.toString();
      final subItems = targetRegion['items'] as List<dynamic>? ?? [];

      // ✅ 하위 지역 코드를 하나로 묶어서 API 요청 (area=-A,B,C 형식)
      final areaCodes = subItems
          .map((item) => item['area']?.toString() ?? item['no']?.toString())
          .whereType<String>()
          .toList();

      final joinedAreaCodes = areaCodes.join(',');

      List<Ship> allShips = [];
      int page = 1;
      while (true) {
        final uri = Uri.parse('https://api.sunsang24.com/ship/list').replace(
          queryParameters: {
            'area': '-$joinedAreaCodes',
            'area_text': subItems.first['name']?.toString() ?? '',
            'area_type': 'area',
            'page': page.toString(),
            'type': 'general',
          },
        );

        final res = await http.get(uri);
        final list = jsonDecode(res.body)['list'] ?? [];

        final ships = list
            .where((s) =>
                s['remain_embarkation_num'] != null &&
                s['remain_embarkation_num'] > 0)
            .map<Ship>((s) => Ship.fromJson({
                  'shipNo': s['ship']?['no'] ?? 0,
                  'name': s['ship']?['name'] ?? '이름없음',
                  'areaMain': s['ship']?['area_main'] ?? '지역미정',
                  'areaSub': s['ship']?['area_sub'] ?? '지역미정',
                  'fishType': s['fish_type'] ?? '어종 미상',
                  'remain': s['remain_embarkation_num'],
                }))
            .toList();

        allShips.addAll(ships);
        if (list.length < 20) break;
        page++;
      }

      return (areaMainTitle, allShips);
    } catch (e) {
      debugPrint('❌ fetchBySubArea 오류: $e');
      return (null, <Ship>[]);
    }
  }

  /// ✅ 입력된 지역이 어떤 대지역 title인지 반환만 해줌
  static Future<String?> getMainTitleFromSubArea(String subAreaText) async {
    try {
      final areaRes = await http.get(
        Uri.parse('https://api.sunsang24.com/ship/filter_area/general'),
      );
      final rawAreas = jsonDecode(areaRes.body)['area'] ?? [];

      for (final region in rawAreas) {
        final title = region['title']?.toString().toLowerCase() ?? '';
        final items = region['items'] as List<dynamic>? ?? [];

        if (title.contains(subAreaText.toLowerCase())) {
          return region['title']?.toString();
        }

        for (final item in items) {
          final name = item['name']?.toString().toLowerCase();
          if (name != null && name.contains(subAreaText.toLowerCase())) {
            return region['title']?.toString();
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
