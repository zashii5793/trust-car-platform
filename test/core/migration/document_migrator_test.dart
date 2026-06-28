import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/migration/document_migrator.dart';

void main() {
  group('DocumentMigrator', () {
    test('currentVersion=1・ステップ無し: データを変えずに返す', () {
      const migrator =
          DocumentMigrator(<int, MigrationStep>{}, currentVersion: 1);

      final result = migrator.migrate({'name': 'a'});

      expect(result['name'], 'a');
    });

    test('v1→v2: 単一ステップを適用し schemaVersion を 2 にする', () {
      final migrator = DocumentMigrator(
        {
          1: (d) => {...d, 'title': d['name'], 'name': null},
        },
        currentVersion: 2,
      );

      final result = migrator.migrate({'name': '整備', 'schemaVersion': 1});

      expect(result['title'], '整備');
      expect(result['schemaVersion'], 2);
    });

    test('v1→v3: 複数ステップを順番に適用する', () {
      final migrator = DocumentMigrator(
        {
          1: (d) => {...d, 'step1': true},
          2: (d) => {...d, 'step2': true},
        },
        currentVersion: 3,
      );

      final result = migrator.migrate({'schemaVersion': 1});

      expect(result['step1'], true);
      expect(result['step2'], true);
      expect(result['schemaVersion'], 3);
    });

    test('schemaVersion 欠損は v1 とみなして移行する', () {
      final migrator = DocumentMigrator(
        {
          1: (d) => {...d, 'migrated': true},
        },
        currentVersion: 2,
      );

      final result = migrator.migrate({'name': 'x'}); // schemaVersion なし

      expect(result['migrated'], true);
      expect(result['schemaVersion'], 2);
    });

    test('冪等性: 2回適用しても結果は1回と同じ', () {
      final migrator = DocumentMigrator(
        {
          1: (d) => {...d, 'count': (d['count'] as int? ?? 0) + 1},
        },
        currentVersion: 2,
      );

      final once = migrator.migrate({'schemaVersion': 1, 'count': 0});
      final twice = migrator.migrate(once);

      expect(once['count'], 1);
      expect(twice['count'], 1); // 再適用されない（既に v2）
      expect(twice['schemaVersion'], 2);
    });

    test('入力マップを破壊的に変更しない', () {
      final migrator = DocumentMigrator(
        {
          1: (d) => {...d, 'added': true},
        },
        currentVersion: 2,
      );

      final input = {'schemaVersion': 1, 'name': 'orig'};
      migrator.migrate(input);

      expect(input.containsKey('added'), isFalse);
      expect(input['schemaVersion'], 1);
    });

    group('Edge Cases', () {
      test('既に currentVersion のデータはそのまま返す', () {
        final migrator = DocumentMigrator(
          {
            1: (d) => {...d, 'shouldNotRun': true},
          },
          currentVersion: 2,
        );

        final result = migrator.migrate({'schemaVersion': 2, 'name': 'y'});

        expect(result.containsKey('shouldNotRun'), isFalse);
        expect(result['schemaVersion'], 2);
      });

      test('未来バージョン（current超）はダウングレードせず据え置く', () {
        final migrator =
            DocumentMigrator(<int, MigrationStep>{}, currentVersion: 2);

        final result = migrator.migrate({'schemaVersion': 5, 'name': 'future'});

        expect(result['schemaVersion'], 5); // 2 に下げない
        expect(result['name'], 'future');
      });

      test('連鎖が途切れている（必要なステップ欠落）と StateError', () {
        final migrator = DocumentMigrator(
          {
            // 1→2 が無いのに current=3
            2: (d) => d,
          },
          currentVersion: 3,
        );

        expect(
          () => migrator.migrate({'schemaVersion': 1}),
          throwsStateError,
        );
      });

      test('schemaVersion が不正型（文字列）でも v1 扱いで落ちない', () {
        final migrator = DocumentMigrator(
          {
            1: (d) => {...d, 'migrated': true},
          },
          currentVersion: 2,
        );

        final result = migrator.migrate({'schemaVersion': 'oops'});

        expect(result['migrated'], true);
        expect(result['schemaVersion'], 2);
      });
    });
  });
}
