import 'package:flutter_test/flutter_test.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';

void main() {
  test('configuration defaults are set', () {
    expect(Configuration.AuthUrl, isNotEmpty);
  });
}
