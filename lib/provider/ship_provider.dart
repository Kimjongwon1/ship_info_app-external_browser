import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/ship.dart';
import '../service/ship_service.dart';
import '../state/ship_list_state.dart';

class ShipListNotifier extends StateNotifier<ShipListState> {
  ShipListNotifier() : super(ShipListState.initial());

  Future<void> fetchOnly(String regionText) async {
    state = state.copyWith(isLoading: true);
    try {
      final ships = await ShipService.fetchAll(regionText);

      // ✅ 여수처럼 정확한 지역명으로 검색 결과가 있으면 그걸로 사용
      if (ships.isNotEmpty) {
        state = state.copyWith(ships: ships, isLoading: false);
        return;
      }

      // ❗ 검색 결과가 없을 경우 → 대지역 전체 검색 fallback
      final (mainTitle, fullShips) =
          await ShipService.fetchBySubArea(regionText);

      state = state.copyWith(ships: fullShips, isLoading: false);
    } catch (e) {
      debugPrint('❌ fetchOnly 오류: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String?> getAreaMainTitle(String regionText) async {
    try {
      return await ShipService.getMainTitleFromSubArea(regionText);
    } catch (_) {
      return null;
    }
  }

  Future<(String?, List<Ship>)> fetchAllBySubArea(String subAreaText) async {
    state = state.copyWith(isLoading: true);
    try {
      final (title, ships) = await ShipService.fetchBySubArea(subAreaText);
      state = state.copyWith(ships: ships, isLoading: false);
      return (title, ships); // ✅ 반드시 record 타입으로 반환해야 함
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return (null, <Ship>[]); // ✅ 여기도 record 타입 맞춰야 함
    }
  }

  void reset() {
    state = ShipListState.initial();
  }
}

final shipListProvider =
    StateNotifierProvider<ShipListNotifier, ShipListState>((ref) {
  return ShipListNotifier();
});
