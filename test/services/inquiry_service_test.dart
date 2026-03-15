// InquiryService / Inquiry Model Unit Tests
//
// Since InquiryService requires FirebaseFirestore, we test pure business logic:
//   1. InquiryStatus / InquiryType enum behavior
//   2. Inquiry.hasReply
//   3. Inquiry.isOpen (status-based)
//   4. Inquiry.displayStatus
//   5. Inquiry.vehicleDisplay (formatted vehicle info string)
//   6. AppError patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Inquiry _makeInquiry({
  String id = 'inq1',
  InquiryStatus status = InquiryStatus.pending,
  DateTime? repliedAt,
  String? vehicleMaker,
  String? vehicleModel,
  int? vehicleYear,
}) {
  final now = DateTime.now();
  return Inquiry(
    id: id,
    userId: 'user1',
    shopId: 'shop1',
    type: InquiryType.general,
    status: status,
    subject: 'テスト件名',
    initialMessage: 'テストメッセージ',
    repliedAt: repliedAt,
    vehicleMaker: vehicleMaker,
    vehicleModel: vehicleModel,
    vehicleYear: vehicleYear,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InquiryStatus enum', () {
    test('全ステータスの displayName が空でない', () {
      for (final status in InquiryStatus.values) {
        expect(status.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(InquiryStatus.fromString('pending'), InquiryStatus.pending);
      expect(InquiryStatus.fromString('inProgress'), InquiryStatus.inProgress);
      expect(InquiryStatus.fromString('replied'), InquiryStatus.replied);
      expect(InquiryStatus.fromString('closed'), InquiryStatus.closed);
      expect(InquiryStatus.fromString('cancelled'), InquiryStatus.cancelled);
    });

    test('fromString(null) は null を返す', () {
      expect(InquiryStatus.fromString(null), isNull);
    });

    test('fromString 不明な文字列は null を返す', () {
      expect(InquiryStatus.fromString(''), isNull);
      expect(InquiryStatus.fromString('unknown'), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final s in InquiryStatus.values) {
        expect(InquiryStatus.fromString(s.name), s);
      }
    });
  });

  group('InquiryType enum', () {
    test('全タイプの displayName が空でない', () {
      for (final type in InquiryType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(InquiryType.fromString('partInquiry'), InquiryType.partInquiry);
      expect(InquiryType.fromString('estimate'), InquiryType.estimate);
      expect(InquiryType.fromString('appointment'), InquiryType.appointment);
      expect(InquiryType.fromString('general'), InquiryType.general);
    });

    test('fromString(null) は null を返す', () {
      expect(InquiryType.fromString(null), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final t in InquiryType.values) {
        expect(InquiryType.fromString(t.name), t);
      }
    });
  });

  // ── Inquiry.hasReply ──────────────────────────────────────────────────────

  group('Inquiry.hasReply', () {
    test('repliedAt が null のとき false', () {
      final inq = _makeInquiry(repliedAt: null);
      expect(inq.hasReply, false);
    });

    test('repliedAt が設定されているとき true', () {
      final inq = _makeInquiry(repliedAt: DateTime.now());
      expect(inq.hasReply, true);
    });

    test('過去の repliedAt でも true', () {
      final inq = _makeInquiry(
        repliedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(inq.hasReply, true);
    });
  });

  // ── Inquiry.isOpen ────────────────────────────────────────────────────────

  group('Inquiry.isOpen', () {
    test('pending のとき true', () {
      expect(_makeInquiry(status: InquiryStatus.pending).isOpen, true);
    });

    test('inProgress のとき true', () {
      expect(_makeInquiry(status: InquiryStatus.inProgress).isOpen, true);
    });

    test('replied のとき true', () {
      expect(_makeInquiry(status: InquiryStatus.replied).isOpen, true);
    });

    test('closed のとき false', () {
      expect(_makeInquiry(status: InquiryStatus.closed).isOpen, false);
    });

    test('cancelled のとき false', () {
      expect(_makeInquiry(status: InquiryStatus.cancelled).isOpen, false);
    });
  });

  // ── Inquiry.displayStatus ─────────────────────────────────────────────────

  group('Inquiry.displayStatus', () {
    test('pending のとき「返信待ち」', () {
      expect(_makeInquiry(status: InquiryStatus.pending).displayStatus, '返信待ち');
    });

    test('inProgress のとき status.displayName（「対応中」）', () {
      expect(
        _makeInquiry(status: InquiryStatus.inProgress).displayStatus,
        InquiryStatus.inProgress.displayName,
      );
    });

    test('replied のとき status.displayName（「回答済み」）', () {
      expect(
        _makeInquiry(status: InquiryStatus.replied).displayStatus,
        InquiryStatus.replied.displayName,
      );
    });

    test('closed のとき status.displayName', () {
      expect(
        _makeInquiry(status: InquiryStatus.closed).displayStatus,
        InquiryStatus.closed.displayName,
      );
    });

    test('cancelled のとき status.displayName', () {
      expect(
        _makeInquiry(status: InquiryStatus.cancelled).displayStatus,
        InquiryStatus.cancelled.displayName,
      );
    });
  });

  // ── Inquiry.vehicleDisplay ────────────────────────────────────────────────

  group('Inquiry.vehicleDisplay', () {
    test('vehicleMaker が null のとき null', () {
      final inq = _makeInquiry(vehicleMaker: null);
      expect(inq.vehicleDisplay, isNull);
    });

    test('vehicleMaker のみのとき maker 単体を返す', () {
      final inq = _makeInquiry(vehicleMaker: 'トヨタ');
      expect(inq.vehicleDisplay, 'トヨタ');
    });

    test('vehicleMaker + vehicleModel のとき「maker model」', () {
      final inq = _makeInquiry(vehicleMaker: 'トヨタ', vehicleModel: 'プリウス');
      expect(inq.vehicleDisplay, 'トヨタ プリウス');
    });

    test('vehicleMaker + vehicleModel + vehicleYear のとき「maker model (year年式)」', () {
      final inq = _makeInquiry(
        vehicleMaker: 'トヨタ',
        vehicleModel: 'プリウス',
        vehicleYear: 2020,
      );
      expect(inq.vehicleDisplay, 'トヨタ プリウス (2020年式)');
    });

    test('vehicleMaker + vehicleYear のみ（model なし）のとき maker と year を含む', () {
      final inq = _makeInquiry(vehicleMaker: 'ホンダ', vehicleYear: 2019);
      expect(inq.vehicleDisplay, 'ホンダ (2019年式)');
    });

    test('vehicleYear のみ（maker なし）のとき null', () {
      final inq = _makeInquiry(vehicleYear: 2020);
      expect(inq.vehicleDisplay, isNull);
    });
  });

  // ── Inquiry equality ──────────────────────────────────────────────────────

  group('Inquiry equality', () {
    test('同じ id は等しい', () {
      final a = _makeInquiry(id: 'inq1', status: InquiryStatus.pending);
      final b = _makeInquiry(id: 'inq1', status: InquiryStatus.closed);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeInquiry(id: 'inq1');
      final b = _makeInquiry(id: 'inq2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（問い合わせサービスエラーシナリオ）', () {
    test('network error は isRetryable=true', () {
      const error = AppError.network('接続失敗');
      expect(error.isRetryable, true);
    });

    test('permission error は isRetryable=false', () {
      const error = AppError.permission('アクセス権限なし');
      expect(error.isRetryable, false);
    });

    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('問い合わせが見つかりません');
      expect(error.isRetryable, false);
    });

    test('Result.success に Inquiry を格納できる', () {
      final result = Result<Inquiry, AppError>.success(_makeInquiry());
      expect(result.isSuccess, true);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<List<Inquiry>, AppError>.failure(
        AppError.network('failed'),
      );
      expect(result.isFailure, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('InquiryStatus.displayName が全て異なる', () {
      final names = InquiryStatus.values.map((s) => s.displayName).toSet();
      expect(names.length, InquiryStatus.values.length);
    });

    test('InquiryType.displayName が全て異なる', () {
      final names = InquiryType.values.map((t) => t.displayName).toSet();
      expect(names.length, InquiryType.values.length);
    });

    test('vehicleDisplay: 非常に長いメーカー名でも例外なし', () {
      final inq = _makeInquiry(vehicleMaker: 'あ' * 100, vehicleModel: 'モデル');
      expect(() => inq.vehicleDisplay, returnsNormally);
    });

    test('vehicleYear: 0 のとき「(0年式)」を含む', () {
      final inq = _makeInquiry(vehicleMaker: 'トヨタ', vehicleYear: 0);
      expect(inq.vehicleDisplay, contains('0年式'));
    });

    test('displayStatus: 全ステータスで例外なし', () {
      for (final status in InquiryStatus.values) {
        expect(
          () => _makeInquiry(status: status).displayStatus,
          returnsNormally,
        );
      }
    });
  });
}
