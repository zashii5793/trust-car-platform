// ReleaseNotesService unit tests.
//
// The service reads bundled release notes (or an injected fixture source) and
// returns them newest-version-first. Covered behaviours:
//   1. getReleaseNotes — sorting, default bundled data
//   2. latest          — newest note / empty source
//   3. Edge cases      — empty list, malformed versions, build metadata

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/app_release_note.dart';
import 'package:trust_car_platform/services/release_notes_service.dart';

AppReleaseNote _note(String version) => AppReleaseNote(
      version: version,
      releasedAt: DateTime(2026, 1, 1),
      headline: 'headline $version',
      highlights: const [
        ReleaseHighlight(
          type: ReleaseHighlightType.feature,
          title: 'title',
          description: 'desc',
        ),
      ],
    );

void main() {
  group('getReleaseNotes', () {
    test('returns the bundled notes by default', () {
      final service = ReleaseNotesService();
      final result = service.getReleaseNotes();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNotEmpty);
      // The first bundled release leads with the product's selling point.
      expect(result.valueOrNull!.first.version, '1.0.0');
      expect(result.valueOrNull!.first.headline, contains('引き継げます'));
    });

    test('sorts notes newest version first', () {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0'), _note('1.2.0'), _note('1.1.0')],
      );

      final versions =
          service.getReleaseNotes().valueOrNull!.map((n) => n.version).toList();
      expect(versions, ['1.2.0', '1.1.0', '1.0.0']);
    });

    test('does not mutate the underlying source list', () {
      final source = [_note('1.0.0'), _note('2.0.0')];
      final service = ReleaseNotesService(source: () => source);

      service.getReleaseNotes();

      // Original order preserved; the service sorts a copy.
      expect(source.map((n) => n.version).toList(), ['1.0.0', '2.0.0']);
    });
  });

  group('latest', () {
    test('returns the newest note', () {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0'), _note('3.0.0'), _note('2.0.0')],
      );

      final result = service.latest();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.version, '3.0.0');
    });

    test('returns NotFound failure when there are no notes', () {
      final service = ReleaseNotesService(source: () => []);

      final result = service.latest();
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<NotFoundError>());
    });
  });

  group('Edge Cases', () {
    test('empty source returns an empty success list', () {
      final service = ReleaseNotesService(source: () => []);

      final result = service.getReleaseNotes();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('malformed version strings do not throw and sort deterministically',
        () {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0'), _note('abc'), _note('1.0')],
      );

      final result = service.getReleaseNotes();
      expect(result.isSuccess, isTrue);
      // 'abc' -> [0,0,0], '1.0' -> [1,0,0], '1.0.0' -> [1,0,0].
      expect(result.valueOrNull!.last.version, 'abc');
    });

    test('build metadata after "+" is ignored when comparing', () {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0+1'), _note('1.0.1+9')],
      );

      final versions =
          service.getReleaseNotes().valueOrNull!.map((n) => n.version).toList();
      expect(versions, ['1.0.1+9', '1.0.0+1']);
    });

    test('single note is returned as-is', () {
      final service = ReleaseNotesService(source: () => [_note('5.4.3')]);

      final result = service.getReleaseNotes();
      expect(result.valueOrNull!.single.version, '5.4.3');
    });
  });
}
