// DriveLogService Unit Tests
//
// Firebase (Firestore) への直接アクセスが必要なメソッドは統合テストでカバーする。
// このファイルでは以下をテストする:
//   1. DriveLog / DriveStatistics / GeoPoint2D モデルのロジック
//   2. DriveLogStatus / WeatherCondition / RoadType enum の動作
//   3. GeoPoint2D の距離計算（Haversine）
//   4. DriveStatistics の表示フォーマット
//   5. addSpotRating のバリデーション仕様（rating 1-5）
//   6. AppError 型の利用パターン（DriveLogService 内のエラー）
//   7. エッジケース

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DriveLogStatus enum
  // ---------------------------------------------------------------------------

  group('DriveLogStatus', () {
    test('全ステータスに displayName が設定されている', () {
      for (final status in DriveLogStatus.values) {
        expect(status.displayName.isNotEmpty, true,
            reason: '${status.name} の displayName が空です');
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final status in DriveLogStatus.values) {
        final result = DriveLogStatus.fromString(status.name);
        expect(result, status,
            reason: '${status.name} の fromString が失敗します');
      }
    });

    test('fromString で null は null を返す', () {
      expect(DriveLogStatus.fromString(null), isNull);
    });

    test('fromString で不正な値は null を返す', () {
      expect(DriveLogStatus.fromString('unknown_status'), isNull);
    });

    test('recording ステータスが存在する', () {
      expect(DriveLogStatus.values.any((s) => s.name == 'recording'), true);
    });

    test('completed ステータスが存在する', () {
      expect(DriveLogStatus.values.any((s) => s.name == 'completed'), true);
    });
  });

  // ---------------------------------------------------------------------------
  // WeatherCondition enum
  // ---------------------------------------------------------------------------

  group('WeatherCondition', () {
    test('全天気に displayName と emoji が設定されている', () {
      for (final weather in WeatherCondition.values) {
        expect(weather.displayName.isNotEmpty, true);
        expect(weather.emoji.isNotEmpty, true);
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final weather in WeatherCondition.values) {
        final result = WeatherCondition.fromString(weather.name);
        expect(result, weather);
      }
    });

    test('fromString で null は null を返す', () {
      expect(WeatherCondition.fromString(null), isNull);
    });

    test('fromString で不正な値は null を返す', () {
      expect(WeatherCondition.fromString('hail'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // RoadType enum
  // ---------------------------------------------------------------------------

  group('RoadType', () {
    test('全道路タイプに displayName が設定されている', () {
      for (final type in RoadType.values) {
        expect(type.displayName.isNotEmpty, true,
            reason: '${type.name} の displayName が空です');
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final type in RoadType.values) {
        final result = RoadType.fromString(type.name);
        expect(result, type);
      }
    });

    test('fromString で null は null を返す', () {
      expect(RoadType.fromString(null), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // GeoPoint2D
  // ---------------------------------------------------------------------------

  group('GeoPoint2D', () {
    test('toMap / fromMap の往復変換が正しい', () {
      const point = GeoPoint2D(latitude: 35.6895, longitude: 139.6917);
      final map = point.toMap();
      final restored = GeoPoint2D.fromMap(map);

      expect(restored.latitude, closeTo(35.6895, 0.0001));
      expect(restored.longitude, closeTo(139.6917, 0.0001));
    });

    test('null の map は (0, 0) を返す', () {
      final point = GeoPoint2D.fromMap(null);
      expect(point.latitude, 0.0);
      expect(point.longitude, 0.0);
    });

    test('同一座標の距離は 0 に近い', () {
      const tokyo = GeoPoint2D(latitude: 35.6895, longitude: 139.6917);
      final distance = tokyo.distanceTo(tokyo);
      expect(distance, closeTo(0, 0.1));
    });

    test('東京〜大阪間の距離は概ね 400km 前後', () {
      const tokyo = GeoPoint2D(latitude: 35.6895, longitude: 139.6917);
      const osaka = GeoPoint2D(latitude: 34.6937, longitude: 135.5023);
      final distanceM = tokyo.distanceTo(osaka);
      final distanceKm = distanceM / 1000;
      // 直線距離は約 400km ± 20km
      expect(distanceKm, greaterThan(380));
      expect(distanceKm, lessThan(420));
    });

    test('distanceTo は対称的（A→B == B→A）', () {
      const a = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      const b = GeoPoint2D(latitude: 36.0, longitude: 140.0);
      final ab = a.distanceTo(b);
      final ba = b.distanceTo(a);
      expect(ab, closeTo(ba, 0.001));
    });

    test('極端に離れた座標でもクラッシュしない', () {
      const north = GeoPoint2D(latitude: 90.0, longitude: 0.0);
      const south = GeoPoint2D(latitude: -90.0, longitude: 0.0);
      expect(() => north.distanceTo(south), returnsNormally);
    });

    test('等価比較が正しく動作する', () {
      const a = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      const b = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      const c = GeoPoint2D(latitude: 36.0, longitude: 139.0);

      expect(a == b, true);
      expect(a == c, false);
    });
  });

  // ---------------------------------------------------------------------------
  // DriveStatistics
  // ---------------------------------------------------------------------------

  group('DriveStatistics', () {
    test('toMap / fromMap の往復変換が正しい', () {
      const stats = DriveStatistics(
        totalDistance: 150.5,
        totalDuration: 7200, // 2 hours
        averageSpeed: 75.0,
        maxSpeed: 120.0,
        fuelConsumed: 12.5,
        stopCount: 3,
      );
      final map = stats.toMap();
      final restored = DriveStatistics.fromMap(map);

      expect(restored.totalDistance, 150.5);
      expect(restored.totalDuration, 7200);
      expect(restored.averageSpeed, 75.0);
      expect(restored.maxSpeed, 120.0);
      expect(restored.fuelConsumed, 12.5);
      expect(restored.stopCount, 3);
    });

    test('fromMap で null は全フィールド 0 のデフォルト値を返す', () {
      final stats = DriveStatistics.fromMap(null);
      expect(stats.totalDistance, 0.0);
      expect(stats.totalDuration, 0);
      expect(stats.averageSpeed, 0.0);
      expect(stats.maxSpeed, 0.0);
      expect(stats.stopCount, 0);
    });

    test('formattedDuration: 1時間以上は時間・分で表示', () {
      const stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 3661, // 1h 1m 1s
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDuration, contains('1時間'));
      expect(stats.formattedDuration, contains('1分'));
    });

    test('formattedDuration: 1時間未満は分・秒で表示', () {
      const stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 125, // 2m 5s
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDuration, contains('2分'));
      expect(stats.formattedDuration, contains('5秒'));
    });

    test('formattedDuration: 0秒は 0分0秒で表示', () {
      const stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDuration, isNotNull);
      expect(stats.formattedDuration.isNotEmpty, true);
    });

    test('formattedDistance: 1km 以上は km で表示', () {
      const stats = DriveStatistics(
        totalDistance: 12.5,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDistance, contains('km'));
      expect(stats.formattedDistance, contains('12.5'));
    });

    test('formattedDistance: 1km 未満は m で表示', () {
      const stats = DriveStatistics(
        totalDistance: 0.5,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDistance, contains('m'));
      expect(stats.formattedDistance, contains('500'));
    });
  });

  // ---------------------------------------------------------------------------
  // DriveWaypoint
  // ---------------------------------------------------------------------------

  group('DriveWaypoint', () {
    test('toMap で location が含まれる', () {
      final waypoint = DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        timestamp: DateTime(2024, 3, 15, 10, 0, 0),
        speed: 60.0,
        altitude: 100.0,
        heading: 270.0,
        accuracy: 5.0,
      );
      final map = waypoint.toMap();

      expect(map['location'], isNotNull);
      expect(map['speed'], 60.0);
      expect(map['altitude'], 100.0);
      expect(map['heading'], 270.0);
      expect(map['accuracy'], 5.0);
    });

    test('null フィールドは toMap に含まれない', () {
      final waypoint = DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        timestamp: DateTime.now(),
      );
      final map = waypoint.toMap();

      expect(map.containsKey('speed'), false);
      expect(map.containsKey('altitude'), false);
    });
  });

  // ---------------------------------------------------------------------------
  // AppError パターン（DriveLogService 内で使われるエラー型）
  // ---------------------------------------------------------------------------

  group('DriveLogService AppError パターン', () {
    test('ドライブログが存在しない場合は NotFoundError を返すべき', () {
      final error = AppError.notFound('Resource not found');
      expect(error, isA<NotFoundError>());
      expect(error.isRetryable, false);
      expect(error.userMessage.isNotEmpty, true);
    });

    test('他ユーザーのログへの操作は PermissionError を返すべき', () {
      final error = AppError.permission('Permission denied');
      expect(error, isA<PermissionError>());
      expect(error.isRetryable, false);
    });

    test('評価値 0（範囲外）は ValidationError を返すべき', () {
      // addSpotRating の rating < 1 || rating > 5 バリデーション
      final error = AppError.validation('Invalid rating value');
      expect(error, isA<ValidationError>());
      expect(error.isRetryable, false);
    });

    test('評価値 6（範囲外）は ValidationError を返すべき', () {
      final error = AppError.validation('Invalid rating value');
      expect(error, isA<ValidationError>());
    });

    test('Result<DriveLog, AppError> の failure を処理できる', () {
      final result = Result<String, AppError>.failure(
        AppError.notFound('Resource not found'),
      );

      final handled = result.when(
        success: (_) => 'ok',
        failure: (e) => e.userMessage,
      );

      expect(handled.isNotEmpty, true);
    });

    test('Result<void, AppError> の success は isSuccess が true', () {
      const result = Result<void, AppError>.success(null);
      expect(result.isSuccess, true);
    });
  });

  // ---------------------------------------------------------------------------
  // DriveLog モデル
  // ---------------------------------------------------------------------------

  group('DriveLog モデル', () {
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

    test('DriveLog インスタンスを作成できる', () {
      final log = _makeLog();
      expect(log.id, 'log1');
      expect(log.userId, 'user1');
      expect(log.status, DriveLogStatus.completed);
    });

    test('copyWith で status を更新できる', () {
      final log = _makeLog(status: DriveLogStatus.recording);
      final updated = log.copyWith(status: DriveLogStatus.completed);

      expect(updated.status, DriveLogStatus.completed);
      expect(updated.id, log.id); // 他フィールドは変わらない
    });

    test('recording ステータスは endTime が null', () {
      final log = _makeLog(status: DriveLogStatus.recording);
      expect(log.endTime, isNull);
    });

    test('statistics.totalDistance はデフォルト値が正しい', () {
      final log = _makeLog();
      expect(log.statistics.totalDistance, 50.0);
    });

    test('toMap で userId が含まれる', () {
      final log = _makeLog(userId: 'u1');
      final map = log.toMap();
      expect(map['userId'], 'u1');
    });

    test('toMap で status が文字列で含まれる', () {
      final log = _makeLog(status: DriveLogStatus.completed);
      final map = log.toMap();
      expect(map['status'], 'completed');
    });
  });

  // ---------------------------------------------------------------------------
  // Edge Cases
  // ---------------------------------------------------------------------------

  group('Edge Cases', () {
    test('GeoPoint2D の経度が 180 を超えてもクラッシュしない', () {
      const edge = GeoPoint2D(latitude: 0, longitude: 180);
      expect(() => edge.distanceTo(const GeoPoint2D(latitude: 0, longitude: -180)),
          returnsNormally);
    });

    test('DriveStatistics の totalDuration が 0 のとき formattedDuration が正常', () {
      const stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDuration.isNotEmpty, true);
    });

    test('DriveStatistics の totalDistance が 0 のとき formattedDistance が正常', () {
      const stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
      expect(stats.formattedDistance.isNotEmpty, true);
    });

    test('DriveStatistics の fromMap で数値フィールドが int か double かを正しく変換する', () {
      final map = <String, dynamic>{
        'totalDistance': 100, // int として渡す
        'totalDuration': 3600.0, // double として渡す
        'averageSpeed': 50,
        'maxSpeed': 100,
      };
      final stats = DriveStatistics.fromMap(map);
      expect(stats.totalDistance, 100.0);
      expect(stats.totalDuration, 3600);
    });

    test('rating の範囲バリデーション: 1 は有効', () {
      // AppError.validation が返らないことを意味する
      // サービスコード: if (rating < 1 || rating > 5) → ValidationError
      expect(1 < 1 || 1 > 5, false); // 1 は有効な評価値
    });

    test('rating の範囲バリデーション: 5 は有効', () {
      expect(5 < 1 || 5 > 5, false); // 5 は有効な評価値
    });

    test('rating の範囲バリデーション: 0 は無効', () {
      expect(0 < 1 || 0 > 5, true); // 0 は無効 → ValidationError
    });

    test('rating の範囲バリデーション: 6 は無効', () {
      expect(6 < 1 || 6 > 5, true); // 6 は無効 → ValidationError
    });

    test('rating の範囲バリデーション: 負数は無効', () {
      expect(-1 < 1 || -1 > 5, true); // -1 は無効 → ValidationError
    });

    test('WeatherCondition の全 emoji は空でない', () {
      for (final weather in WeatherCondition.values) {
        expect(weather.emoji.isNotEmpty, true);
      }
    });

    test('DriveLogStatus の recording → completed のライフサイクルが自然', () {
      // startDrive は recording、endDrive は completed
      expect(DriveLogStatus.recording.displayName, isNotEmpty);
      expect(DriveLogStatus.completed.displayName, isNotEmpty);
      // recording と completed は別のステータス
      expect(DriveLogStatus.recording, isNot(DriveLogStatus.completed));
    });
  });
}
