import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/safety_tip.dart';
import 'package:trust_car_platform/services/safety_tip_service.dart';

void main() {
  group('SafetyTipService', () {
    late FakeFirebaseFirestore firestore;
    late SafetyTipService service;
    final now = DateTime(2026, 1, 1);

    SafetyTip buildTip({
      String id = 'tip-1',
      String title = 'シートベルトを正しく着用する',
      SafetyTipCategory category = SafetyTipCategory.drivingBasics,
      SafetyTipSource source = SafetyTipSource.jaf,
      String sourceUrl = 'https://jaf.or.jp/common/safety-drive',
      bool isActive = true,
    }) =>
        SafetyTip(
          id: id,
          title: title,
          body: '全席シートベルト着用は法令で定められています。',
          category: category,
          source: source,
          sourceUrl: sourceUrl,
          isActive: isActive,
          publishedAt: now,
        );

    Future<void> seedTip(SafetyTip tip) async {
      await firestore.collection('safety_tips').doc(tip.id).set(tip.toMap());
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = SafetyTipService(firestore: firestore);
    });

    // -------------------------------------------------------------------------
    // SafetyTip model
    // -------------------------------------------------------------------------
    group('SafetyTip model', () {
      test('disclaimerが空でないこと（法的要件）', () {
        expect(SafetyTip.disclaimer, isNotEmpty);
        expect(SafetyTip.disclaimer.length, greaterThan(20));
      });

      test('fromFirestore → toMap のラウンドトリップが成功する', () async {
        final tip = buildTip();
        await seedTip(tip);

        final doc = await firestore.collection('safety_tips').doc(tip.id).get();
        final restored = SafetyTip.fromFirestore(doc);

        expect(restored.title, tip.title);
        expect(restored.category, tip.category);
        expect(restored.source, tip.source);
        expect(restored.sourceUrl, tip.sourceUrl);
      });
    });

    // -------------------------------------------------------------------------
    // addTip (platform admin only)
    // -------------------------------------------------------------------------
    group('addTip', () {
      test('正常系: プラットフォーム管理者がヒントを追加できる', () async {
        final result = await service.addTip(
          title: '雨天時の車間距離を2倍に保つ',
          body: '雨天時は制動距離が2〜3倍になります。',
          category: SafetyTipCategory.seasonalDriving,
          source: SafetyTipSource.npa,
          sourceUrl: 'https://www.npa.go.jp/bureau/traffic/anzen/',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore
            .collection('safety_tips')
            .doc(result.valueOrNull!)
            .get();
        expect(doc.data()!['source'], 'npa');
      });

      group('Edge Cases', () {
        test('空のtitleはバリデーションエラー', () async {
          final result = await service.addTip(
            title: '',
            body: '内容',
            category: SafetyTipCategory.drivingBasics,
            source: SafetyTipSource.jaf,
            sourceUrl: 'https://jaf.or.jp',
          );
          expect(result.isFailure, isTrue);
        });

        test('空のsourceUrlはバリデーションエラー（公式ソース必須）', () async {
          final result = await service.addTip(
            title: 'タイトル',
            body: '内容',
            category: SafetyTipCategory.drivingBasics,
            source: SafetyTipSource.jaf,
            sourceUrl: '',
          );
          expect(result.isFailure, isTrue);
        });

        test('httpsでないsourceUrlはバリデーションエラー', () async {
          final result = await service.addTip(
            title: 'タイトル',
            body: '内容',
            category: SafetyTipCategory.drivingBasics,
            source: SafetyTipSource.jaf,
            sourceUrl: 'http://insecure.example.com', // Not HTTPS
          );
          expect(result.isFailure, isTrue);
        });

        test('空のbodyはバリデーションエラー', () async {
          final result = await service.addTip(
            title: 'タイトル',
            body: '',
            category: SafetyTipCategory.drivingBasics,
            source: SafetyTipSource.jaf,
            sourceUrl: 'https://jaf.or.jp',
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // getTips
    // -------------------------------------------------------------------------
    group('getTips', () {
      test('正常系: アクティブなヒントのみ取得される', () async {
        await seedTip(buildTip(id: 'active-1'));
        await seedTip(buildTip(id: 'active-2', title: '別のヒント'));
        await seedTip(buildTip(id: 'inactive-1', isActive: false));

        final result = await service.getTips();
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(2));
        expect(result.valueOrNull!.every((t) => t.isActive), isTrue);
      });

      test('正常系: カテゴリでフィルタできる', () async {
        await seedTip(buildTip(
            id: 'seasonal-1',
            category: SafetyTipCategory.seasonalDriving,
            title: '雪道の運転'));
        await seedTip(buildTip(
            id: 'basic-1',
            category: SafetyTipCategory.drivingBasics,
            title: '基本'));

        final result =
            await service.getTips(category: SafetyTipCategory.seasonalDriving);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(1));
        expect(result.valueOrNull!.first.title, '雪道の運転');
      });

      test('正常系: ヒントゼロでも空リスト', () async {
        final result = await service.getTips();
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });

      test('正常系: ソース別フィルタできる', () async {
        await seedTip(buildTip(
            id: 'jaf-1', source: SafetyTipSource.jaf, title: 'JAFヒント'));
        await seedTip(
            buildTip(id: 'npa-1', source: SafetyTipSource.npa, title: '警察ヒント'));

        final result = await service.getTips(source: SafetyTipSource.npa);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(1));
        expect(result.valueOrNull!.first.source, SafetyTipSource.npa);
      });
    });

    // -------------------------------------------------------------------------
    // getById
    // -------------------------------------------------------------------------
    group('getById', () {
      test('正常系: IDでヒントを取得できる', () async {
        await seedTip(buildTip());
        final result = await service.getById('tip-1');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.id, 'tip-1');
      });

      test('異常系: 存在しないIDはnotFoundエラー', () async {
        final result = await service.getById('ghost');
        expect(result.isFailure, isTrue);
      });
    });
  });
}
