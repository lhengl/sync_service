// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'firestore_soft_deletion.dart';

class TrashRegistryMapper extends ClassMapperBase<TrashRegistry> {
  TrashRegistryMapper._();

  static TrashRegistryMapper? _instance;
  static TrashRegistryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TrashRegistryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'TrashRegistry';

  static String _$userId(TrashRegistry v) => v.userId;
  static const Field<TrashRegistry, String> _f$userId =
      Field('userId', _$userId);
  static String? _$lastDisposedByDeviceId(TrashRegistry v) =>
      v.lastDisposedByDeviceId;
  static const Field<TrashRegistry, String> _f$lastDisposedByDeviceId =
      Field('lastDisposedByDeviceId', _$lastDisposedByDeviceId, opt: true);
  static DateTime _$disposalCutoff(TrashRegistry v) => v.disposalCutoff;
  static const Field<TrashRegistry, DateTime> _f$disposalCutoff =
      Field('disposalCutoff', _$disposalCutoff, opt: true);
  static Map<String, DateTime> _$_deviceLastDisposal(TrashRegistry v) =>
      v._deviceLastDisposal;
  static const Field<TrashRegistry, Map<String, DateTime>>
      _f$_deviceLastDisposal = Field(
          '_deviceLastDisposal', _$_deviceLastDisposal,
          key: 'deviceLastDisposal', opt: true);

  @override
  final MappableFields<TrashRegistry> fields = const {
    #userId: _f$userId,
    #lastDisposedByDeviceId: _f$lastDisposedByDeviceId,
    #disposalCutoff: _f$disposalCutoff,
    #_deviceLastDisposal: _f$_deviceLastDisposal,
  };

  static TrashRegistry _instantiate(DecodingData data) {
    return TrashRegistry(
        userId: data.dec(_f$userId),
        lastDisposedByDeviceId: data.dec(_f$lastDisposedByDeviceId),
        disposalCutoff: data.dec(_f$disposalCutoff),
        deviceLastDisposal: data.dec(_f$_deviceLastDisposal));
  }

  @override
  final Function instantiate = _instantiate;

  static TrashRegistry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TrashRegistry>(map);
  }

  static TrashRegistry fromJson(String json) {
    return ensureInitialized().decodeJson<TrashRegistry>(json);
  }
}

mixin TrashRegistryMappable {
  String toJson() {
    return TrashRegistryMapper.ensureInitialized()
        .encodeJson<TrashRegistry>(this as TrashRegistry);
  }

  Map<String, dynamic> toMap() {
    return TrashRegistryMapper.ensureInitialized()
        .encodeMap<TrashRegistry>(this as TrashRegistry);
  }

  TrashRegistryCopyWith<TrashRegistry, TrashRegistry, TrashRegistry>
      get copyWith => _TrashRegistryCopyWithImpl(
          this as TrashRegistry, $identity, $identity);
  @override
  String toString() {
    return TrashRegistryMapper.ensureInitialized()
        .stringifyValue(this as TrashRegistry);
  }

  @override
  bool operator ==(Object other) {
    return TrashRegistryMapper.ensureInitialized()
        .equalsValue(this as TrashRegistry, other);
  }

  @override
  int get hashCode {
    return TrashRegistryMapper.ensureInitialized()
        .hashValue(this as TrashRegistry);
  }
}

extension TrashRegistryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TrashRegistry, $Out> {
  TrashRegistryCopyWith<$R, TrashRegistry, $Out> get $asTrashRegistry =>
      $base.as((v, t, t2) => _TrashRegistryCopyWithImpl(v, t, t2));
}

abstract class TrashRegistryCopyWith<$R, $In extends TrashRegistry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, DateTime, ObjectCopyWith<$R, DateTime, DateTime>>
      get _deviceLastDisposal;
  $R call(
      {String? userId,
      String? lastDisposedByDeviceId,
      DateTime? disposalCutoff,
      Map<String, DateTime>? deviceLastDisposal});
  TrashRegistryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TrashRegistryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TrashRegistry, $Out>
    implements TrashRegistryCopyWith<$R, TrashRegistry, $Out> {
  _TrashRegistryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TrashRegistry> $mapper =
      TrashRegistryMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, DateTime, ObjectCopyWith<$R, DateTime, DateTime>>
      get _deviceLastDisposal => MapCopyWith(
          $value._deviceLastDisposal,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(deviceLastDisposal: v));
  @override
  $R call(
          {String? userId,
          Object? lastDisposedByDeviceId = $none,
          Object? disposalCutoff = $none,
          Object? deviceLastDisposal = $none}) =>
      $apply(FieldCopyWithData({
        if (userId != null) #userId: userId,
        if (lastDisposedByDeviceId != $none)
          #lastDisposedByDeviceId: lastDisposedByDeviceId,
        if (disposalCutoff != $none) #disposalCutoff: disposalCutoff,
        if (deviceLastDisposal != $none) #deviceLastDisposal: deviceLastDisposal
      }));
  @override
  TrashRegistry $make(CopyWithData data) => TrashRegistry(
      userId: data.get(#userId, or: $value.userId),
      lastDisposedByDeviceId:
          data.get(#lastDisposedByDeviceId, or: $value.lastDisposedByDeviceId),
      disposalCutoff: data.get(#disposalCutoff, or: $value.disposalCutoff),
      deviceLastDisposal:
          data.get(#deviceLastDisposal, or: $value._deviceLastDisposal));

  @override
  TrashRegistryCopyWith<$R2, TrashRegistry, $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _TrashRegistryCopyWithImpl($value, $cast, t);
}
