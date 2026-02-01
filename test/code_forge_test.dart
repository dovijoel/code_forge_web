import 'package:flutter_test/flutter_test.dart';
import 'package:code_forge_web/code_forge.dart';

void main() {
  group('CodeForgeController', () {
    test('can be instantiated', () {
      final controller = CodeForgeController();
      expect(controller, isNotNull);
    });

    test('can set and get text', () {
      final controller = CodeForgeController();
      controller.text = 'Hello, World!';
      expect(controller.text, 'Hello, World!');
    });
  });

  group('Web Compatibility', () {
    test('getPlatformPid returns an int', () {
      // On native, returns the actual PID
      // On web, returns -1
      expect(getPlatformPid(), isA<int>());
    });
  });
}
