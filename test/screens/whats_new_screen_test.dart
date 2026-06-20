// WhatsNewScreen widget tests.
//
// The screen receives a ReleaseNotesService via constructor injection (no
// ServiceLocator needed in tests). Because bundled data resolves synchronously,
// content / empty / error states are all present on the first frame.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/app_release_note.dart';
import 'package:trust_car_platform/screens/about/whats_new_screen.dart';
import 'package:trust_car_platform/services/release_notes_service.dart';

AppReleaseNote _note(String version, String headline) => AppReleaseNote(
      version: version,
      releasedAt: DateTime(2026, 6, 20),
      headline: headline,
      highlights: const [
        ReleaseHighlight(
          type: ReleaseHighlightType.feature,
          title: 'お店が変わっても履歴はそのまま',
          description: 'どの店舗でも引き継げます',
        ),
      ],
    );

Widget _wrap(ReleaseNotesService service) => MaterialApp(
      home: WhatsNewScreen(service: service),
    );

void main() {
  group('WhatsNewScreen', () {
    testWidgets('renders release note sections with the selling-point headline',
        (tester) async {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0', '車両管理情報をどの店舗でも引き継げます')],
      );

      await tester.pumpWidget(_wrap(service));
      await tester.pump();

      expect(find.text('アップデート情報'), findsOneWidget);
      expect(find.byKey(const Key('release_note_1.0.0')), findsOneWidget);
      expect(find.text('車両管理情報をどの店舗でも引き継げます'), findsOneWidget);
      expect(find.text('最新'), findsOneWidget);
      expect(find.text('新機能'), findsWidgets);
    });

    testWidgets('marks only the newest version with the 最新 badge',
        (tester) async {
      final service = ReleaseNotesService(
        source: () => [_note('1.0.0', 'old'), _note('1.1.0', 'new')],
      );

      await tester.pumpWidget(_wrap(service));
      await tester.pump();

      // Both sections render, but only one "最新" badge exists.
      expect(find.byKey(const Key('release_note_1.1.0')), findsOneWidget);
      expect(find.byKey(const Key('release_note_1.0.0')), findsOneWidget);
      expect(find.text('最新'), findsOneWidget);
    });

    testWidgets('shows empty state when there are no notes', (tester) async {
      final service = ReleaseNotesService(source: () => []);

      await tester.pumpWidget(_wrap(service));
      await tester.pump();

      expect(find.byKey(const Key('whats_new_empty')), findsOneWidget);
      expect(find.text('更新情報はまだありません'), findsOneWidget);
    });

    testWidgets('shows error state with a retry button on failure',
        (tester) async {
      final service = ReleaseNotesService(
        source: () => throw Exception('boom'),
      );

      await tester.pumpWidget(_wrap(service));
      await tester.pump();

      expect(find.byKey(const Key('whats_new_error')), findsOneWidget);
      expect(find.text('再読み込み'), findsOneWidget);
    });
  });
}
