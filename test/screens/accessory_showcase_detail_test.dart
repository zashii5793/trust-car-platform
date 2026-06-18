import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/screens/accessories/accessory_showcase_screen.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';

/// #13: 一覧アイテムをタップしても無反応だった不具合の回帰防止。
/// タップ→詳細シート（投稿写真・レビュー一覧）が開くことを検証する。
void main() {
  late FakeFirebaseFirestore fs;

  Future<void> seedShowcase({
    required String id,
    required String itemName,
    String? review,
  }) async {
    await fs.collection('accessory_showcases').doc(id).set({
      'userId': 'u1',
      'category': 'electronics',
      'itemName': itemName,
      'brand': 'Vantrue',
      'priceApprox': 15000,
      'rating': 5,
      'imageUrls': <String>[],
      'review': review,
      'helpfulCount': 0,
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
    });
  }

  setUp(() async {
    fs = FakeFirebaseFirestore();
    await seedShowcase(id: 's1', itemName: 'Vantrue N2 Pro', review: '夜間も鮮明で満足');
    await seedShowcase(id: 's2', itemName: 'Vantrue N2 Pro', review: '取り付けが簡単');
    if (sl.isRegistered<PopularAccessoriesService>()) {
      sl.unregister<PopularAccessoriesService>();
    }
    sl.registerSingleton<PopularAccessoriesService>(
      PopularAccessoriesService(firestore: fs),
    );
  });

  tearDown(() {
    if (sl.isRegistered<PopularAccessoriesService>()) {
      sl.unregister<PopularAccessoriesService>();
    }
  });

  testWidgets('一覧のトレンドカードをタップすると詳細シートが開く', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccessoryShowcaseScreen()),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('trend_card_Vantrue N2 Pro'));
    expect(card, findsOneWidget);

    await tester.tap(card.first);
    await tester.pumpAndSettle();

    expect(find.text('みんなの投稿'), findsOneWidget);
    expect(find.text('夜間も鮮明で満足'), findsOneWidget);
    expect(find.text('取り付けが簡単'), findsOneWidget);
  });
}
