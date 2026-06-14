// VehicleHistorySharingScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows vehicle name in title
//     2. Shows add-permission button
//   Empty state:
//     3. Shows 'まだ共有していません' when no permissions
//   List state:
//     4. Shows shop IDs when permissions exist
//     5. Shows revoke button per item
//   Revoke flow:
//     6. Tapping revoke button shows confirmation dialog
//     7. Tapping キャンセル dismisses dialog
//     8. Tapping 解除する calls revokePermission
//   Error state:
//     9. Shows error message on load failure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/screens/vehicle/vehicle_history_sharing_screen.dart';
import 'package:trust_car_platform/services/vehicle_history_sharing_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockSharingService implements VehicleHistorySharingService {
  final List<String> shopIds;
  final AppError? loadError;
  bool revokeCalled = false;
  String? revokedShopId;

  _MockSharingService({this.shopIds = const [], this.loadError});

  @override
  Future<Result<List<String>, AppError>> getPermittedShops({
    required String vehicleId,
  }) async {
    if (loadError != null) return Result.failure(loadError!);
    return Result.success(shopIds);
  }

  @override
  Future<Result<void, AppError>> revokePermission({
    required String vehicleId,
    required String shopId,
    required String ownerId,
  }) async {
    revokeCalled = true;
    revokedShopId = shopId;
    return const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> grantPermission({
    required String vehicleId,
    required String shopId,
    required String ownerId,
    DateTime? expiresAt,
  }) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen(_MockSharingService mock, {String vehicleName = 'マイカー'}) {
  sl.override<VehicleHistorySharingService>(mock);
  return MaterialApp(
    home: VehicleHistorySharingScreen(
      vehicleId: 'v1',
      ownerId: 'user1',
      vehicleName: vehicleName,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('VehicleHistorySharingScreen — AppBar', () {
    testWidgets('1. 車両名がタイトルに表示される', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockSharingService(), vehicleName: 'プリウス'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('プリウス'), findsOneWidget);
    });

    testWidgets('2. 追加ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSharingService()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('add_sharing_btn')), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleHistorySharingScreen — Empty state', () {
    testWidgets('3. 共有なし時は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSharingService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('まだ共有していません'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleHistorySharingScreen — List state', () {
    testWidgets('4. ショップIDが一覧表示される', (tester) async {
      final mock = _MockSharingService(shopIds: ['shop-A', 'shop-B']);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('shop-A'), findsOneWidget);
      expect(find.text('shop-B'), findsOneWidget);
    });

    testWidgets('5. 各アイテムに解除ボタンが表示される', (tester) async {
      final mock = _MockSharingService(shopIds: ['shop-A', 'shop-B']);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.block_outlined), findsNWidgets(2));
    });
  });

  // =========================================================================
  group('VehicleHistorySharingScreen — Revoke flow', () {
    testWidgets('6. 解除ボタンタップで確認ダイアログが表示される', (tester) async {
      final mock = _MockSharingService(shopIds: ['shop-X']);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('共有を解除しますか?'), findsOneWidget);
    });

    testWidgets('7. キャンセルでダイアログが閉じる', (tester) async {
      final mock = _MockSharingService(shopIds: ['shop-X']);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('共有を解除しますか?'), findsNothing);
      expect(mock.revokeCalled, isFalse);
    });

    testWidgets('8. 解除するをタップするとrevokePermissionが呼ばれる', (tester) async {
      final mock = _MockSharingService(shopIds: ['shop-X']);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除する'));
      await tester.pumpAndSettle();

      expect(mock.revokeCalled, isTrue);
      expect(mock.revokedShopId, 'shop-X');
    });
  });

  // =========================================================================
  group('VehicleHistorySharingScreen — Error state', () {
    testWidgets('9. ロードエラー時はエラーメッセージが表示される', (tester) async {
      final mock = _MockSharingService(
        loadError: AppError.server('load failed'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('サーバーエラーが発生しました'), findsOneWidget);
    });
  });
}
