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

      if (ships.isNotEmpty) {
        state = state.copyWith(ships: ships, isLoading: false);
        return;
      }

      final (mainTitle, fullShips) =
          await ShipService.fetchBySubArea(regionText);

      state = state.copyWith(ships: fullShips, isLoading: false);
    } catch (e) {
      debugPrint('❌ fetchOnly 오류: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<List<Ship>> fetchOnlyDirect(String regionText) async {
    return await ShipService.fetchAll(regionText);
  }

  Future<List<Ship>> fetchOnlyDirectWithMain(String subArea, String mainArea) {
    return ShipService.fetchAllWithMain(mainArea, subArea);
  }

  Future<String?> getAreaMainTitle(String regionText) async {
    try {
      return await ShipService.getMainTitleFromSubArea(regionText);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getSubAreasForMain(String mainTitle) async {
    return await ShipService.getSubAreasForMain(mainTitle);
  }

  Future<(String?, List<Ship>)> fetchAllBySubArea(String subAreaText) async {
    state = state.copyWith(isLoading: true);
    try {
      final (title, ships) = await ShipService.fetchBySubArea(subAreaText);
      state = state.copyWith(ships: ships, isLoading: false);
      return (title, ships);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return (null, <Ship>[]);
    }
  }

  void setShipList(List<Ship> ships) {
    state = state.copyWith(ships: ships, isLoading: false);
  }

  void reset() {
    state = state.copyWith(ships: [], isLoading: false);
  }

  Future<List<String>> getAllMainAreas() async {
    try {
      final res = await ShipService.getAllMainAreaTitles();
      return res;
    } catch (_) {
      return [];
    }
  }
}

final shipListProvider =
    StateNotifierProvider<ShipListNotifier, ShipListState>((ref) {
  return ShipListNotifier();
});
