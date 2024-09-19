import 'loggable.dart';

class RetryHelper<T> with Loggable {
  final Future<T> Function() future;
  final int retries;
  final Duration retryInterval;

  RetryHelper({
    required this.future,
    this.retries = 3,
    this.retryInterval = const Duration(seconds: 5),
  });

  /// A helper function that retries a given future function with specified retry attempts and intervals.
  Future<T> retry() async {
    int attempts = 0;
    while (attempts < retries) {
      try {
        return await future();
      } catch (e, s) {
        attempts++;
        if (attempts >= retries) {
          rethrow; // Rethrow the final error after all retries have failed
        }
        devLog(
          'Retry attempt $attempts failed. Retrying in ${retryInterval.inSeconds} seconds.',
          error: e,
          stackTrace: s,
        );
        await Future.delayed(retryInterval);
      }
    }
    throw Exception('All retry attempts failed.'); // Throw a generic exception if all retries fail
  }
}
