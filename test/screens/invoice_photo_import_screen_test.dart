// 請求書の写真から、過去の整備記録をまとめて移す。
// 読み取り（ML Kit）と写真の選択は差し替えている。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/vehicle/invoice_photo_import_screen.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/services/maintenance_history_import_service.dart';

final _today = DateTime(2026, 9, 28);

final _vehicle = Vehicle(
  id: 'v1',
  userId: 'u1',
  maker: 'MINI',
  model: 'クーパー',
  year: 2019,
  grade: '',
  mileage: 48000,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// 写真の名前 → 読み取り結果。null は読めなかった写真。
final _photos = <String, InvoiceData?>{
  '/p/shaken.jpg': InvoiceData(
    date: DateTime(2025, 4, 2),
    totalAmount: 132000,
    shopName: 'タカヤモーター',
    items: [InvoiceItem(name: '車検整備一式')],
  ),
  '/p/oil.jpg': InvoiceData(
    date: DateTime(2025, 10, 1),
    // 金額が読めなかった
    items: [InvoiceItem(name: 'エンジンオイル交換')],
  ),
  '/p/blurry.jpg': null,
};

void main() {
  group('InvoiceDraft.fromInvoice', () {
    test('明細の1行目を内容に、種類は推し量る', () {
      final d = InvoiceDraft.fromInvoice('a.jpg', _photos['/p/shaken.jpg']!);
      expect(d.title, '車検整備一式');
      expect(d.type, MaintenanceType.carInspection);
      expect(d.isReady(_today), isTrue);
    });

    group('Edge Cases', () {
      test('読めなかった金額は空のまま（推測で埋めない）', () {
        final d = InvoiceDraft.fromInvoice('b.jpg', _photos['/p/oil.jpg']!);
        expect(d.total, isNull);
        expect(d.isReady(_today), isFalse);
      });

      test('明細が無ければ「整備」', () {
        final d = InvoiceDraft.fromInvoice('c.jpg', InvoiceData());
        expect(d.title, '整備');
        expect(d.type, MaintenanceType.other);
      });

      test('未来の日付は取り込めない', () {
        final d = InvoiceDraft.fromInvoice(
          'd.jpg',
          InvoiceData(date: DateTime(2027, 1, 1), totalAmount: 100),
        );
        expect(d.isReady(_today), isFalse);
      });
    });
  });

  group('InvoicePhotoImportScreen', () {
    late FakeFirebaseFirestore fs;

    setUp(() => fs = FakeFirebaseFirestore());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: InvoicePhotoImportScreen(
          vehicle: _vehicle,
          userId: 'u1',
          service: MaintenanceHistoryImportService(
            firestore: fs,
            now: () => _today,
          ),
          pickPhotos: () async => _photos.keys.toList(),
          readInvoice: (path) async {
            final d = _photos[path];
            return d == null
                ? const Result.failure(AppError.unknown('読めません'))
                : Result.success(d);
          },
          today: _today,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('読めたものが並び、読めなかった写真と未入力を知らせる', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('invoice_pick')));
      await tester.pumpAndSettle();

      expect(find.text('車検整備一式（車検）'), findsOneWidget);
      expect(find.text('エンジンオイル交換（オイル交換）'), findsOneWidget);
      expect(find.textContaining('blurry.jpg'), findsOneWidget);
      expect(find.byKey(const Key('invoice_needs_input')), findsOneWidget);
      // 取り込めるのは、そろっている1件だけ
      expect(find.text('1件を移す'), findsOneWidget);
    });

    testWidgets('読めなかった金額を入れると、2件とも移せる', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('invoice_pick')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('金額を入れる'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('invoice_total_field')), '8,800');
      await tester.tap(find.byKey(const Key('invoice_total_ok')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invoice_needs_input')), findsNothing);
      await tester.tap(find.text('2件を移す'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('invoice_import_result')))
            .data,
        '2件を追加しました',
      );
      final docs = await fs.collection('maintenance_records').get();
      final costs = docs.docs.map((d) => d.data()['cost']).toSet();
      expect(costs, {132000, 8800});
      expect(docs.docs.first.data()['verificationSource'], 'selfReported');
    });

    testWidgets('チェックを外したものは移さない', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('invoice_pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('0件を移す'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ));
      expect(button.onPressed, isNull);
    });
  });
}
