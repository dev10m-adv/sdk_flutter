import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PK {
  static final BigInt startTime =
      BigInt.from(DateTime.now().millisecondsSinceEpoch - 1735671600000);
  static final Stopwatch stopwatch = Stopwatch()..start();
  static BigInt upTime = BigInt.zero;
  static late BigInt deviceId;
  static bool _isInitialized = false; // Track initialization status

  // Fetch deviceId automatically when calling getPK()
  static Future<void> _initializeIfNeeded() async {
    if (!_isInitialized) {
      final FlutterSecureStorage secureStorage = FlutterSecureStorage();
      String? deviceIdStr = await secureStorage.read(key: "DeviceId");
      // final SharedPreferences prefs = await SharedPreferences.getInstance();
      // String? deviceIdStr = prefs.getString('deviceId');
      

      if (deviceIdStr == null || deviceIdStr.isEmpty) {
        throw Exception("Device ID not found in SharedPreferences");
      }

      deviceId = BigInt.from(int.tryParse(deviceIdStr) ?? 0);
      _isInitialized = true;
    }
  }

  static Future<BigInt> getPK() async {
    await _initializeIfNeeded(); // Ensure deviceId is set before using it

    final BigInt elapsed = BigInt.from(stopwatch.elapsedMilliseconds);
    if (elapsed > upTime) {
      upTime = elapsed;
    } else {
      upTime += BigInt.one;
    }

    return ((startTime + upTime) << 24) + (deviceId & BigInt.from(0xFFFFFF));
  }
}
