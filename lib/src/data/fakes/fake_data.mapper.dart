// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'fake_data.dart';

class FakeSyncEntityMapper extends ClassMapperBase<FakeSyncEntity> {
  FakeSyncEntityMapper._();

  static FakeSyncEntityMapper? _instance;
  static FakeSyncEntityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FakeSyncEntityMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'FakeSyncEntity';

  static String _$id(FakeSyncEntity v) => v.id;
  static const Field<FakeSyncEntity, String> _f$id = Field('id', _$id);
  static String _$message(FakeSyncEntity v) => v.message;
  static const Field<FakeSyncEntity, String> _f$message =
      Field('message', _$message);
  static DateTime _$createdAt(FakeSyncEntity v) => v.createdAt;
  static const Field<FakeSyncEntity, DateTime> _f$createdAt =
      Field('createdAt', _$createdAt, opt: true);
  static DateTime _$updatedAt(FakeSyncEntity v) => v.updatedAt;
  static const Field<FakeSyncEntity, DateTime> _f$updatedAt =
      Field('updatedAt', _$updatedAt, opt: true);

  @override
  final MappableFields<FakeSyncEntity> fields = const {
    #id: _f$id,
    #message: _f$message,
    #createdAt: _f$createdAt,
    #updatedAt: _f$updatedAt,
  };

  static FakeSyncEntity _instantiate(DecodingData data) {
    return FakeSyncEntity(
        id: data.dec(_f$id),
        message: data.dec(_f$message),
        createdAt: data.dec(_f$createdAt),
        updatedAt: data.dec(_f$updatedAt));
  }

  @override
  final Function instantiate = _instantiate;

  static FakeSyncEntity fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FakeSyncEntity>(map);
  }

  static FakeSyncEntity fromJson(String json) {
    return ensureInitialized().decodeJson<FakeSyncEntity>(json);
  }
}

mixin FakeSyncEntityMappable {
  String toJson() {
    return FakeSyncEntityMapper.ensureInitialized()
        .encodeJson<FakeSyncEntity>(this as FakeSyncEntity);
  }

  Map<String, dynamic> toMap() {
    return FakeSyncEntityMapper.ensureInitialized()
        .encodeMap<FakeSyncEntity>(this as FakeSyncEntity);
  }

  FakeSyncEntityCopyWith<FakeSyncEntity, FakeSyncEntity, FakeSyncEntity>
      get copyWith => _FakeSyncEntityCopyWithImpl(
          this as FakeSyncEntity, $identity, $identity);
  @override
  String toString() {
    return FakeSyncEntityMapper.ensureInitialized()
        .stringifyValue(this as FakeSyncEntity);
  }

  @override
  bool operator ==(Object other) {
    return FakeSyncEntityMapper.ensureInitialized()
        .equalsValue(this as FakeSyncEntity, other);
  }

  @override
  int get hashCode {
    return FakeSyncEntityMapper.ensureInitialized()
        .hashValue(this as FakeSyncEntity);
  }
}

extension FakeSyncEntityValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FakeSyncEntity, $Out> {
  FakeSyncEntityCopyWith<$R, FakeSyncEntity, $Out> get $asFakeSyncEntity =>
      $base.as((v, t, t2) => _FakeSyncEntityCopyWithImpl(v, t, t2));
}

abstract class FakeSyncEntityCopyWith<$R, $In extends FakeSyncEntity, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call(
      {String? id, String? message, DateTime? createdAt, DateTime? updatedAt});
  FakeSyncEntityCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _FakeSyncEntityCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FakeSyncEntity, $Out>
    implements FakeSyncEntityCopyWith<$R, FakeSyncEntity, $Out> {
  _FakeSyncEntityCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FakeSyncEntity> $mapper =
      FakeSyncEntityMapper.ensureInitialized();
  @override
  $R call(
          {String? id,
          String? message,
          Object? createdAt = $none,
          Object? updatedAt = $none}) =>
      $apply(FieldCopyWithData({
        if (id != null) #id: id,
        if (message != null) #message: message,
        if (createdAt != $none) #createdAt: createdAt,
        if (updatedAt != $none) #updatedAt: updatedAt
      }));
  @override
  FakeSyncEntity $make(CopyWithData data) => FakeSyncEntity(
      id: data.get(#id, or: $value.id),
      message: data.get(#message, or: $value.message),
      createdAt: data.get(#createdAt, or: $value.createdAt),
      updatedAt: data.get(#updatedAt, or: $value.updatedAt));

  @override
  FakeSyncEntityCopyWith<$R2, FakeSyncEntity, $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _FakeSyncEntityCopyWithImpl($value, $cast, t);
}
