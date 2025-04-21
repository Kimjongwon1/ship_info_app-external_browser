import 'package:freezed_annotation/freezed_annotation.dart';

part 'ship.freezed.dart';
part 'ship.g.dart';

@freezed
class Ship with _$Ship {
  const factory Ship({
    required int shipNo,
    required String name,
    required String areaMain,
    required String areaSub,
    required String fishType,
    required int remain,
  }) = _Ship;

  factory Ship.fromJson(Map<String, dynamic> json) => _$ShipFromJson(json);
}
