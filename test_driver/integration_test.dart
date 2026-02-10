import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [args]) async {
      final dir = Directory('docs/screenshots');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('docs/screenshots/$name.png');
      await file.writeAsBytes(bytes);
      print('📸 Saved: docs/screenshots/$name.png');
      return true;
    },
  );
}
