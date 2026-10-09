// 操作の流れを通すテスト（test/flows/）の土台。
//
// **本物の画面・本物のサービス・メモリ上の Firestore** で組む。
// 単体テストは部品ごとに正しくても、つないだときにだけ壊れる不具合
// （画面が渡す値とサービスが待つ値のズレ）を拾うための層。
//
// - Firestore は FakeFirebaseFirestore（ルールは効かない。ルールは
//   test/rules/ で別に確かめている）
// - ログインは MockFirebaseAuth。店主・スタッフ・利用者を1つのテストの中で
//   切り替えられるよう、人ごとに作る
// - エミュレータは使わないので、PR ごとの CI（flutter test）で回る

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/detail_delivery_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_detail_inbox_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

/// 店のIDの形。流れのテストは両方の形で通す（既存の店を壊さず、
/// 新しい店でも同じことができるか）。
enum ShopIdForm {
  /// これまでの形（店のID ＝ 最初の店主の uid）
  ownerUid('店のID＝店主のuid'),

  /// 新しい形（自動ID。2026-10-01 段階1）
  autoId('店のID＝自動ID');

  final String label;
  const ShopIdForm(this.label);
}

/// 流れの中の1人（店主・スタッフ・利用者）。
class FlowActor {
  final String uid;
  final String name;
  final MockFirebaseAuth auth;

  FlowActor(this.uid, this.name)
      : auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: name),
        );

  User get user => auth.currentUser!;
}

/// 1つの流れで共有する世界（Firestore は全員で1つ）。
class FlowWorld {
  final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
  final DateTime today;

  FlowWorld({DateTime? today}) : today = today ?? DateTime(2026, 9, 28);

  FirebaseService firebaseFor(FlowActor a) =>
      FirebaseService(firestore: fs, auth: a.auth);

  InquiryService inquiryFor(FlowActor a) => InquiryService(
        firestore: fs,
        auth: a.auth,
        subscriptionService: ShopSubscriptionService(firestore: fs),
      );

  /// 店を作り、店のIDを返す（docs/SHOP_ID_DECOUPLING_DESIGN.md）。
  ///
  /// - [ShopIdForm.ownerUid]: これまでの形。店のID ＝ 店主の uid で、名簿に
  ///   owner の行は無い（本番のタカヤモーターがこの形）
  /// - [ShopIdForm.autoId]: 新しい形。アプリが店を登録するときと同じ
  ///   [ShopService.createMyShop] で作る（自動ID・名簿に owner の行）
  Future<String> createShop(
    FlowActor owner,
    String name, {
    ShopIdForm form = ShopIdForm.ownerUid,
  }) async {
    switch (form) {
      case ShopIdForm.ownerUid:
        await fs.collection('shops').doc(owner.uid).set({
          'name': name,
          'ownerId': owner.uid,
          'type': 'maintenanceShop',
          'isActive': true,
          'planType': 'free',
          'createdAt': DateTime(2026),
          'updatedAt': DateTime(2026),
        });
        return owner.uid;
      case ShopIdForm.autoId:
        final created = await ShopService(firestore: fs).createMyShop(
          Shop(
            id: '',
            name: name,
            type: ShopType.maintenanceShop,
            ownerId: owner.uid,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          ownerName: owner.name,
        );
        final id = created.valueOrNull!.id;
        expect(id, isNot(owner.uid), reason: '自動IDで作られていない');
        return id;
    }
  }

  /// 利用者の車を作る。
  Future<Vehicle> createVehicle(
    FlowActor owner, {
    String maker = 'MINI',
    String model = 'クーパー',
  }) async {
    final ref = fs.collection('vehicles').doc();
    final v = Vehicle(
      id: ref.id,
      userId: owner.uid,
      maker: maker,
      model: model,
      year: 2019,
      grade: 'S',
      mileage: 48000,
      licensePlate: '品川 300 あ 12-34',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await ref.set(v.toMap());
    return v;
  }

  /// [actor] としてアプリを動かす（Provider と ServiceLocator を切り替える）。
  ///
  /// 画面の中で `sl.get<FirebaseService>()` を呼ぶところがあるので、
  /// 人を替えるたびに差し替える。
  Future<void> pumpAs(
    WidgetTester tester,
    FlowActor actor,
    Widget home, {
    Size size = const Size(900, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final firebase = firebaseFor(actor);
    sl.override<FirebaseService>(firebase);
    sl.override<ShopDetailInboxService>(
        ShopDetailInboxService(firestore: fs, now: () => today));
    sl.override<DetailDeliveryService>(DetailDeliveryService(
      firestore: fs,
      linkService: LedgerLinkService(firestore: fs, now: () => today),
      inquiryService: inquiryFor(actor),
      now: () => today,
    ));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _ActorAuthProvider(actor),
          ),
          ChangeNotifierProvider<ShopProvider>(
            create: (_) => ShopProvider(
              shopService: ShopService(firestore: fs),
              inquiryService: inquiryFor(actor),
            ),
          ),
          // 本物のアプリはホーム画面で先に車の一覧を読み込んでいる。
          // 遅延生成のままだと、最初に使う瞬間まで読み込みが始まらない。
          ChangeNotifierProvider<VehicleProvider>(
            lazy: false,
            create: (_) =>
                VehicleProvider(firebaseService: firebase)..listenToVehicles(),
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _ActorAuthProvider extends AuthProvider {
  final FlowActor actor;

  _ActorAuthProvider(this.actor) : super(authService: _NoopAuthService());

  @override
  User? get firebaseUser => actor.user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

class _NoopAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
