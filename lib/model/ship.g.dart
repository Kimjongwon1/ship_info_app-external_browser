// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ship.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShipImpl _$$ShipImplFromJson(Map<String, dynamic> json) => _$ShipImpl(
      shipNo: json['shipNo'] as int,
      name: json['name'] as String,
      areaMain: json['areaMain'] as String,
      areaSub: json['areaSub'] as String,
      fishType: json['fishType'] as String,
      remain: (json['remain'] as num).toInt(),
    );

Map<String, dynamic> _$$ShipImplToJson(_$ShipImpl instance) =>
    <String, dynamic>{
      'shipNo': instance.shipNo,
      'name': instance.name,
      'areaMain': instance.areaMain,
      'areaSub': instance.areaSub,
      'fishType': instance.fishType,
      'remain': instance.remain,
    };
