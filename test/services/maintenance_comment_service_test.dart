// MaintenanceCommentService Unit Tests
//
// Pure logic — no Firebase, no mocks needed.
// Tests cover tone judgement, comment content, edge cases.
//
// Coverage areas:
//   1. tone 判定ロジック（good / acceptable / overdue / noHistory / null）
//   2. timingEvaluation の文言確認
//   3. nextSchedule の文言確認
//   4. mileageAtService が null でもクラッシュしない
//   5. Edge Cases — 空リスト / 自己除外

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/maintenance_comment_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// 固定日付基準点（テスト用）
final _baseDate = DateTime(2026, 6, 7);

/// MaintenanceRecord を最小限のフィールドで作る
MaintenanceRecord _makeRecord({
  String id = 'r1',
  String vehicleId = 'v1',
  String userId = 'u1',
  MaintenanceType type = MaintenanceType.oilChange,
  String title = 'オイル交換',
  required DateTime date,
  int? mileageAtService,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    userId: userId,
    type: type,
    title: title,
    cost: 3500,
    date: date,
    mileageAtService: mileageAtService,
    createdAt: date,
  );
}

void main() {
  late MaintenanceCommentService service;

  setUp(() {
    service = MaintenanceCommentService();
  });

  // ==========================================================================
  // Group 1: tone 判定ロジック
  // ==========================================================================
  group('tone 判定ロジック', () {
    test('正常系（good）: 前回から5ヶ月・4,500km → oilChange(6ヶ月,5000km) → CommentTone.good', () {
      // oilChange rule: 6ヶ月, 5000km
      // 前回: 5ヶ月前 = 150日前, 走行 25000km → 現在 29500km
      final prevDate = _baseDate.subtract(const Duration(days: 150));
      final recordDate = _baseDate;

      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 25000,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: recordDate,
        mileageAtService: 29500,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 29500,
      );

      expect(comment, isNotNull);
      expect(comment!.tone, CommentTone.good);
    });

    test('許容範囲（acceptable）: 前回から7ヶ月・5,500km → oilChange → CommentTone.acceptable（1.2倍以内）', () {
      // 7ヶ月 ≈ 210日, ratio = 7/6 ≈ 1.167 ≤ 1.2
      // km ratio = 5500/5000 = 1.1 ≤ 1.2
      // max ratio = 1.167 → acceptable
      final prevDate = _baseDate.subtract(const Duration(days: 210));
      final recordDate = _baseDate;

      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 24500,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: recordDate,
        mileageAtService: 30000, // 30000 - 24500 = 5500km
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 30000,
      );

      expect(comment, isNotNull);
      expect(comment!.tone, CommentTone.acceptable);
    });

    test('遅れ（overdue）: 前回から10ヶ月・8,000km → oilChange → CommentTone.overdue', () {
      // 10ヶ月 ≈ 300日, ratio = 10/6 ≈ 1.667 > 1.2
      final prevDate = _baseDate.subtract(const Duration(days: 300));
      final recordDate = _baseDate;

      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 22000,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: recordDate,
        mileageAtService: 30000, // 30000 - 22000 = 8000km
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 30000,
      );

      expect(comment, isNotNull);
      expect(comment!.tone, CommentTone.overdue);
    });

    test('初回記録（noHistory）: 同タイプの前回記録なし → CommentTone.noHistory', () {
      final recordDate = _baseDate;
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: recordDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record], // 自分だけ（前回なし）
        currentMileage: 10000,
      );

      expect(comment, isNotNull);
      expect(comment!.tone, CommentTone.noHistory);
    });

    test('ルール未定義タイプ（null）: MaintenanceType.washing などルール外 → generateComment returns null', () {
      final recordDate = _baseDate;
      // washing は _rules に含まれていない
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.washing,
        title: '洗車',
        date: recordDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 10000,
      );

      expect(comment, isNull);
    });
  });

  // ==========================================================================
  // Group 2: timingEvaluation 文言確認
  // ==========================================================================
  group('timingEvaluation 文言確認', () {
    test('good トーン → timingEvaluation に "適切" が含まれる', () {
      final prevDate = _baseDate.subtract(const Duration(days: 150));
      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 25000,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 29500,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 29500,
      );

      expect(comment, isNotNull);
      expect(comment!.timingEvaluation, contains('適切'));
    });

    test('acceptable トーン → timingEvaluation に "ほぼ推奨" が含まれる', () {
      final prevDate = _baseDate.subtract(const Duration(days: 210));
      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 24500,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 30000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 30000,
      );

      expect(comment, isNotNull);
      expect(comment!.timingEvaluation, contains('ほぼ推奨'));
    });

    test('overdue トーン → timingEvaluation に "推奨時期より遅れ" が含まれる', () {
      final prevDate = _baseDate.subtract(const Duration(days: 300));
      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 22000,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 30000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 30000,
      );

      expect(comment, isNotNull);
      expect(comment!.timingEvaluation, contains('推奨時期より遅れ'));
    });

    test('noHistory トーン → timingEvaluation に "初めて" が含まれる', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 10000,
      );

      expect(comment, isNotNull);
      expect(comment!.timingEvaluation, contains('初め'));
    });
  });

  // ==========================================================================
  // Group 3: nextSchedule 文言確認
  // ==========================================================================
  group('nextSchedule 文言確認', () {
    test('ルールありの場合、nextSchedule に "次回の目安" が含まれる', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 10000,
      );

      expect(comment, isNotNull);
      expect(comment!.nextSchedule, isNotNull);
      expect(comment.nextSchedule, contains('次回の目安'));
    });

    test('mileageAtService が null でも nextSchedule に "次回の目安" が含まれる', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: null, // null
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 0,
      );

      // mileageAtService が null でも nextSchedule は生成される
      // （intervalMonths > 0 なので月ベースの nextSchedule が生成される）
      expect(comment, isNotNull);
      expect(comment!.nextSchedule, isNotNull);
      expect(comment.nextSchedule, contains('次回の目安'));
    });
  });

  // ==========================================================================
  // Group 4: mileageAtService が null でもクラッシュしない
  // ==========================================================================
  group('mileageAtService null 安全性', () {
    test('record.mileageAtService が null でも crash しない', () {
      final prevDate = _baseDate.subtract(const Duration(days: 150));
      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: null, // null
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: null, // null
      );

      expect(
        () => service.generateComment(
          record: record,
          allRecords: [prevRecord, record],
          currentMileage: 30000,
        ),
        returnsNormally,
      );
    });

    test('mileageAtService が null の場合、timingDetail に km 部分が含まれない', () {
      final prevDate = _baseDate.subtract(const Duration(days: 150));
      final prevRecord = _makeRecord(
        id: 'r0',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: null,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: null,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record],
        currentMileage: 30000,
      );

      expect(comment, isNotNull);
      // timingDetail は生成されるが km 部分（走行距離）は含まれない
      // km部分は prev.mileageAtService != null && record.mileageAtService != null の場合のみ
      if (comment!.timingDetail != null) {
        expect(comment.timingDetail, isNot(contains('走行後の交換')));
      }
    });
  });

  // ==========================================================================
  // Group 5: Edge Cases
  // ==========================================================================
  group('Edge Cases', () {
    test('allRecords が空リスト → noHistory', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [], // 空リスト
        currentMileage: 10000,
      );

      expect(comment, isNotNull);
      expect(comment!.tone, CommentTone.noHistory);
    });

    test('allRecords に record と同じ日の別レコードが含まれる → 自分自身 (id == record.id) は除外される', () {
      // r1 が対象レコード（id: 'r1'）
      // r_same が同じ日付・同じタイプだが別ID（r_same は前回として使われるべき）
      // r1 自身は allRecords に含まれているが除外される
      final sameDate = _baseDate;
      final prevDate = _baseDate.subtract(const Duration(days: 150));

      final prevRecord = _makeRecord(
        id: 'r_prev',
        type: MaintenanceType.oilChange,
        date: prevDate,
        mileageAtService: 25000,
      );
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: sameDate,
        mileageAtService: 29500,
      );
      // 同日の別レコード（後にソートされる）
      final sameDay = _makeRecord(
        id: 'r_same_day',
        type: MaintenanceType.oilChange,
        date: sameDate.subtract(const Duration(hours: 1)), // 1時間前
        mileageAtService: 29000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [prevRecord, record, sameDay],
        currentMileage: 29500,
      );

      // record 自身は除外され、最新の previous が使われる
      expect(comment, isNotNull);
      // r1 は除外されるので、prevRecord または sameDay が最新前回として使われる
      // sameDay (1時間前) の方が最新なので sameDay が前回記録となる
      // tone は noHistory ではないことを確認
      expect(comment!.tone, isNot(CommentTone.noHistory));
    });

    test('allRecords に自分自身のみ（id が同じ）→ noHistory', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.oilChange,
        date: _baseDate,
        mileageAtService: 10000,
      );

      final comment = service.generateComment(
        record: record,
        allRecords: [record], // 自分自身のみ
        currentMileage: 10000,
      );

      expect(comment, isNotNull);
      // 自分自身は除外されるので前回記録なし → noHistory
      expect(comment!.tone, CommentTone.noHistory);
    });

    test('ルール未定義の carWash（washing） → null を返す', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.washing,
        title: '洗車',
        date: _baseDate,
      );

      final result = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(result, isNull);
    });

    test('other タイプ → null を返す（ルール未定義）', () {
      final record = _makeRecord(
        id: 'r1',
        type: MaintenanceType.other,
        title: 'その他作業',
        date: _baseDate,
      );

      final result = service.generateComment(
        record: record,
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(result, isNull);
    });
  });
}
