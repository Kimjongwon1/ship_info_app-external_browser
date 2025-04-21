import 'package:freezed_annotation/freezed_annotation.dart';

import '../model/ship.dart'; // 실제 모델 경로에 맞게 수정

part 'ship_list_state.freezed.dart';

@freezed
class ShipListState with _$ShipListState {
  const factory ShipListState({
    @Default([]) List<Ship> ships,
    @Default(false) bool isLoading,
  }) = _ShipListState;

  factory ShipListState.initial() => const ShipListState();
}
