part of 'soft_deletion_impl.dart';

class FirestoreDisposalRegistryMapper extends JsonMapper<DisposalRegistry> {
  @override
  DisposalRegistry fromMap(Map<String, dynamic> map) {
    return DisposalRegistry.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(DisposalRegistry value) {
    return value.toMap();
  }
}

/// This is important to reconcile the sync state during an extended offline period.
@MappableClass()
class DisposalRegistry with DisposalRegistryMappable {
  static const String userIdField = 'userId';
  static const String lastDisposedByDeviceIdField = 'lastDisposedByDeviceId';
  static const String disposalCutoffField = 'disposalCutoff';
  static const String deviceLastDisposalField = 'deviceLastDisposal';

  final String userId;

  String? lastDisposedByDeviceId;

  /// Each time a disposer clears soft deleted records, it guarantees to only dispose records that are older
  /// than this cutoff, so any devices that stayed offline should check that its last synced time is after this cut off.
  /// Otherwise, it needs to be invalidated.
  DateTime disposalCutoff;

  /// A map of device and their last disposal time in the form of
  /// {deviceId:lastDisposal}
  final Map<String, DateTime> _deviceLastDisposal;
  Map<String, DateTime> get deviceLastDisposal => {..._deviceLastDisposal};

  @MappableConstructor()
  DisposalRegistry({
    required this.userId,
    this.lastDisposedByDeviceId,
    DateTime? disposalCutoff,
    Map<String, DateTime>? deviceLastDisposal,
  })  : _deviceLastDisposal = deviceLastDisposal ?? {},
        disposalCutoff = disposalCutoff ?? DateTime.now().subtract(const Duration(days: 14));

  DisposalRegistry.required({
    required this.userId,
    required this.lastDisposedByDeviceId,
    required this.disposalCutoff,
    Map<String, DateTime>? deviceLastDisposal,
  }) : _deviceLastDisposal = deviceLastDisposal ?? {};

  factory DisposalRegistry.fromJson(String json) => DisposalRegistryMapper.fromJson(json);
  factory DisposalRegistry.fromMap(Map<String, dynamic> map) => DisposalRegistryMapper.fromMap(map);

  /// Register the disposal attempt by the device
  void registerDisposal({
    required String deviceId,
    required DateTime disposalCutoff,
  }) {
    if (disposalCutoff.isBefore(this.disposalCutoff)) {
      throw StateError('New disposalCutoff ($disposalCutoff) cannot be before current '
          'disposalCutoff${this.disposalCutoff}');
    }
    final now = DateTime.now();
    _deviceLastDisposal[deviceId] = now;
    lastDisposedByDeviceId = deviceId;
    this.disposalCutoff = disposalCutoff;
  }

  /// Check if the cache on this device is valid by comparing its last disposal and cutoff time
  /// If this is false, the device should invalidate its cache and resync
  bool cacheIsValid(String deviceId) {
    final lastDisposal = _deviceLastDisposal[deviceId];
    if (lastDisposal == null) {
      // Device has never synced before
      return false;
    }

    // If the calling device is the last disposer, cache should be valid
    if (lastDisposedByDeviceId == deviceId) {
      return true;
    }

    // Ensure the device last disposed after the cutoff
    return lastDisposal.isAfter(disposalCutoff);
  }
}
