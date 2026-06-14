// SharedPrefsNotificationStateStore Unit Tests
//
// Uses SharedPreferences.setMockInitialValues to avoid platform channels.
// Tests: load/save read ids, load/save dismissed ids, _maxIds cap (500).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_car_platform/services/notification_state_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsNotificationStateStore', () {
    late SharedPrefsNotificationStateStore store;

    setUp(() {
      store = SharedPrefsNotificationStateStore();
    });

    group('loadReadIds', () {
      test('returns empty set when no data persisted', () async {
        final ids = await store.loadReadIds();
        expect(ids, isEmpty);
      });

      test('returns previously saved ids', () async {
        SharedPreferences.setMockInitialValues({
          'notif_read_ids': ['a', 'b', 'c'],
        });
        final ids = await store.loadReadIds();
        expect(ids, {'a', 'b', 'c'});
      });
    });

    group('saveReadIds / loadReadIds round-trip', () {
      test('persists and reloads ids', () async {
        await store.saveReadIds({'x', 'y'});
        final ids = await store.loadReadIds();
        expect(ids, containsAll(['x', 'y']));
        expect(ids.length, 2);
      });

      test('overwrites previous value', () async {
        await store.saveReadIds({'old'});
        await store.saveReadIds({'new1', 'new2'});
        final ids = await store.loadReadIds();
        expect(ids, {'new1', 'new2'});
        expect(ids.contains('old'), isFalse);
      });

      test('empty set saves and reloads as empty', () async {
        await store.saveReadIds({'some'});
        await store.saveReadIds({});
        final ids = await store.loadReadIds();
        expect(ids, isEmpty);
      });
    });

    group('loadDismissedIds', () {
      test('returns empty set when no data persisted', () async {
        final ids = await store.loadDismissedIds();
        expect(ids, isEmpty);
      });

      test('returns previously saved dismissed ids', () async {
        SharedPreferences.setMockInitialValues({
          'notif_dismissed_ids': ['d1', 'd2'],
        });
        final ids = await store.loadDismissedIds();
        expect(ids, {'d1', 'd2'});
      });
    });

    group('saveDismissedIds / loadDismissedIds round-trip', () {
      test('persists and reloads dismissed ids', () async {
        await store.saveDismissedIds({'d1', 'd2', 'd3'});
        final ids = await store.loadDismissedIds();
        expect(ids, containsAll(['d1', 'd2', 'd3']));
      });

      test('read and dismissed ids are stored independently', () async {
        await store.saveReadIds({'r1'});
        await store.saveDismissedIds({'d1'});
        expect(await store.loadReadIds(), {'r1'});
        expect(await store.loadDismissedIds(), {'d1'});
      });
    });

    group('_maxIds cap (500)', () {
      test('saving 501 ids caps to last 500', () async {
        final ids = Set<String>.from(
          List.generate(501, (i) => 'id_$i'),
        );
        await store.saveReadIds(ids);
        final loaded = await store.loadReadIds();
        expect(loaded.length, 500);
        // The last element written should be retained
        expect(loaded.contains('id_500'), isTrue);
        // The first element (oldest) should have been dropped
        expect(loaded.contains('id_0'), isFalse);
      });

      test('saving exactly 500 ids does not cap', () async {
        final ids = Set<String>.from(List.generate(500, (i) => 'id_$i'));
        await store.saveReadIds(ids);
        final loaded = await store.loadReadIds();
        expect(loaded.length, 500);
      });
    });

    group('Edge Cases', () {
      test('ids with special characters round-trip correctly', () async {
        const special = {'id/with/slashes', 'id with spaces', 'id:colon'};
        await store.saveReadIds(special);
        final loaded = await store.loadReadIds();
        expect(loaded, special);
      });

      test('very short single-char ids work', () async {
        await store.saveReadIds({'a'});
        expect(await store.loadReadIds(), {'a'});
      });
    });
  });
}
