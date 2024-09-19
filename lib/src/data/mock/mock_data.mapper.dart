// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'mock_data.dart';

class MockSyncEntityMapper extends ClassMapperBase<MockSyncEntity> {
  MockSyncEntityMapper._();

  static MockSyncEntityMapper? _instance;
  static MockSyncEntityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MockSyncEntityMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'MockSyncEntity';

  static String _$id(MockSyncEntity v) => v.id;
  static const Field<MockSyncEntity, String> _f$id = Field('id', _$id);
  static DateTime _$createdAt(MockSyncEntity v) => v.createdAt;
  static const Field<MockSyncEntity, DateTime> _f$createdAt =
      Field('createdAt', _$createdAt);
  static DateTime _$updatedAt(MockSyncEntity v) => v.updatedAt;
  static const Field<MockSyncEntity, DateTime> _f$updatedAt =
      Field('updatedAt', _$updatedAt);
  static String _$message(MockSyncEntity v) => v.message;
  static const Field<MockSyncEntity, String> _f$message =
      Field('message', _$message);

  @override
  final MappableFields<MockSyncEntity> fields = const {
    #id: _f$id,
    #createdAt: _f$createdAt,
    #updatedAt: _f$updatedAt,
    #message: _f$message,
  };

  static MockSyncEntity _instantiate(DecodingData data) {
    return MockSyncEntity(
        id: data.dec(_f$id),
        createdAt: data.dec(_f$createdAt),
        updatedAt: data.dec(_f$updatedAt),
        message: data.dec(_f$message));
  }

  @override
  final Function instantiate = _instantiate;

  static MockSyncEntity fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MockSyncEntity>(map);
  }

  static MockSyncEntity fromJson(String json) {
    return ensureInitialized().decodeJson<MockSyncEntity>(json);
  }
}

mixin MockSyncEntityMappable {
  String toJson() {
    return MockSyncEntityMapper.ensureInitialized()
        .encodeJson<MockSyncEntity>(this as MockSyncEntity);
  }

  Map<String, dynamic> toMap() {
    return MockSyncEntityMapper.ensureInitialized()
        .encodeMap<MockSyncEntity>(this as MockSyncEntity);
  }

  MockSyncEntityCopyWith<MockSyncEntity, MockSyncEntity, MockSyncEntity>
      get copyWith => _MockSyncEntityCopyWithImpl(
          this as MockSyncEntity, $identity, $identity);
  @override
  String toString() {
    return MockSyncEntityMapper.ensureInitialized()
        .stringifyValue(this as MockSyncEntity);
  }

  @override
  bool operator ==(Object other) {
    return MockSyncEntityMapper.ensureInitialized()
        .equalsValue(this as MockSyncEntity, other);
  }

  @override
  int get hashCode {
    return MockSyncEntityMapper.ensureInitialized()
        .hashValue(this as MockSyncEntity);
  }
}

extension MockSyncEntityValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MockSyncEntity, $Out> {
  MockSyncEntityCopyWith<$R, MockSyncEntity, $Out> get $asMockSyncEntity =>
      $base.as((v, t, t2) => _MockSyncEntityCopyWithImpl(v, t, t2));
}

abstract class MockSyncEntityCopyWith<$R, $In extends MockSyncEntity, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call(
      {String? id, DateTime? createdAt, DateTime? updatedAt, String? message});
  MockSyncEntityCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _MockSyncEntityCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MockSyncEntity, $Out>
    implements MockSyncEntityCopyWith<$R, MockSyncEntity, $Out> {
  _MockSyncEntityCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MockSyncEntity> $mapper =
      MockSyncEntityMapper.ensureInitialized();
  @override
  $R call(
          {String? id,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? message}) =>
      $apply(FieldCopyWithData({
        if (id != null) #id: id,
        if (createdAt != null) #createdAt: createdAt,
        if (updatedAt != null) #updatedAt: updatedAt,
        if (message != null) #message: message
      }));
  @override
  MockSyncEntity $make(CopyWithData data) => MockSyncEntity(
      id: data.get(#id, or: $value.id),
      createdAt: data.get(#createdAt, or: $value.createdAt),
      updatedAt: data.get(#updatedAt, or: $value.updatedAt),
      message: data.get(#message, or: $value.message));

  @override
  MockSyncEntityCopyWith<$R2, MockSyncEntity, $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _MockSyncEntityCopyWithImpl($value, $cast, t);
}
