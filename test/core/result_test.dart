import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/result/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('値を保持する', () {
        const result = Result<int, String>.success(42);

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.valueOrNull, 42);
        expect(result.errorOrNull, null);
      });

      test('whenで値を取得できる', () {
        const result = Result<int, String>.success(42);

        final value = result.when(
          success: (v) => 'Success: $v',
          failure: (e) => 'Failure: $e',
        );

        expect(value, 'Success: 42');
      });

      test('mapで変換できる', () {
        const result = Result<int, String>.success(42);
        final mapped = result.map((v) => v * 2);

        expect(mapped.valueOrNull, 84);
      });

      test('getOrElseで値を取得できる', () {
        const result = Result<int, String>.success(42);
        expect(result.getOrElse(0), 42);
      });

      test('getOrThrowで値を取得できる', () {
        const result = Result<int, String>.success(42);
        expect(result.getOrThrow(), 42);
      });

      test('flatMapでResultをチェーンできる', () {
        const result = Result<int, String>.success(42);
        final chained = result.flatMap((v) => Result.success(v.toString()));

        expect(chained.valueOrNull, '42');
      });

      test('equalityが正しく動作する', () {
        const result1 = Result<int, String>.success(42);
        const result2 = Result<int, String>.success(42);
        const result3 = Result<int, String>.success(100);

        expect(result1, result2);
        expect(result1, isNot(result3));
      });
    });

    group('Failure', () {
      test('エラーを保持する', () {
        const result = Result<int, String>.failure('error');

        expect(result.isSuccess, false);
        expect(result.isFailure, true);
        expect(result.valueOrNull, null);
        expect(result.errorOrNull, 'error');
      });

      test('whenでエラーを取得できる', () {
        const result = Result<int, String>.failure('error');

        final value = result.when(
          success: (v) => 'Success: $v',
          failure: (e) => 'Failure: $e',
        );

        expect(value, 'Failure: error');
      });

      test('mapはエラーを維持する', () {
        const result = Result<int, String>.failure('error');
        final mapped = result.map((v) => v * 2);

        expect(mapped.errorOrNull, 'error');
      });

      test('mapErrorでエラーを変換できる', () {
        const result = Result<int, String>.failure('error');
        final mapped = result.mapError((e) => e.toUpperCase());

        expect(mapped.errorOrNull, 'ERROR');
      });

      test('getOrElseでデフォルト値を取得できる', () {
        const result = Result<int, String>.failure('error');
        expect(result.getOrElse(99), 99);
      });

      test('getOrThrowで例外をスローする', () {
        const result = Result<int, String>.failure('error');
        expect(() => result.getOrThrow(), throwsA('error'));
      });

      test('flatMapはエラーを維持する', () {
        const result = Result<int, String>.failure('error');
        final chained = result.flatMap((v) => Result.success(v.toString()));

        expect(chained.errorOrNull, 'error');
      });

      test('equalityが正しく動作する', () {
        const result1 = Result<int, String>.failure('error');
        const result2 = Result<int, String>.failure('error');
        const result3 = Result<int, String>.failure('other');

        expect(result1, result2);
        expect(result1, isNot(result3));
      });
    });

    group('Extensions', () {
      test('onSuccessが成功時にのみ実行される', () {
        var called = false;
        const Result<int, String>.success(42).onSuccess((_) => called = true);
        expect(called, true);

        called = false;
        const Result<int, String>.failure('error').onSuccess((_) => called = true);
        expect(called, false);
      });

      test('onFailureが失敗時にのみ実行される', () {
        var called = false;
        const Result<int, String>.failure('error').onFailure((_) => called = true);
        expect(called, true);

        called = false;
        const Result<int, String>.success(42).onFailure((_) => called = true);
        expect(called, false);
      });
    });
  });
}
