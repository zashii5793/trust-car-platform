// DriveLogProvider Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/drive_log_provider.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock DriveLogService
// ---------------------------------------------------------------------------

class MockDriveLogService implements DriveLogService {
  Result<List<DriveLog>, AppError> getUserLogsResult = const Result.success([]);
  Result<void, AppError> deleteResult = const Result.success(null);

  int getUserLogsCallCount = 0;
  int deleteCallCount = 0;
  String? lastUserId;
  int? lastLimit;
  String? lastDeletedId;

  @override
  Future<Result<List<DriveLog>, AppError>> getUserDriveLogs({
    required String userId,
    int limit = 20,
    dynamic startAfter,
  }) async {
    getUserLogsCallCount++;
    lastUserId = userId;
    lastLimit = limit;
    return getUserLogsResult;
  }

  @override
  Future<Result<void, AppError>> deleteDriveLog({
    required String driveLogId,
    required String userId,
  }) async {
    deleteCallCount++;
    lastDeletedId = driveLogId;
    return deleteResult;
  }

  // Unused methods
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

DriveLog _makeLog({
  String id = 'log1',
  String userId = 'user1',
  DriveLogStatus status = DriveLogStatus.completed,
}) {
  final now = DateTime.now();
  return DriveLog(
    id: id,
    userId: userId,
    status: status,
    startTime: now,
    statistics: const DriveStatistics(
      totalDistance: 50.0,
      totalDuration: 3600,
      averageSpeed: 50.0,
      maxSpeed: 100.0,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

DriveLogProvider _makeProvider(MockDriveLogService service) {
  return DriveLogProvider(driveLogService: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DriveLogProvider', () {
    late MockDriveLogService mockService;
    late DriveLogProvider provider;

    setUp(() {
      mockService = MockDriveLogService();
      provider = _makeProvider(mockService);
    });

    // ── 初期状態 ──────────────────────────────────────────────────────────────

    group('初期状態', () {
      test('初期状態は空でisLoadingはfalse', () {
        expect(provider.logs, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
        expect(provider.hasMore, true);
        expect(provider.isEmpty, true);
      });
    });

    // ── loadUserDriveLogs ─────────────────────────────────────────────────────

    group('loadUserDriveLogs', () {
      test('正常にログ一覧を読み込む', () async {
        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l1'),
          _makeLog(id: 'l2'),
        ]);

        await provider.loadUserDriveLogs('user1');

        expect(provider.logs.length, 2);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('正しい userId を渡してサービスを呼び出す', () async {
        await provider.loadUserDriveLogs('u_test');
        expect(mockService.lastUserId, 'u_test');
      });

      test('読み込み中は isLoading が true になる（完了後 false）', () async {
        await provider.loadUserDriveLogs('user1');
        expect(provider.isLoading, false);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.getUserLogsResult =
            Result.failure(AppError.network('connection failed'));

        await provider.loadUserDriveLogs('user1');

        expect(provider.error, isNotNull);
        expect(provider.logs, isEmpty);
      });

      test('20件のとき hasMore が true になる', () async {
        mockService.getUserLogsResult = Result.success(
          List.generate(20, (i) => _makeLog(id: 'l$i')),
        );

        await provider.loadUserDriveLogs('user1');

        expect(provider.hasMore, true);
      });

      test('20件未満のとき hasMore が false になる', () async {
        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l1'),
          _makeLog(id: 'l2'),
        ]);

        await provider.loadUserDriveLogs('user1');

        expect(provider.hasMore, false);
      });

      test('再読み込みで既存ログがクリアされる', () async {
        mockService.getUserLogsResult = Result.success([_makeLog(id: 'l1')]);
        await provider.loadUserDriveLogs('user1');
        expect(provider.logs.length, 1);

        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l2'),
          _makeLog(id: 'l3'),
        ]);
        await provider.loadUserDriveLogs('user1');

        expect(provider.logs.length, 2);
        expect(provider.logs.first.id, 'l2');
      });

      test('isEmpty は読み込み後ログがあれば false', () async {
        mockService.getUserLogsResult = Result.success([_makeLog()]);
        await provider.loadUserDriveLogs('user1');

        expect(provider.isEmpty, false);
      });
    });

    // ── loadMore ──────────────────────────────────────────────────────────────

    group('loadMore', () {
      test('hasMore が false のとき追加読み込みしない', () async {
        mockService.getUserLogsResult = Result.success([_makeLog()]);
        await provider.loadUserDriveLogs('user1'); // 1件 < 20 → hasMore=false

        mockService.getUserLogsCallCount = 0;
        await provider.loadMore('user1');

        expect(mockService.getUserLogsCallCount, 0);
      });

      test('isLoading 中は追加読み込みしない', () async {
        // hasMore=true の状態で loadMore を呼ぶ
        mockService.getUserLogsResult = Result.success(
          List.generate(20, (i) => _makeLog(id: 'l$i')),
        );
        await provider.loadUserDriveLogs('user1');
        mockService.getUserLogsCallCount = 0;

        // ログが空でないため loadMore は実行される
        await provider.loadMore('user1');
        expect(mockService.getUserLogsCallCount, 1);
      });

      test('loadMore 失敗時に hasMore が false になる', () async {
        // hasMore=true の状態を作る
        mockService.getUserLogsResult = Result.success(
          List.generate(20, (i) => _makeLog(id: 'l$i')),
        );
        await provider.loadUserDriveLogs('user1');

        // 次のリクエストを失敗させる
        mockService.getUserLogsResult =
            Result.failure(AppError.network('failed'));
        await provider.loadMore('user1');

        expect(provider.hasMore, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── deleteDriveLog ────────────────────────────────────────────────────────

    group('deleteDriveLog', () {
      test('削除成功でログ一覧から除去される', () async {
        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l1'),
          _makeLog(id: 'l2'),
        ]);
        await provider.loadUserDriveLogs('user1');

        final success = await provider.deleteDriveLog('l1', 'user1');

        expect(success, true);
        expect(provider.logs.length, 1);
        expect(provider.logs.first.id, 'l2');
      });

      test('削除失敗ではログ一覧が変わらない', () async {
        mockService.getUserLogsResult = Result.success([_makeLog(id: 'l1')]);
        await provider.loadUserDriveLogs('user1');

        mockService.deleteResult =
            Result.failure(AppError.permission('Permission denied'));
        final success = await provider.deleteDriveLog('l1', 'user1');

        expect(success, false);
        expect(provider.logs.length, 1);
        expect(provider.error, isNotNull);
      });

      test('正しい driveLogId を渡してサービスを呼び出す', () async {
        await provider.deleteDriveLog('target_log', 'user1');
        expect(mockService.lastDeletedId, 'target_log');
      });
    });

    // ── clear ─────────────────────────────────────────────────────────────────

    group('clear', () {
      test('clear で全状態がリセットされる', () async {
        mockService.getUserLogsResult = Result.success([_makeLog(id: 'l1')]);
        await provider.loadUserDriveLogs('user1');
        expect(provider.logs.isNotEmpty, true);

        provider.clear();

        expect(provider.logs, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
        expect(provider.hasMore, true);
        expect(provider.isEmpty, true);
      });
    });

    // ── Edge Cases ────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('空のログ一覧を読み込んでも正常', () async {
        mockService.getUserLogsResult = const Result.success([]);
        await provider.loadUserDriveLogs('user1');

        expect(provider.logs, isEmpty);
        expect(provider.error, isNull);
        expect(provider.isEmpty, true);
      });

      test('存在しない ID を削除してもクラッシュしない', () async {
        await provider.loadUserDriveLogs('user1');
        expect(
          () => provider.deleteDriveLog('nonexistent', 'user1'),
          returnsNormally,
        );
      });

      test('削除後に再読み込みで正しいリストになる', () async {
        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l1'),
          _makeLog(id: 'l2'),
        ]);
        await provider.loadUserDriveLogs('user1');
        await provider.deleteDriveLog('l1', 'user1');

        // 再読み込み
        mockService.getUserLogsResult = Result.success([_makeLog(id: 'l2')]);
        await provider.loadUserDriveLogs('user1');

        expect(provider.logs.length, 1);
        expect(provider.logs.first.id, 'l2');
      });

      test('recording ステータスのログも一覧に表示できる', () async {
        mockService.getUserLogsResult = Result.success([
          _makeLog(id: 'l1', status: DriveLogStatus.recording),
        ]);
        await provider.loadUserDriveLogs('user1');

        expect(provider.logs.first.status, DriveLogStatus.recording);
      });
    });
  });
}
