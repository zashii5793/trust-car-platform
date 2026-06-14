// FleetMemberScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/fleet_member.dart';
import 'package:trust_car_platform/screens/fleet/fleet_member_screen.dart';
import 'package:trust_car_platform/services/fleet_member_service.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';

// ── Stub FleetMemberService ───────────────────────────────────────────────────

class _StubFleetMemberService implements FleetMemberService {
  List<FleetMember> members;

  _StubFleetMemberService({
    this.members = const [],
  });

  @override
  Future<Result<List<FleetMember>, AppError>> getMembers(
      String companyId) async {
    return Result.success(members);
  }

  @override
  Future<Result<FleetMember, AppError>> addMember({
    required String companyId,
    required String userId,
    required FleetRole role,
    required String requesterId,
  }) async {
    return Result.success(FleetMember(
      id: '${companyId}_$userId',
      companyId: companyId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<FleetMember, AppError>> updateRole({
    required String companyId,
    required String userId,
    required FleetRole newRole,
    required String requesterId,
  }) async {
    return Result.success(FleetMember(
      id: '${companyId}_$userId',
      companyId: companyId,
      userId: userId,
      role: newRole,
      joinedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<void, AppError>> removeMember({
    required String companyId,
    required String userId,
    required String requesterId,
  }) async {
    return const Result.success(null);
  }

  @override
  Future<Result<FleetRole?, AppError>> getMemberRole({
    required String companyId,
    required String userId,
  }) async =>
      Result.success(members
          .where((m) => m.companyId == companyId && m.userId == userId)
          .map((m) => m.role)
          .firstOrNull);

  @override
  Future<Result<bool, AppError>> canWrite({
    required String companyId,
    required String userId,
  }) async {
    final roleResult =
        await getMemberRole(companyId: companyId, userId: userId);
    final role = roleResult.valueOrNull;
    return Result.success(role == FleetRole.owner || role == FleetRole.manager);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

FleetMember _member({
  String companyId = 'company-1',
  String userId = 'user-1',
  FleetRole role = FleetRole.staff,
  String? displayName,
}) =>
    FleetMember(
      id: '${companyId}_$userId',
      companyId: companyId,
      userId: userId,
      role: role,
      displayName: displayName,
      joinedAt: DateTime(2025, 1, 1),
    );

Widget _buildScreen({
  required _StubFleetMemberService service,
  String companyId = 'company-1',
  String currentUserId = 'owner-1',
}) {
  sl
    ..reset()
    ..registerLazySingleton<FleetMemberService>(() => service)
    ..registerLazySingleton<AuthService>(() => AuthService());

  return MaterialApp(
    home: ChangeNotifierProvider(
      create: (_) => AuthProvider(authService: sl.get<AuthService>()),
      child: FleetMemberScreen(
        companyId: companyId,
        currentUserId: currentUserId,
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  tearDown(() => sl.reset());

  group('FleetMemberScreen — 表示', () {
    testWidgets('メンバーが0人の場合は空状態を表示する', (tester) async {
      final service = _StubFleetMemberService(members: []);
      await tester.pumpWidget(_buildScreen(service: service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fleet_members_empty')), findsOneWidget);
    });

    testWidgets('メンバー一覧が表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(
            userId: 'owner-1', role: FleetRole.owner, displayName: 'オーナー太郎'),
        _member(
            userId: 'staff-1', role: FleetRole.staff, displayName: 'スタッフ花子'),
      ]);
      await tester.pumpWidget(_buildScreen(
        service: service,
        currentUserId: 'owner-1',
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('member_card_owner-1')), findsOneWidget);
      expect(find.byKey(const Key('member_card_staff-1')), findsOneWidget);
      expect(find.text('オーナー太郎'), findsOneWidget);
      expect(find.text('スタッフ花子'), findsOneWidget);
    });

    testWidgets('現在のユーザーには（あなた）が表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner, displayName: '自分'),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      expect(find.text('（あなた）'), findsOneWidget);
    });
  });

  group('FleetMemberScreen — オーナー権限', () {
    testWidgets('オーナーには「メンバーを追加」FABが表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_member_fab')), findsOneWidget);
    });

    testWidgets('非オーナーには「メンバーを追加」FABが表示されない', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'staff-1', role: FleetRole.staff),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'staff-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_member_fab')), findsNothing);
    });

    testWidgets('オーナーは他メンバーの削除ボタンが表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner, displayName: 'オーナー'),
        _member(userId: 'staff-1', role: FleetRole.staff, displayName: 'スタッフ'),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_member_staff-1')), findsOneWidget);
    });
  });

  group('FleetMemberScreen — admin権限', () {
    testWidgets('adminには「メンバーを追加」FABが表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'admin-1', role: FleetRole.admin),
        _member(userId: 'staff-1', role: FleetRole.staff),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'admin-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_member_fab')), findsOneWidget);
    });

    testWidgets('adminはstaffの削除ボタンが表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner),
        _member(userId: 'admin-1', role: FleetRole.admin),
        _member(userId: 'staff-1', role: FleetRole.staff),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'admin-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_member_staff-1')), findsOneWidget);
    });

    testWidgets('adminはownerの削除ボタンが表示されない', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner),
        _member(userId: 'admin-1', role: FleetRole.admin),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'admin-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_member_owner-1')), findsNothing);
    });
  });

  group('FleetMemberScreen — メンバー追加', () {
    testWidgets('メンバー追加ダイアログが開く', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_member_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_member_user_id_field')), findsOneWidget);
      expect(
          find.byKey(const Key('add_member_confirm_button')), findsOneWidget);
    });

    testWidgets('ユーザーIDが空のまま追加ボタンを押しても閉じない', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_member_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_member_confirm_button')));
      await tester.pumpAndSettle();

      // Dialog should still be open (empty userId rejected)
      expect(find.byKey(const Key('add_member_user_id_field')), findsOneWidget);
    });
  });

  group('FleetMemberScreen — 削除確認', () {
    testWidgets('削除ボタンタップで確認ダイアログが表示される', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(userId: 'owner-1', role: FleetRole.owner, displayName: 'オーナー'),
        _member(userId: 'staff-1', role: FleetRole.staff, displayName: 'スタッフ'),
      ]);
      await tester
          .pumpWidget(_buildScreen(service: service, currentUserId: 'owner-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('remove_member_staff-1')));
      await tester.pumpAndSettle();

      expect(find.text('メンバーを削除'), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('displayNameがない場合はuserIdをフォールバック表示する', (tester) async {
      final service = _StubFleetMemberService(members: [
        _member(
            userId: 'uid-no-name', role: FleetRole.viewer, displayName: null),
      ]);
      await tester.pumpWidget(
          _buildScreen(service: service, currentUserId: 'other-user'));
      await tester.pumpAndSettle();

      expect(find.text('uid-no-name'), findsWidgets);
    });

    testWidgets('サービスエラー時は再読み込みボタンが表示される', (tester) async {
      sl
        ..reset()
        ..registerLazySingleton<FleetMemberService>(
            () => _FailingFleetMemberService())
        ..registerLazySingleton<AuthService>(() => AuthService());

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: sl.get<AuthService>()),
          child: const FleetMemberScreen(
            companyId: 'company-1',
            currentUserId: 'owner-1',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });
}

class _FailingFleetMemberService implements FleetMemberService {
  @override
  Future<Result<List<FleetMember>, AppError>> getMembers(
          String companyId) async =>
      const Result.failure(AppError.unknown('network error'));

  @override
  Future<Result<FleetMember, AppError>> addMember(
          {required String companyId,
          required String userId,
          required FleetRole role,
          required String requesterId}) async =>
      const Result.failure(AppError.unknown('error'));

  @override
  Future<Result<FleetMember, AppError>> updateRole(
          {required String companyId,
          required String userId,
          required FleetRole newRole,
          required String requesterId}) async =>
      const Result.failure(AppError.unknown('error'));

  @override
  Future<Result<void, AppError>> removeMember(
          {required String companyId,
          required String userId,
          required String requesterId}) async =>
      const Result.failure(AppError.unknown('error'));

  @override
  Future<Result<FleetRole?, AppError>> getMemberRole(
          {required String companyId, required String userId}) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> canWrite(
          {required String companyId, required String userId}) async =>
      const Result.success(false);
}
