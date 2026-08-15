import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/maps_config.dart';

void main() {
  group('MapsConfig', () {
    test('MAPS_API_KEY 未設定時は apiKey が空・isConfigured=false（ビルド安全）', () {
      // テストは --dart-define なしで走るため既定は空。
      expect(MapsConfig.apiKey, isEmpty);
      expect(MapsConfig.isConfigured, isFalse);
    });
  });
}
