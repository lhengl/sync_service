// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'soft_deletion_impl.dart';

class DisposalRegistryMapper extends ClassMapperBase<DisposalRegistry> {
  DisposalRegistryMapper._();

  static DisposalRegistryMapper? _instance;
  static DisposalRegistryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DisposalRegistryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DisposalRegistry';

  static String _$userId(DisposalRegistry v) => v.userId;
  static const Field<DisposalRegistry, String> _f$userId =
      Field('userId', _$userId);
  static String? _$lastDisposedByDeviceId(DisposalRegistry v) =>
      v.lastDisposedByDeviceId;
  static const Field<DisposalRegistry, String> _f$lastDisposedByDeviceId =
      Field('lastDisposedByDeviceId', _$lastDisposedByDeviceId, opt: true);
  static DateTime _$disposalCutoff(DisposalRegistry v) => v.disposalCutoff;
  static const Field<DisposalRegistry, DateTime> _f$disposalCutoff =
      Field('disposalCutoff', _$disposalCutoff, opt: true);
  static Map<String, DateTime> _$_deviceLastDisposal(DisposalRegistry v) =>
      v._deviceLastDisposal;
  static const Field<DisposalRegistry, Map<String, DateTime>>
      _f$_deviceLastDisposal = Field(
          '_deviceLastDisposal', _$_deviceLastDisposal,
          key: 'deviceLastDisposal', opt: true);

  @override
  final MappableFields<DisposalRegistry> fields = const {
    #userId: _f$userId,
    #lastDisposedByDeviceId: _f$lastDisposedByDeviceId,
    #disposalCutoff: _f$disposalCutoff,
    #_deviceLastDisposal: _f$_deviceLastDisposal,
  };

  static DisposalRegistry _instantiate(DecodingData data) {
    return DisposalRegistry(
        userId: data.dec(_f$userId),
        lastDisposedByDeviceId: data.dec(_f$lastDisposedByDeviceId),
        disposalCutoff: data.dec(_f$disposalCutoff),
        deviceLastDisposal: data.dec(_f$_deviceLastDisposal));
  }

  @override
  final Function instantiate = _instantiate;

  static DisposalRegistry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DisposalRegistry>(map);
  }

  static DisposalRegistry fromJson(String json) {
    return ensureInitialized().decodeJson<DisposalRegistry>(json);
  }
}

mixin DisposalRegistryMappable {
  String toJson() {
    return DisposalRegistryMapper.ensureInitialized()
        .encodeJson<DisposalRegistry>(this as DisposalRegistry);
  }

  Map<String, dynamic> toMap() {
    return DisposalRegistryMapper.ensureInitialized()
        .encodeMap<DisposalRegistry>(this as DisposalRegistry);
  }

  DisposalRegistryCopyWith<DisposalRegistry, DisposalRegistry, DisposalRegistry>
      get copyWith => _DisposalRegistryCopyWithImpl(
          this as DisposalRegistry, $identity, $identity);
  @override
  String toString() {
    return DisposalRegistryMapper.ensureInitialized()
        .stringifyValue(this as DisposalRegistry);
  }

  @override
  bool operator ==(Object other) {
    return DisposalRegistryMapper.ensureInitialized()
        .equalsValue(this as DisposalRegistry, other);
  }

  @override
  int get hashCode {
    return DisposalRegistryMapper.ensureInitialized()
        .hashValue(this as DisposalRegistry);
  }
}

extension DisposalRegistryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DisposalRegistry, $Out> {
  DisposalRegistryCopyWith<$R, DisposalRegistry, $Out>
      get $asDisposalRegistry =>
          $base.as((v, t, t2) => _DisposalRegistryCopyWithImpl(v, t, t2));
}

abstract class DisposalRegistryCopyWith<$R, $In extends DisposalRegistry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, DateTime, ObjectCopyWith<$R, DateTime, DateTime>>
      get _deviceLastDisposal;
  $R call(
      {String? userId,
      String? lastDisposedByDeviceId,
      DateTime? disposalCutoff,
      Map<String, DateTime>? deviceLastDisposal});
  DisposalRegistryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _DisposalRegistryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DisposalRegistry, $Out>
    implements DisposalRegistryCopyWith<$R, DisposalRegistry, $Out> {
  _DisposalRegistryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DisposalRegistry> $mapper =
      DisposalRegistryMapper.ensureInitialized();
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
  DisposalRegistry $make(CopyWithData data) => DisposalRegistry(
      userId: data.get(#userId, or: $value.userId),
      lastDisposedByDeviceId:
          data.get(#lastDisposedByDeviceId, or: $value.lastDisposedByDeviceId),
      disposalCutoff: data.get(#disposalCutoff, or: $value.disposalCutoff),
      deviceLastDisposal:
          data.get(#deviceLastDisposal, or: $value._deviceLastDisposal));

  @override
  DisposalRegistryCopyWith<$R2, DisposalRegistry, $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _DisposalRegistryCopyWithImpl($value, $cast, t);
}
