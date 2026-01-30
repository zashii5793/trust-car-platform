import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';

void main() {
  late ServiceLocator locator;

  setUp(() {
    locator = ServiceLocator.instance;
    locator.reset();
  });

  tearDown(() {
    locator.reset();
  });

  group('ServiceLocator', () {
    group('register', () {
      test('ファクトリを登録して取得できる', () {
        locator.register<String>(() => 'test');

        expect(locator.get<String>(), 'test');
      });

      test('毎回新しいインスタンスを生成する', () {
        var counter = 0;
        locator.register<int>(() => ++counter);

        expect(locator.get<int>(), 1);
        expect(locator.get<int>(), 2);
        expect(locator.get<int>(), 3);
      });
    });

    group('registerLazySingleton', () {
      test('初回のみインスタンスを生成する', () {
        var counter = 0;
        locator.registerLazySingleton<int>(() => ++counter);

        expect(locator.get<int>(), 1);
        expect(locator.get<int>(), 1);
        expect(locator.get<int>(), 1);
      });
    });

    group('registerSingleton', () {
      test('インスタンスを直接登録できる', () {
        locator.registerSingleton<String>('singleton');

        expect(locator.get<String>(), 'singleton');
      });
    });

    group('get', () {
      test('未登録の型で例外をスローする', () {
        expect(
          () => locator.get<double>(),
          throwsA(isA<ServiceLocatorException>()),
        );
      });
    });

    group('tryGet', () {
      test('未登録の型でnullを返す', () {
        expect(locator.tryGet<double>(), null);
      });

      test('登録済みの型で値を返す', () {
        locator.registerSingleton<String>('test');

        expect(locator.tryGet<String>(), 'test');
      });
    });

    group('isRegistered', () {
      test('登録状態を確認できる', () {
        expect(locator.isRegistered<String>(), false);

        locator.registerSingleton<String>('test');

        expect(locator.isRegistered<String>(), true);
      });
    });

    group('unregister', () {
      test('登録を解除できる', () {
        locator.registerSingleton<String>('test');

        expect(locator.isRegistered<String>(), true);

        locator.unregister<String>();

        expect(locator.isRegistered<String>(), false);
      });
    });

    group('reset', () {
      test('全ての登録を解除する', () {
        locator.registerSingleton<String>('test');
        locator.registerSingleton<int>(42);

        locator.reset();

        expect(locator.isRegistered<String>(), false);
        expect(locator.isRegistered<int>(), false);
      });
    });

    group('override', () {
      test('既存の登録を上書きする', () {
        locator.registerSingleton<String>('original');

        expect(locator.get<String>(), 'original');

        locator.override<String>('overridden');

        expect(locator.get<String>(), 'overridden');
      });
    });

    group('sl shortcut', () {
      test('ServiceLocator.instanceと同じインスタンスを返す', () {
        expect(sl, same(ServiceLocator.instance));
      });
    });
  });
}
