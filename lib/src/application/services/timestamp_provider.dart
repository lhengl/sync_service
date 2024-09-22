import 'package:flutter_kronos/flutter_kronos.dart';

abstract class TimestampProvider {
  Future<DateTime> get currentTime;
}

class KronosTimestampProvider implements TimestampProvider {
  const KronosTimestampProvider();
  @override
  Future<DateTime> get currentTime async => (await FlutterKronos.getNtpDateTime ?? DateTime.now()).toUtc();
}

class FakeTimeStampProvider implements TimestampProvider {
  const FakeTimeStampProvider();
  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}
