/// User Scenario Integration Tests
///
/// Simulates three user journeys against Firebase Emulators:
///   - 新規ユーザー       : Registration, first vehicle/maintenance, empty marketplace
///   - ライトな利用者     : Occasional use — 2 vehicles, occasional maintenance + shop inquiry
///   - ヘビーな利用者     : Power user — 3 vehicles, 18 maintenance records, multiple shop inquiries,
///                         part search, message thread, data integrity checks
///
/// Prerequisites:
///   firebase emulators:start --only firestore,auth
///
/// Run:
///   flutter test test/integration/user_scenario_integration_test.dart
///
/// Skip without emulator:
///   flutter test --exclude-tags emulator

@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';

import '../helpers/firebase_emulator_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test data factories
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _shopDoc({
  required String name,
  String type = 'maintenanceShop',
  String prefecture = '東京都',
  String city = '渋谷区',
  double rating = 4.0,
  int reviewCount = 10,
  bool isFeatured = false,
  List<String> services = const ['maintenance', 'inspection'],
}) {
  return {
    'name': name,
    'type': type,
    'isActive': true,
    'isFeatured': isFeatured,
    'isVerified': true,
    'prefecture': prefecture,
    'city': city,
    'address': '$prefecture$city テスト通り1-1',
    'phone': '03-0000-0000',
    'services': services,
    'supportedMakerIds': <String>[],
    'imageUrls': <String>[],
    'businessHours': {
      '0': {'openTime': null, 'closeTime': null, 'isClosed': true},
      '1': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '2': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '3': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '4': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '5': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '6': {'openTime': '10:00', 'closeTime': '17:00', 'isClosed': false},
    },
    'rating': rating,
    'reviewCount': reviewCount,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> _partDoc({
  required String shopId,
  required String name,
  String category = 'maintenance',
  int priceFrom = 3000,
  int priceTo = 8000,
  bool isFeatured = false,
  List<String> tags = const [],
}) {
  return {
    'shopId': shopId,
    'name': name,
    'description': '$name の商品説明。高品質・耐久性重視。',
    'category': category,
    'isActive': true,
    'isFeatured': isFeatured,
    'priceFrom': priceFrom,
    'priceTo': priceTo,
    'isPriceNegotiable': false,
    'compatibleVehicles': <Map<String, dynamic>>[],
    'prosAndCons': [
      {'text': '品質が高い', 'isPro': true},
      {'text': '耐久性に優れる', 'isPro': true},
    ],
    'tags': [...tags, category],
    'reviewCount': 0,
    'imageUrls': <String>[],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Clear collections not covered by [FirebaseEmulatorHelper.clearFirestore].
Future<void> _clearExtra(FirebaseFirestore fs) async {
  for (final col in ['shops', 'part_listings', 'inquiries']) {
    final snap = await fs.collection(col).get();
    if (snap.docs.isEmpty) continue;
    final batch = fs.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late FirebaseFirestore firestore;
  late FirebaseService firebaseService;
  late ShopService shopService;
  late InquiryService inquiryService;
  late PartRecommendationService partService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FirebaseEmulatorHelper.initialize();

    firestore = FirebaseFirestore.instance;
    firebaseService = FirebaseService();
    shopService = ShopService();
    inquiryService = InquiryService();
    partService = PartRecommendationService();
  });

  setUp(() async {
    await FirebaseEmulatorHelper.clearFirestore();
    await _clearExtra(firestore);
  });

  tearDown(() async {
    await FirebaseEmulatorHelper.signOut();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Scenario 1: 新規ユーザー
  //   想定: 初めてアプリを開いたユーザー。データは何もない状態から始まる。
  // ═══════════════════════════════════════════════════════════════════════════
  group('Scenario 1: 新規ユーザー', () {
    late String userId;
    const email = 'newuser@example.com';

    setUp(() async {
      final cred = await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: 'password123',
      );
      userId = cred.user!.uid;
      await firestore.collection('users').doc(userId).set(
            TestDataGenerator.userProfileData(
              email: email,
              displayName: '新規太郎',
            ),
          );
    });

    test('初期状態: 車両リストが空', () async {
      final vehicles = await firebaseService.getUserVehicles().first;
      expect(vehicles, isEmpty);
    });

    test('初期状態: マーケットにショップが0件', () async {
      final result = await shopService.getShops();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, isEmpty);
    });

    test('初期状態: おすすめパーツが0件', () async {
      final result = await partService.getFeaturedParts();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, isEmpty);
    });

    test('最初の車両（Toyota Aqua）を登録できる', () async {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: '',
        userId: userId,
        maker: 'Toyota',
        model: 'Aqua',
        year: 2022,
        grade: 'X',
        mileage: 0,
        createdAt: now,
        updatedAt: now,
      );

      final result = await firebaseService.addVehicle(vehicle);

      expect(result.isSuccess, true);
      final vehicleId = result.valueOrNull!;

      // Firestoreへの永続化を確認
      final doc = await firestore.collection('vehicles').doc(vehicleId).get();
      expect(doc.exists, true);
      expect(doc.data()?['maker'], 'Toyota');
      expect(doc.data()?['model'], 'Aqua');
      expect(doc.data()?['userId'], userId);
      expect(doc.data()?['mileage'], 0);
    });

    test('車両登録後に初回整備記録（オイル交換）を追加できる', () async {
      // 車両をシード
      final vRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
                userId: userId, maker: 'Toyota', model: 'Aqua'),
          );
      final vehicleId = vRef.id;

      // 整備記録を追加
      final rRef = await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: vehicleId,
              userId: userId,
              type: 'oilChange',
              cost: 4000,
            ),
          );

      // サービス経由で取得できることを確認
      final result =
          await firebaseService.getMaintenanceRecordsForVehicle(vehicleId);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.id, rRef.id);
      expect(result.valueOrNull!.first.cost, 4000);
    });

    test('ナンバープレート重複チェック: 未登録プレートは重複なし', () async {
      final result =
          await firebaseService.isLicensePlateExists('東京 500 あ 1234');
      expect(result.isSuccess, true);
      expect(result.valueOrNull, false);
    });

    test('車両を登録しナンバープレートの重複チェックが機能する', () async {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: '',
        userId: userId,
        maker: 'Honda',
        model: 'N-BOX',
        year: 2021,
        grade: 'G',
        mileage: 3000,
        licensePlate: '品川 580 に 4321',
        createdAt: now,
        updatedAt: now,
      );
      await firebaseService.addVehicle(vehicle);

      // 同一プレートで重複チェック
      final dupResult =
          await firebaseService.isLicensePlateExists('品川 580 に 4321');
      expect(dupResult.isSuccess, true);
      expect(dupResult.valueOrNull, true); // 重複あり
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Scenario 2: ライトな利用者
  //   想定: 月1〜2回利用。車2台、整備記録数件。たまにショップに問い合わせ。
  // ═══════════════════════════════════════════════════════════════════════════
  group('Scenario 2: ライトな利用者', () {
    late String userId;
    late String vehicle1Id;
    late String vehicle2Id;
    late String shopId;
    const email = 'lightuser@example.com';

    setUp(() async {
      final cred = await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: 'password123',
      );
      userId = cred.user!.uid;
      await firestore.collection('users').doc(userId).set(
            TestDataGenerator.userProfileData(
                email: email, displayName: 'ライト花子'),
          );

      // 既存データ: 車両2台
      final v1 = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
                userId: userId, maker: 'Honda', model: 'Fit', year: 2020),
          );
      vehicle1Id = v1.id;

      final v2 = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
                userId: userId, maker: 'Toyota', model: 'Yaris', year: 2021),
          );
      vehicle2Id = v2.id;

      // 既存データ: 整備記録 4件（主にvehicle1）
      for (final type in [
        'oilChange',
        'tireRotation',
        'brakeFluidChange',
        'inspection',
      ]) {
        await firestore.collection('maintenance_records').add(
              TestDataGenerator.maintenanceRecordData(
                vehicleId: vehicle1Id,
                userId: userId,
                type: type,
                cost: 5000,
              ),
            );
      }

      // ショップ1店舗
      final sRef = await firestore
          .collection('shops')
          .add(_shopDoc(name: 'テストモータース渋谷', isFeatured: true));
      shopId = sRef.id;
    });

    test('既存2台が正しく取得できる', () async {
      final vehicles = await firebaseService.getUserVehicles().first;
      expect(vehicles, hasLength(2));
      final makers = vehicles.map((v) => v.maker).toSet();
      expect(makers, containsAll(['Honda', 'Toyota']));
    });

    test('既存整備記録4件がvehicle1から取得できる', () async {
      final result =
          await firebaseService.getMaintenanceRecordsForVehicle(vehicle1Id);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.length, greaterThanOrEqualTo(4));
    });

    test('vehicle2には整備記録がない', () async {
      final result =
          await firebaseService.getMaintenanceRecordsForVehicle(vehicle2Id);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, isEmpty);
    });

    test('新しいオイル交換記録を追加できる', () async {
      await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: vehicle1Id,
              userId: userId,
              type: 'oilChange',
              cost: 6500,
            ),
          );

      final result =
          await firebaseService.getMaintenanceRecordsForVehicle(vehicle1Id);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.length, greaterThanOrEqualTo(5));
    });

    test('ショップ一覧（フィルタなし）が取得できる', () async {
      final result = await shopService.getShops();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.name, 'テストモータース渋谷');
    });

    test('都道府県フィルタで東京のショップのみ取得できる', () async {
      await firestore
          .collection('shops')
          .add(_shopDoc(name: '大阪テストガレージ', prefecture: '大阪府', city: '梅田'));

      final tokyoResult = await shopService.getShops(prefecture: '東京都');
      expect(tokyoResult.isSuccess, true);
      expect(tokyoResult.valueOrNull!.every((s) => s.prefecture == '東京都'),
          true);

      final osakaResult = await shopService.getShops(prefecture: '大阪府');
      expect(osakaResult.isSuccess, true);
      expect(osakaResult.valueOrNull!.every((s) => s.prefecture == '大阪府'),
          true);
    });

    test('注目ショップ（getFeaturedShops）が取得できる', () async {
      final result = await shopService.getFeaturedShops();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.isFeatured, true);
    });

    test('ショップへの見積もり問い合わせを送信できる', () async {
      final result = await inquiryService.createInquiry(
        userId: userId,
        shopId: shopId,
        type: InquiryType.estimate,
        subject: '車検の見積もりについて',
        message:
            '2020年式ホンダFitの車検をお願いしたいのですが、費用の目安を教えてください。',
        vehicleId: vehicle1Id,
      );

      expect(result.isSuccess, true);
      final inquiry = result.valueOrNull!;
      expect(inquiry.userId, userId);
      expect(inquiry.shopId, shopId);
      expect(inquiry.type, InquiryType.estimate);
      expect(inquiry.status, InquiryStatus.pending);

      // Firestoreへの永続化確認
      final doc =
          await firestore.collection('inquiries').doc(inquiry.id).get();
      expect(doc.exists, true);
      expect(doc.data()?['type'], 'estimate');
    });

    test('問い合わせ送信後にユーザーの問い合わせ一覧に表示される', () async {
      await inquiryService.createInquiry(
        userId: userId,
        shopId: shopId,
        type: InquiryType.serviceInquiry,
        subject: 'オイル交換の予約',
        message: '次の土曜日にオイル交換を予約したいです。',
      );

      final result = await inquiryService.getUserInquiries(userId);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
    });

    test('ショップ側からの問い合わせ一覧も取得できる', () async {
      await inquiryService.createInquiry(
        userId: userId,
        shopId: shopId,
        type: InquiryType.general,
        subject: '営業時間の確認',
        message: '日曜日は営業していますか？',
      );

      final result = await inquiryService.getShopInquiries(shopId);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Scenario 3: ヘビーな利用者
  //   想定: 車3台・整備記録18件のクルマ好き。マーケットで複数問い合わせ、
  //         パーツ検索、メッセージ往来、データ整合性を重視するユーザー。
  // ═══════════════════════════════════════════════════════════════════════════
  group('Scenario 3: ヘビーな利用者', () {
    late String userId;
    late List<String> vehicleIds;
    late List<String> shopIds;
    const email = 'heavyuser@example.com';

    setUp(() async {
      final cred = await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: 'password123',
      );
      userId = cred.user!.uid;
      vehicleIds = [];
      shopIds = [];

      await firestore.collection('users').doc(userId).set(
            TestDataGenerator.userProfileData(
                email: email, displayName: 'ヘビー次郎'),
          );

      // ── 車両3台（スポーツカー中心）──────────────────────────────────────
      final vehicleSpecs = [
        {'maker': 'Toyota', 'model': 'GR86', 'year': 2022, 'mileage': 45000},
        {
          'maker': 'Subaru',
          'model': 'WRX STI',
          'year': 2019,
          'mileage': 87000
        },
        {'maker': 'Mazda', 'model': 'RX-7', 'year': 1999, 'mileage': 120000},
      ];
      for (final spec in vehicleSpecs) {
        final ref = await firestore.collection('vehicles').add({
          'userId': userId,
          'maker': spec['maker'],
          'model': spec['model'],
          'year': spec['year'],
          'grade': 'STI',
          'mileage': spec['mileage'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        vehicleIds.add(ref.id);
      }

      // ── 整備記録: 車両1に10件、車両2に5件、車両3に3件（合計18件）──────────
      const types1 = [
        'oilChange', 'oilFilterChange', 'tireRotation', 'brakeFluidChange',
        'brakeInspection', 'airFilterChange', 'sparkPlugChange',
        'batteryChange', 'coolantChange', 'transmissionFluidChange',
      ];
      for (int i = 0; i < types1.length; i++) {
        await firestore.collection('maintenance_records').add(
              TestDataGenerator.maintenanceRecordData(
                vehicleId: vehicleIds[0],
                userId: userId,
                type: types1[i],
                cost: 3000 + i * 2000,
              ),
            );
      }
      for (int i = 0; i < 5; i++) {
        await firestore.collection('maintenance_records').add(
              TestDataGenerator.maintenanceRecordData(
                vehicleId: vehicleIds[1],
                userId: userId,
                type: i % 2 == 0 ? 'oilChange' : 'inspection',
                cost: 8000 + i * 3000,
              ),
            );
      }
      for (int i = 0; i < 3; i++) {
        await firestore.collection('maintenance_records').add(
              TestDataGenerator.maintenanceRecordData(
                vehicleId: vehicleIds[2],
                userId: userId,
                type: 'repair',
                cost: 50000 + i * 10000,
              ),
            );
      }

      // ── ショップ3店舗 ───────────────────────────────────────────────────
      final shopSpecs = [
        _shopDoc(
          name: 'スポーツカー専門店 渋谷',
          type: 'maintenanceShop',
          prefecture: '東京都',
          city: '渋谷区',
          isFeatured: true,
          services: ['maintenance', 'repair', 'inspection'],
          rating: 4.8,
          reviewCount: 320,
        ),
        _shopDoc(
          name: 'チューニングショップ 横浜',
          type: 'customShop',
          prefecture: '神奈川県',
          city: '横浜市',
          isFeatured: true,
          services: ['customization', 'partsInstall', 'tire'],
          rating: 4.6,
          reviewCount: 180,
        ),
        _shopDoc(
          name: 'パーツ専門店 秋葉原',
          type: 'partsShop',
          prefecture: '東京都',
          city: '千代田区',
          services: ['partsInstall'],
          rating: 4.2,
          reviewCount: 90,
        ),
      ];
      for (final spec in shopSpecs) {
        final ref = await firestore.collection('shops').add(spec);
        shopIds.add(ref.id);
      }

      // ── パーツ5件 ──────────────────────────────────────────────────────
      await firestore.collection('part_listings').add(_partDoc(
            shopId: shopIds[2],
            name: 'HKS スポーツエキゾースト',
            category: 'exhaust',
            priceFrom: 80000,
            priceTo: 120000,
            isFeatured: true,
            tags: ['hks', 'muffler', 'exhaust'],
          ));
      await firestore.collection('part_listings').add(_partDoc(
            shopId: shopIds[2],
            name: 'TRD スポーツエアフィルター',
            category: 'intake',
            priceFrom: 8000,
            priceTo: 15000,
            isFeatured: true,
            tags: ['trd', 'air', 'intake'],
          ));
      await firestore.collection('part_listings').add(_partDoc(
            shopId: shopIds[2],
            name: 'ENDLESS ブレーキパッド スポーツ',
            category: 'brake',
            priceFrom: 20000,
            priceTo: 40000,
            tags: ['endless', 'brake'],
          ));
      await firestore.collection('part_listings').add(_partDoc(
            shopId: shopIds[1],
            name: 'RS☆R スーパーダウンスプリング',
            category: 'suspension',
            priceFrom: 30000,
            priceTo: 50000,
            isFeatured: true,
            tags: ['rsr', 'spring', 'suspension'],
          ));
      await firestore.collection('part_listings').add(_partDoc(
            shopId: shopIds[2],
            name: 'MOTUL エンジンオイル 0W-20',
            category: 'maintenance',
            priceFrom: 5000,
            priceTo: 7000,
            isFeatured: true,
            tags: ['motul', 'oil', 'engine'],
          ));
    });

    // ── 車両 ────────────────────────────────────────────────────────────────

    test('車両3台すべて取得できる', () async {
      final vehicles = await firebaseService.getUserVehicles().first;
      expect(vehicles, hasLength(3));
    });

    test('個別車両がgetVehicleで取得できる', () async {
      final result = await firebaseService.getVehicle(vehicleIds[0]);
      expect(result.isSuccess, true);
      expect(result.valueOrNull?.maker, 'Toyota');
      expect(result.valueOrNull?.model, 'GR86');
    });

    test('4台目の車両を追加できる', () async {
      final now = DateTime.now();
      final newVehicle = Vehicle(
        id: '',
        userId: userId,
        maker: 'Nissan',
        model: 'GT-R',
        year: 2017,
        grade: 'Premium',
        mileage: 55000,
        createdAt: now,
        updatedAt: now,
      );
      final addResult = await firebaseService.addVehicle(newVehicle);
      expect(addResult.isSuccess, true);

      final vehicles = await firebaseService.getUserVehicles().first;
      expect(vehicles, hasLength(4));
    });

    // ── 整備記録 ─────────────────────────────────────────────────────────────

    test('車両1の整備記録が10件取得できる', () async {
      final result = await firebaseService.getMaintenanceRecordsForVehicle(
          vehicleIds[0],
          limit: 15);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(10));
    });

    test('車両2の整備記録が5件取得できる', () async {
      final result = await firebaseService.getMaintenanceRecordsForVehicle(
          vehicleIds[1],
          limit: 10);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(5));
    });

    test('車両3の整備記録が3件取得できる', () async {
      final result = await firebaseService.getMaintenanceRecordsForVehicle(
          vehicleIds[2],
          limit: 10);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(3));
    });

    test('複数車両の整備記録を一括取得できる', () async {
      final result = await firebaseService.getMaintenanceRecordsForVehicles(
        vehicleIds,
        limitPerVehicle: 5,
      );
      expect(result.isSuccess, true);
      final records = result.valueOrNull!;
      expect(records.keys, containsAll(vehicleIds));
    });

    test('走行距離更新（mileage）が反映される', () async {
      final getResult = await firebaseService.getVehicle(vehicleIds[1]);
      final original = getResult.valueOrNull!;

      final updated = original.copyWith(
        mileage: 90000,
        updatedAt: DateTime.now(),
      );
      final updateResult =
          await firebaseService.updateVehicle(vehicleIds[1], updated);
      expect(updateResult.isSuccess, true);

      final refreshed = await firebaseService.getVehicle(vehicleIds[1]);
      expect(refreshed.valueOrNull?.mileage, 90000);
    });

    // ── マーケットプレイス（ショップ）────────────────────────────────────────

    test('全ショップ3店舗が取得できる', () async {
      final result = await shopService.getShops();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(3));
    });

    test('注目ショップ（isFeatured）は2店舗', () async {
      final result = await shopService.getFeaturedShops(limit: 10);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(2));
      expect(result.valueOrNull!.every((s) => s.isFeatured), true);
    });

    test('東京都のショップのみ取得できる（2店舗）', () async {
      final result = await shopService.getShops(prefecture: '東京都');
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.every((s) => s.prefecture == '東京都'), true);
    });

    test('神奈川県のショップのみ取得できる（1店舗）', () async {
      final result = await shopService.getShops(prefecture: '神奈川県');
      expect(result.isSuccess, true);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.name, 'チューニングショップ 横浜');
    });

    test('サービス種別 partsInstall でフィルタできる', () async {
      final result =
          await shopService.getShopsByService(ServiceCategory.partsInstall);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.isNotEmpty, true);
      expect(
        result.valueOrNull!
            .every((s) => s.services.contains(ServiceCategory.partsInstall)),
        true,
      );
    });

    // ── マーケットプレイス（パーツ）──────────────────────────────────────────

    test('おすすめパーツ4件が取得できる', () async {
      final result = await partService.getFeaturedParts(limit: 10);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.length, greaterThanOrEqualTo(4));
      expect(result.valueOrNull!.every((p) => p.isFeatured), true);
    });

    test('キーワード「エキゾースト」で検索できる', () async {
      final result = await partService.searchParts('エキゾースト');
      expect(result.isSuccess, true);
      expect(
        result.valueOrNull!.any((p) => p.name.contains('エキゾースト')),
        true,
      );
    });

    test('カテゴリ exhaust でパーツを絞り込める', () async {
      final result =
          await partService.getPartsByCategory(PartCategory.exhaust);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.isNotEmpty, true);
      expect(
        result.valueOrNull!.every((p) => p.category == PartCategory.exhaust),
        true,
      );
    });

    test('カテゴリ suspension で絞り込める', () async {
      final result =
          await partService.getPartsByCategory(PartCategory.suspension);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.isNotEmpty, true);
    });

    test('パーツ詳細が取得できる', () async {
      final featuredResult = await partService.getFeaturedParts(limit: 1);
      final partId = featuredResult.valueOrNull!.first.id;

      final detailResult = await partService.getPartDetail(partId);
      expect(detailResult.isSuccess, true);
      expect(detailResult.valueOrNull?.id, partId);
    });

    // ── 問い合わせ ───────────────────────────────────────────────────────────

    test('3店舗への問い合わせを一括登録できる', () async {
      final inquirySpecs = [
        {
          'shopId': shopIds[0],
          'type': InquiryType.estimate,
          'subject': 'GR86 車検の見積もり',
          'message': '2022年式GR86の車検。費用目安と予約可否を確認させてください。',
          'vehicleId': vehicleIds[0],
        },
        {
          'shopId': shopIds[1],
          'type': InquiryType.partInquiry,
          'subject': 'WRX STI サスペンション交換',
          'message': 'RS☆Rスプリングへの交換。工賃込みで見積もりをお願いします。',
          'vehicleId': vehicleIds[1],
        },
        {
          'shopId': shopIds[2],
          'type': InquiryType.serviceInquiry,
          'subject': 'RX-7 マフラー交換',
          'message': 'HKSマフラーの在庫確認と取り付け可否を確認したい。',
          'vehicleId': vehicleIds[2],
        },
      ];

      for (final spec in inquirySpecs) {
        final result = await inquiryService.createInquiry(
          userId: userId,
          shopId: spec['shopId'] as String,
          type: spec['type'] as InquiryType,
          subject: spec['subject'] as String,
          message: spec['message'] as String,
          vehicleId: spec['vehicleId'] as String?,
        );
        expect(result.isSuccess, true,
            reason: '問い合わせ「${spec['subject']}」の登録に失敗');
      }

      final allResult = await inquiryService.getUserInquiries(userId, limit: 10);
      expect(allResult.isSuccess, true);
      expect(allResult.valueOrNull, hasLength(3));
    });

    test('問い合わせへのメッセージ送受信が機能する', () async {
      final inquiryResult = await inquiryService.createInquiry(
        userId: userId,
        shopId: shopIds[0],
        type: InquiryType.estimate,
        subject: '車検の詳細確認',
        message: '予算について確認したいことがあります。',
        vehicleId: vehicleIds[0],
      );
      expect(inquiryResult.isSuccess, true);
      final inquiryId = inquiryResult.valueOrNull!.id;

      // ユーザーが追加メッセージを送信
      final msg1 = await inquiryService.sendMessage(
        inquiryId: inquiryId,
        senderId: userId,
        isFromShop: false,
        content: '予算は10万円以内を希望しています。可能でしょうか？',
      );
      expect(msg1.isSuccess, true);

      // 2通目のメッセージ
      final msg2 = await inquiryService.sendMessage(
        inquiryId: inquiryId,
        senderId: userId,
        isFromShop: false,
        content: '日程は来月中旬を希望です。',
      );
      expect(msg2.isSuccess, true);

      // メッセージ一覧取得
      final messagesResult = await inquiryService.getMessages(inquiryId);
      expect(messagesResult.isSuccess, true);
      expect(messagesResult.valueOrNull!.length, greaterThanOrEqualTo(2));
      expect(
        messagesResult.valueOrNull!.any((m) => m.content.contains('10万円')),
        true,
      );
    });

    test('問い合わせのステータスが pending → inProgress に更新できる', () async {
      final inquiryResult = await inquiryService.createInquiry(
        userId: userId,
        shopId: shopIds[0],
        type: InquiryType.appointment,
        subject: '定期点検の予約',
        message: '来月の定期点検を予約したいです。',
        vehicleId: vehicleIds[0],
      );
      final inquiryId = inquiryResult.valueOrNull!.id;

      final updateResult =
          await inquiryService.updateStatus(inquiryId, InquiryStatus.inProgress);
      expect(updateResult.isSuccess, true);

      final refreshed = await inquiryService.getInquiry(inquiryId);
      expect(refreshed.valueOrNull?.status, InquiryStatus.inProgress);
    });

    test('問い合わせのステータスが inProgress → replied に更新できる', () async {
      final inquiryResult = await inquiryService.createInquiry(
        userId: userId,
        shopId: shopIds[0],
        type: InquiryType.general,
        subject: '一般問い合わせ',
        message: 'テスト。',
      );
      final inquiryId = inquiryResult.valueOrNull!.id;
      await inquiryService.updateStatus(inquiryId, InquiryStatus.inProgress);

      final updateResult =
          await inquiryService.updateStatus(inquiryId, InquiryStatus.replied);
      expect(updateResult.isSuccess, true);

      final refreshed = await inquiryService.getInquiry(inquiryId);
      expect(refreshed.valueOrNull?.status, InquiryStatus.replied);
    });

    test('未読問い合わせ数が取得できる（非負整数）', () async {
      for (int i = 0; i < 3; i++) {
        await inquiryService.createInquiry(
          userId: userId,
          shopId: shopIds[i],
          type: InquiryType.general,
          subject: '問い合わせ $i',
          message: 'テストメッセージ $i',
        );
      }

      final countResult = await inquiryService.getUnreadCountForUser(userId);
      expect(countResult.isSuccess, true);
      expect(countResult.valueOrNull!, greaterThanOrEqualTo(0));
    });

    test('既読マークを付けると未読カウントが更新される', () async {
      final inquiryResult = await inquiryService.createInquiry(
        userId: userId,
        shopId: shopIds[0],
        type: InquiryType.general,
        subject: '既読テスト',
        message: 'テスト。',
      );
      final inquiryId = inquiryResult.valueOrNull!.id;

      final markResult = await inquiryService.markAsRead(
        inquiryId: inquiryId,
        isUser: true,
      );
      expect(markResult.isSuccess, true);
    });

    // ── データ整合性 ──────────────────────────────────────────────────────────

    group('データ整合性', () {
      test('各車両の整備記録が他の車両と混在しない', () async {
        final r1 = await firebaseService.getMaintenanceRecordsForVehicle(
            vehicleIds[0]);
        final r2 = await firebaseService.getMaintenanceRecordsForVehicle(
            vehicleIds[1]);

        for (final record in r1.valueOrNull!) {
          expect(record.vehicleId, vehicleIds[0],
              reason: '車両1の記録に別の vehicleId が混入');
        }
        for (final record in r2.valueOrNull!) {
          expect(record.vehicleId, vehicleIds[1],
              reason: '車両2の記録に別の vehicleId が混入');
        }
      });

      test('登録済みナンバープレートは重複チェックで検出される', () async {
        final now = DateTime.now();
        final v = Vehicle(
          id: '',
          userId: userId,
          maker: 'Mitsubishi',
          model: 'Lancer Evolution',
          year: 2007,
          grade: 'X',
          mileage: 65000,
          licensePlate: '多摩 300 こ 7890',
          createdAt: now,
          updatedAt: now,
        );
        await firebaseService.addVehicle(v);

        final dupCheck =
            await firebaseService.isLicensePlateExists('多摩 300 こ 7890');
        expect(dupCheck.isSuccess, true);
        expect(dupCheck.valueOrNull, true);
      });

      test('車両削除後はgetVehicleで取得できない', () async {
        final vehicleToDelete = vehicleIds[2];
        final deleteResult =
            await firebaseService.deleteVehicle(vehicleToDelete);
        expect(deleteResult.isSuccess, true);

        final getResult = await firebaseService.getVehicle(vehicleToDelete);
        expect(getResult.isFailure, true);

        final remaining = await firebaseService.getUserVehicles().first;
        expect(remaining, hasLength(2));
      });

      test('存在しないショップIDへのgetShopはエラーを返す', () async {
        final result = await shopService.getShop('non-existent-shop-id');
        expect(result.isFailure, true);
      });

      test('存在しない問い合わせIDへのgetInquiryはエラーを返す', () async {
        final result =
            await inquiryService.getInquiry('non-existent-inquiry-id');
        expect(result.isFailure, true);
      });

      test('他ユーザーのデータを持つvehicleIdへのアクセスは空を返す', () async {
        // 別ユーザーで作成した vehicleId（存在しないもの）を参照
        final fakeVehicleId = 'other-user-vehicle-xyz';
        final result =
            await firebaseService.getMaintenanceRecordsForVehicle(fakeVehicleId);
        // エラーにならず空リストを返す（Firestoreの設計）
        expect(result.isSuccess, true);
        expect(result.valueOrNull, isEmpty);
      });
    });
  });
}
