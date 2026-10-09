// ログイン直後の振り分け（2026-10-08 使用感テスト #2）。
//
// 店主でログインしても、お客さん用の「マイカー」が出て、顧客台帳まで
// 5手かかっていた。店主・スタッフは台帳を最初に開き、お客さん用の画面へは
// 1手で行けるようにする。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/screens/shop/post_login_home.dart';
import 'package:trust_car_platform/services/shop_entry_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class _Fixed extends ShopEntryService {
  final Future<Result<ShopEntry?, AppError>> Function() answer;
  final List<String> asked = [];

  _Fixed(this.answer)
      : super(
          shopService: ShopService(firestore: FakeFirebaseFirestore()),
          staffService: ShopStaffService(firestore: FakeFirebaseFirestore()),
        );

  @override
  Future<Result<ShopEntry?, AppError>> resolve(String uid) {
    asked.add(uid);
    return answer();
  }
}

const _owner = ShopEntry(
  shopId: 'shop_a',
  shopName: 'タカヤモーター',
  isOwner: true,
  ownerUid: 'owner1',
);
const _staff = ShopEntry(
  shopId: 'shop_a',
  shopName: 'タカヤモーター',
  isOwner: false,
  ownerUid: 'owner1',
);

Widget _app(ShopEntryService? service, {Duration? timeout}) => MaterialApp(
      home: PostLoginHome(
        uid: 'u1',
        entryService: service,
        timeout: timeout ?? const Duration(seconds: 8),
        userHome: (_) => const Scaffold(body: Text('マイカー画面')),
        ledgerBuilder: (context, entry, openUserHome) => Scaffold(
          body: Column(children: [
            Text('台帳 ${entry.shopName} ${entry.isOwner ? '店主' : 'スタッフ'}'),
            TextButton(onPressed: openUserHome, child: const Text('マイカーへ')),
          ]),
        ),
      ),
    );

void main() {
  testWidgets('店主は、ログインするとまず顧客台帳が開く', (tester) async {
    final s = _Fixed(() async => const Result.success(_owner));
    await tester.pumpWidget(_app(s));
    await tester.pumpAndSettle();
    expect(find.text('台帳 タカヤモーター 店主'), findsOneWidget);
    expect(find.text('マイカー画面'), findsNothing);
    expect(s.asked, ['u1']);
  });

  testWidgets('スタッフも、まず顧客台帳が開く', (tester) async {
    await tester
        .pumpWidget(_app(_Fixed(() async => const Result.success(_staff))));
    await tester.pumpAndSettle();
    expect(find.text('台帳 タカヤモーター スタッフ'), findsOneWidget);
  });

  testWidgets('台帳から1手で、お客さん用の画面へ行けて、戻れる', (tester) async {
    await tester
        .pumpWidget(_app(_Fixed(() async => const Result.success(_owner))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('マイカーへ'));
    await tester.pumpAndSettle();
    expect(find.text('マイカー画面'), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('台帳 タカヤモーター 店主'), findsOneWidget);
  });

  testWidgets('お客さんは、今まで通りマイカー', (tester) async {
    await tester
        .pumpWidget(_app(_Fixed(() async => const Result.success(null))));
    await tester.pumpAndSettle();
    expect(find.text('マイカー画面'), findsOneWidget);
  });

  group('Edge Cases', () {
    testWidgets('確かめている間は、どちらの画面も出さない', (tester) async {
      final c = Completer<Result<ShopEntry?, AppError>>();
      await tester.pumpWidget(_app(_Fixed(() => c.future)));
      await tester.pump();
      expect(find.text('マイカー画面'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      c.complete(const Result.success(_owner));
      await tester.pumpAndSettle();
      expect(find.text('台帳 タカヤモーター 店主'), findsOneWidget);
    });

    testWidgets('読めなければ（オフラインなど）マイカーを出す（止めない）', (tester) async {
      await tester.pumpWidget(_app(_Fixed(
          () async => const Result.failure(AppError.network('offline')))));
      await tester.pumpAndSettle();
      expect(find.text('マイカー画面'), findsOneWidget);
    });

    testWidgets('返事が来なければ、待ち時間のあとマイカーを出す', (tester) async {
      final c = Completer<Result<ShopEntry?, AppError>>();
      await tester.pumpWidget(
          _app(_Fixed(() => c.future), timeout: const Duration(seconds: 2)));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('マイカー画面'), findsOneWidget);
    });

    testWidgets('振り分けの仕組みが無い環境では、マイカー', (tester) async {
      await tester.pumpWidget(_app(null));
      await tester.pumpAndSettle();
      expect(find.text('マイカー画面'), findsOneWidget);
    });
  });
}
