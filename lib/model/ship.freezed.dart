// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ship.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Ship _$ShipFromJson(Map<String, dynamic> json) {
  return _Ship.fromJson(json);
}

/// @nodoc
mixin _$Ship {
  int get shipNo => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get areaMain => throw _privateConstructorUsedError;
  String get areaSub => throw _privateConstructorUsedError;
  String get fishType => throw _privateConstructorUsedError;
  int get remain => throw _privateConstructorUsedError;

  /// Serializes this Ship to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Ship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShipCopyWith<Ship> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShipCopyWith<$Res> {
  factory $ShipCopyWith(Ship value, $Res Function(Ship) then) =
      _$ShipCopyWithImpl<$Res, Ship>;
  @useResult
  $Res call(
      {int shipNo,
      String name,
      String areaMain,
      String areaSub,
      String fishType,
      int remain});
}

/// @nodoc
class _$ShipCopyWithImpl<$Res, $Val extends Ship>
    implements $ShipCopyWith<$Res> {
  _$ShipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Ship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shipNo = null,
    Object? name = null,
    Object? areaMain = null,
    Object? areaSub = null,
    Object? fishType = null,
    Object? remain = null,
  }) {
    return _then(_value.copyWith(
      shipNo: null == shipNo
          ? _value.shipNo
          : shipNo // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      areaMain: null == areaMain
          ? _value.areaMain
          : areaMain // ignore: cast_nullable_to_non_nullable
              as String,
      areaSub: null == areaSub
          ? _value.areaSub
          : areaSub // ignore: cast_nullable_to_non_nullable
              as String,
      fishType: null == fishType
          ? _value.fishType
          : fishType // ignore: cast_nullable_to_non_nullable
              as String,
      remain: null == remain
          ? _value.remain
          : remain // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShipImplCopyWith<$Res> implements $ShipCopyWith<$Res> {
  factory _$$ShipImplCopyWith(
          _$ShipImpl value, $Res Function(_$ShipImpl) then) =
      __$$ShipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int shipNo,
      String name,
      String areaMain,
      String areaSub,
      String fishType,
      int remain});
}

/// @nodoc
class __$$ShipImplCopyWithImpl<$Res>
    extends _$ShipCopyWithImpl<$Res, _$ShipImpl>
    implements _$$ShipImplCopyWith<$Res> {
  __$$ShipImplCopyWithImpl(_$ShipImpl _value, $Res Function(_$ShipImpl) _then)
      : super(_value, _then);

  /// Create a copy of Ship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shipNo = null,
    Object? name = null,
    Object? areaMain = null,
    Object? areaSub = null,
    Object? fishType = null,
    Object? remain = null,
  }) {
    return _then(_$ShipImpl(
      shipNo: null == shipNo
          ? _value.shipNo
          : shipNo // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      areaMain: null == areaMain
          ? _value.areaMain
          : areaMain // ignore: cast_nullable_to_non_nullable
              as String,
      areaSub: null == areaSub
          ? _value.areaSub
          : areaSub // ignore: cast_nullable_to_non_nullable
              as String,
      fishType: null == fishType
          ? _value.fishType
          : fishType // ignore: cast_nullable_to_non_nullable
              as String,
      remain: null == remain
          ? _value.remain
          : remain // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShipImpl implements _Ship {
  const _$ShipImpl(
      {required this.shipNo,
      required this.name,
      required this.areaMain,
      required this.areaSub,
      required this.fishType,
      required this.remain});

  factory _$ShipImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShipImplFromJson(json);

  @override
  final int shipNo;
  @override
  final String name;
  @override
  final String areaMain;
  @override
  final String areaSub;
  @override
  final String fishType;
  @override
  final int remain;

  @override
  String toString() {
    return 'Ship(shipNo: $shipNo, name: $name, areaMain: $areaMain, areaSub: $areaSub, fishType: $fishType, remain: $remain)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShipImpl &&
            (identical(other.shipNo, shipNo) || other.shipNo == shipNo) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.areaMain, areaMain) ||
                other.areaMain == areaMain) &&
            (identical(other.areaSub, areaSub) || other.areaSub == areaSub) &&
            (identical(other.fishType, fishType) ||
                other.fishType == fishType) &&
            (identical(other.remain, remain) || other.remain == remain));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, shipNo, name, areaMain, areaSub, fishType, remain);

  /// Create a copy of Ship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShipImplCopyWith<_$ShipImpl> get copyWith =>
      __$$ShipImplCopyWithImpl<_$ShipImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShipImplToJson(
      this,
    );
  }
}

abstract class _Ship implements Ship {
  const factory _Ship(
      {required final int shipNo,
      required final String name,
      required final String areaMain,
      required final String areaSub,
      required final String fishType,
      required final int remain}) = _$ShipImpl;

  factory _Ship.fromJson(Map<String, dynamic> json) = _$ShipImpl.fromJson;

  @override
  int get shipNo;
  @override
  String get name;
  @override
  String get areaMain;
  @override
  String get areaSub;
  @override
  String get fishType;
  @override
  int get remain;

  /// Create a copy of Ship
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShipImplCopyWith<_$ShipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
