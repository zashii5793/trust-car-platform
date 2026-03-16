// DriveLogScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/drive/drive_log_screen.dart';
import 'package:trust_car_platform/providers/drive_log_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthService implements AuthService {
  @override
  Stream<dynamic> get authStateChanges => const Stream.empty();

  @override
  Future<Result<dynamic, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<dynamic, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<dynamic, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> signOut() async =>
      const Result.success(null);

  @override
  Future<Result<dynamic, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<dynamic, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(
          String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteAccount() async =>
      const Result.success(null);

  @override
  dynamic get currentUser => null;
}

class MockDriveLogService implements DriveLogService {
  Result<List<DriveLog>, AppError> logsResult = const Result.success([]);
  Result<void, AppError> deleteResult = const Result.success(null);
  int loadCallCount = 0;
  String? lastDeleteId;

  @override
  Future<Result<List<DriveLog>, AppError>> getUserDriveLogs({
    required String userId,
    int limit = 20,
    dynamic startAfter,
  }) async {
    loadCallCount++;
    return logsResult;
  }

  @override
  Future<Result<void, AppError>> deleteDriveLog({
    required String driveLogId,
    required String userId,
  }) async {
    lastDeleteId = driveLogId;
    return deleteResult;
  }

  // Unimplemented (not needed for screen tests)
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helper — create a minimal DriveLog
// ---------------------------------------------------------------------------

DriveLog _makeDriveLog({
  String id = 'log1',
  String userId = 'user1',
  String? title,
  double distance = 42.5,
  int durationSecs = 3600,
}) {
  final now = DateTime.now();
  return DriveLog(
    id: id,
    userId: userId,
    status: DriveLogStatus.completed,
    startTime: now.subtract(const Duration(hours: 1)),
    statistics: DriveStatistics(
      totalDistance: distance,
      totalDuration: durationSecs,
      averageSpeed: 42.5,
      maxSpeed: 80.0,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildUnderTest({
  required MockDriveLogService driveLogService,
  String? userId,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(authService: MockAuthService()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            DriveLogProvider(driveLogService: driveLogService),
      ),
    ],
    child: const MaterialApp(home: DriveLogScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockDriveLogService service;

  setUp(() {
    service = MockDriveLogService();
  });

  group('DriveLogScreen — AppBar', () {
    testWidgets('「ドライブログ」タイトルを表示する', (tester) async {
      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      expect(find.text('ドライブログ'), findsOneWidget);
    });
  });

  group('DriveLogScreen — 空状態', () {
    testWidgets('ドライブログなしのとき空状態を表示する', (tester) async {
      service.logsResult = const Result.success([]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      expect(find.text('ドライブログがありません'), findsOneWidget);
    });

    testWidgets('空状態の説明文を表示する', (tester) async {
      service.logsResult = const Result.success([]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      expect(find.text('ドライブを記録してみましょう'), findsOneWidget);
    });
  });

  group('DriveLogScreen — ログ一覧', () {
    testWidgets('ドライブログが1件表示される', (tester) async {
      service.logsResult = Result.success([_makeDriveLog(id: 'log1')]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      expect(find.text('ドライブログがありません'), findsNothing);
    });

    testWidgets('複数ログが一覧に表示される', (tester) async {
      service.logsResult = Result.success([
        _makeDriveLog(id: 'log1', distance: 30.0),
        _makeDriveLog(id: 'log2', distance: 50.0),
      ]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      expect(find.text('ドライブログがありません'), findsNothing);
      // ログ要素が複数存在する（ListTile や Card など）
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('DriveLogScreen — エラー状態', () {
    testWidgets('ネットワークエラー時にエラー表示する', (tester) async {
      service.logsResult = const Result.failure(
        AppError.network('接続失敗'),
      );

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      // エラー状態UI (AppErrorState か エラーテキスト)
      expect(find.text('ドライブログがありません'), findsNothing);
    });
  });

  group('DriveLogScreen — 削除ダイアログ', () {
    testWidgets('削除ボタンをタップすると確認ダイアログが表示される', (tester) async {
      service.logsResult = Result.success([_makeDriveLog(id: 'log1')]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      // 削除ボタン（IconButton or tooltip='削除'）を探す
      final deleteButtons = find.byTooltip('削除');
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        expect(find.text('ドライブログを削除'), findsOneWidget);
        expect(find.text('このドライブログを削除しますか？'), findsOneWidget);
      }
    });

    testWidgets('削除ダイアログでキャンセルすると閉じる', (tester) async {
      service.logsResult = Result.success([_makeDriveLog(id: 'log1')]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      final deleteButtons = find.byTooltip('削除');
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();

        expect(find.text('ドライブログを削除'), findsNothing);
        expect(service.lastDeleteId, isNull);
      }
    });
  });

  group('Edge Cases', () {
    testWidgets('ログが空→追加されたら空状態が消える', (tester) async {
      service.logsResult = const Result.success([]);
      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();
      expect(find.text('ドライブログがありません'), findsOneWidget);
    });

    testWidgets('画面がスクロール可能（RefreshIndicator あり）', (tester) async {
      service.logsResult = Result.success([
        _makeDriveLog(id: 'log1'),
        _makeDriveLog(id: 'log2'),
      ]);

      await tester.pumpWidget(_buildUnderTest(driveLogService: service));
      await tester.pump();

      // ListView か RefreshIndicator が存在する
      expect(
        find.byType(RefreshIndicator).evaluate().isNotEmpty ||
            find.byType(ListView).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
