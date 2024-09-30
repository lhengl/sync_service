// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'firestore_hard_deletion.dart';

class DeletionRegistryMapper extends ClassMapperBase<DeletionRegistry> {
  DeletionRegistryMapper._();

  static DeletionRegistryMapper? _instance;
  static DeletionRegistryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeletionRegistryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DeletionRegistry';

  static String _$userId(DeletionRegistry v) => v.userId;
  static const Field<DeletionRegistry, String> _f$userId =
      Field('userId', _$userId);
  static Map<String, DateTime> _$deviceLastSynced(DeletionRegistry v) =>
      v.deviceLastSynced;
  static const Field<DeletionRegistry, Map<String, DateTime>>
      _f$deviceLastSynced =
      Field('deviceLastSynced', _$deviceLastSynced, opt: true);
  static Map<String, Map<String, Set<String>>> _$deletions(
          DeletionRegistry v) =>
      v.deletions;
  static const Field<DeletionRegistry, Map<String, Map<String, Set<String>>>>
      _f$deletions = Field('deletions', _$deletions, opt: true);
  static String? _$lastDeviceId(DeletionRegistry v) => v.lastDeviceId;
  static const Field<DeletionRegistry, String> _f$lastDeviceId =
      Field('lastDeviceId', _$lastDeviceId, opt: true);
  static Map<String, Map<String, Set<String>>> _$deletionsByCollection(
          DeletionRegistry v) =>
      v.deletionsByCollection;
  static const Field<DeletionRegistry, Map<String, Map<String, Set<String>>>>
      _f$deletionsByCollection = Field(
          'deletionsByCollection', _$deletionsByCollection,
          mode: FieldMode.member);

  @override
  final MappableFields<DeletionRegistry> fields = const {
    #userId: _f$userId,
    #deviceLastSynced: _f$deviceLastSynced,
    #deletions: _f$deletions,
    #lastDeviceId: _f$lastDeviceId,
    #deletionsByCollection: _f$deletionsByCollection,
  };

  static DeletionRegistry _instantiate(DecodingData data) {
    return DeletionRegistry(
        userId: data.dec(_f$userId),
        deviceLastSynced: data.dec(_f$deviceLastSynced),
        deletions: data.dec(_f$deletions),
        lastDeviceId: data.dec(_f$lastDeviceId));
  }

  @override
  final Function instantiate = _instantiate;

  static DeletionRegistry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DeletionRegistry>(map);
  }

  static DeletionRegistry fromJson(String json) {
    return ensureInitialized().decodeJson<DeletionRegistry>(json);
  }
}

mixin DeletionRegistryMappable {
  String toJson() {
    return DeletionRegistryMapper.ensureInitialized()
        .encodeJson<DeletionRegistry>(this as DeletionRegistry);
  }

  Map<String, dynamic> toMap() {
    return DeletionRegistryMapper.ensureInitialized()
        .encodeMap<DeletionRegistry>(this as DeletionRegistry);
  }

  DeletionRegistryCopyWith<DeletionRegistry, DeletionRegistry, DeletionRegistry>
      get copyWith => _DeletionRegistryCopyWithImpl(
          this as DeletionRegistry, $identity, $identity);
  @override
  String toString() {
    return DeletionRegistryMapper.ensureInitialized()
        .stringifyValue(this as DeletionRegistry);
  }

  @override
  bool operator ==(Object other) {
    return DeletionRegistryMapper.ensureInitialized()
        .equalsValue(this as DeletionRegistry, other);
  }

  @override
  int get hashCode {
    return DeletionRegistryMapper.ensureInitialized()
        .hashValue(this as DeletionRegistry);
  }
}

extension DeletionRegistryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DeletionRegistry, $Out> {
  DeletionRegistryCopyWith<$R, DeletionRegistry, $Out>
      get $asDeletionRegistry =>
          $base.as((v, t, t2) => _DeletionRegistryCopyWithImpl(v, t, t2));
}

abstract class DeletionRegistryCopyWith<$R, $In extends DeletionRegistry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, DateTime, ObjectCopyWith<$R, DateTime, DateTime>>
      get deviceLastSynced;
  MapCopyWith<
      $R,
      String,
      Map<String, Set<String>>,
      ObjectCopyWith<$R, Map<String, Set<String>>,
          Map<String, Set<String>>>> get deletions;
  $R call(
      {String? userId,
      Map<String, DateTime>? deviceLastSynced,
      Map<String, Map<String, Set<String>>>? deletions,
      String? lastDeviceId});
  DeletionRegistryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _DeletionRegistryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DeletionRegistry, $Out>
    implements DeletionRegistryCopyWith<$R, DeletionRegistry, $Out> {
  _DeletionRegistryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DeletionRegistry> $mapper =
      DeletionRegistryMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, DateTime, ObjectCopyWith<$R, DateTime, DateTime>>
      get deviceLastSynced => MapCopyWith(
          $value.deviceLastSynced,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(deviceLastSynced: v));
  @override
  MapCopyWith<
      $R,
      String,
      Map<String, Set<String>>,
      ObjectCopyWith<$R, Map<String, Set<String>>,
          Map<String, Set<String>>>> get deletions => MapCopyWith(
      $value.deletions,
      (v, t) => ObjectCopyWith(v, $identity, t),
      (v) => call(deletions: v));
  @override
  $R call(
          {String? userId,
          Object? deviceLastSynced = $none,
          Object? deletions = $none,
          Object? lastDeviceId = $none}) =>
      $apply(FieldCopyWithData({
        if (userId != null) #userId: userId,
        if (deviceLastSynced != $none) #deviceLastSynced: deviceLastSynced,
        if (deletions != $none) #deletions: deletions,
        if (lastDeviceId != $none) #lastDeviceId: lastDeviceId
      }));
  @override
  DeletionRegistry $make(CopyWithData data) => DeletionRegistry(
      userId: data.get(#userId, or: $value.userId),
      deviceLastSynced:
          data.get(#deviceLastSynced, or: $value.deviceLastSynced),
      deletions: data.get(#deletions, or: $value.deletions),
      lastDeviceId: data.get(#lastDeviceId, or: $value.lastDeviceId));

  @override
  DeletionRegistryCopyWith<$R2, DeletionRegistry, $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _DeletionRegistryCopyWithImpl($value, $cast, t);
}
