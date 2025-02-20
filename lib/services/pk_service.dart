class PK {
  static final BigInt startTime = BigInt.from(
  DateTime.now().millisecondsSinceEpoch - 1735671600000); // Epoch starts at Jan 1, 2025

  static final Stopwatch stopwatch = Stopwatch()..start();
  static BigInt upTime = BigInt.zero;
  static late BigInt deviceId;

  static void initialize(BigInt Deviceid) {
    deviceId = Deviceid;
  }

  static BigInt getPK() {
    final int elapsed = stopwatch.elapsedMilliseconds;

    if (BigInt.from(elapsed) > upTime) {
      upTime = BigInt.from(elapsed);
    } else {
      upTime += BigInt.one;
    }

    return ((startTime + upTime) << 24) + (deviceId & BigInt.from(0xFFFFFF));
  }
}
