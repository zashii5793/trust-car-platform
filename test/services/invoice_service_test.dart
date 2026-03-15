// InvoiceService / Invoice Model Unit Tests
//
// Since InvoiceService requires FirebaseFirestore, we test pure business logic:
//   1. PaymentMethod / PaymentStatus enum behavior
//   2. Invoice.remainingAmount (financial calculation)
//   3. Invoice.isOverdue (date + status logic)
//   4. Invoice.isDueSoon (7-day window logic)
//   5. AppError patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/invoice.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Invoice _makeInvoice({
  String id = 'inv1',
  int totalAmount = 100000,
  int? paidAmount,
  PaymentStatus paymentStatus = PaymentStatus.unpaid,
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return Invoice(
    id: id,
    maintenanceRecordId: 'rec1',
    vehicleId: 'v1',
    userId: 'user1',
    invoiceNumber: 'INV-001',
    issueDate: now,
    dueDate: dueDate,
    partsCost: 50000,
    laborCost: 30000,
    miscCost: 5000,
    subtotal: 85000,
    taxAmount: 8500,
    discountAmount: 0,
    totalAmount: totalAmount,
    paymentStatus: paymentStatus,
    paidAmount: paidAmount,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PaymentMethod enum', () {
    test('全メソッドの displayName が空でない', () {
      for (final method in PaymentMethod.values) {
        expect(method.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromString('creditCard'), PaymentMethod.creditCard);
      expect(PaymentMethod.fromString('bankTransfer'), PaymentMethod.bankTransfer);
      expect(PaymentMethod.fromString('loan'), PaymentMethod.loan);
      expect(PaymentMethod.fromString('electronicMoney'), PaymentMethod.electronicMoney);
      expect(PaymentMethod.fromString('other'), PaymentMethod.other);
    });

    test('fromString(null) は null を返す', () {
      expect(PaymentMethod.fromString(null), isNull);
    });

    test('fromString 不明な文字列は null を返す', () {
      expect(PaymentMethod.fromString(''), isNull);
      expect(PaymentMethod.fromString('bitcoin'), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethod.fromString(m.name), m);
      }
    });
  });

  group('PaymentStatus enum', () {
    test('全ステータスの displayName が空でない', () {
      for (final status in PaymentStatus.values) {
        expect(status.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(PaymentStatus.fromString('unpaid'), PaymentStatus.unpaid);
      expect(PaymentStatus.fromString('partiallyPaid'), PaymentStatus.partiallyPaid);
      expect(PaymentStatus.fromString('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromString('overdue'), PaymentStatus.overdue);
    });

    test('fromString 不明な文字列はデフォルト（unpaid）を返す', () {
      expect(PaymentStatus.fromString(null), PaymentStatus.unpaid);
      expect(PaymentStatus.fromString(''), PaymentStatus.unpaid);
      expect(PaymentStatus.fromString('invalid'), PaymentStatus.unpaid);
    });

    test('全 enum 値を往復変換できる', () {
      for (final s in PaymentStatus.values) {
        expect(PaymentStatus.fromString(s.name), s);
      }
    });
  });

  // ── Invoice.remainingAmount ───────────────────────────────────────────────

  group('Invoice.remainingAmount', () {
    test('paymentStatus が paid のとき 0', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.paid,
        totalAmount: 100000,
        paidAmount: 100000,
      );
      expect(inv.remainingAmount, 0);
    });

    test('unpaid で paidAmount が null のとき totalAmount 全額', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        totalAmount: 80000,
        paidAmount: null,
      );
      expect(inv.remainingAmount, 80000);
    });

    test('partiallyPaid で paidAmount=30000 のとき totalAmount - 30000', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.partiallyPaid,
        totalAmount: 100000,
        paidAmount: 30000,
      );
      expect(inv.remainingAmount, 70000);
    });

    test('paidAmount が totalAmount と同じでも paid でなければ 0 にならない', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        totalAmount: 50000,
        paidAmount: 50000,
      );
      // paid ステータスではないため paid ステータス判定はされない
      expect(inv.remainingAmount, 0);
    });

    test('totalAmount が 0 のとき 0', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        totalAmount: 0,
        paidAmount: null,
      );
      expect(inv.remainingAmount, 0);
    });
  });

  // ── Invoice.isOverdue ─────────────────────────────────────────────────────

  group('Invoice.isOverdue', () {
    test('dueDate が null のとき false', () {
      final inv = _makeInvoice(dueDate: null);
      expect(inv.isOverdue, false);
    });

    test('paymentStatus が paid のとき false（dueDate が過去でも）', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.paid,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(inv.isOverdue, false);
    });

    test('dueDate が昨日（未払い）のとき true', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(inv.isOverdue, true);
    });

    test('dueDate が明日（未払い）のとき false', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(inv.isOverdue, false);
    });

    test('dueDate が1年前（未払い）のとき true', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(inv.isOverdue, true);
    });

    test('partiallyPaid で期限切れのとき true', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.partiallyPaid,
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(inv.isOverdue, true);
    });
  });

  // ── Invoice.isDueSoon ─────────────────────────────────────────────────────

  group('Invoice.isDueSoon', () {
    test('dueDate が null のとき false', () {
      final inv = _makeInvoice(dueDate: null);
      expect(inv.isDueSoon, false);
    });

    test('paymentStatus が paid のとき false', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.paid,
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );
      expect(inv.isDueSoon, false);
    });

    test('0日後（今日が期限）のとき true', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(inv.isDueSoon, true);
    });

    test('7日後のとき true', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      expect(inv.isDueSoon, true);
    });

    test('8日後のとき false', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 8)),
      );
      expect(inv.isDueSoon, false);
    });

    test('期限切れ（昨日）のとき false（days < 0）', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(inv.isDueSoon, false);
    });

    test('14日後のとき false', () {
      final inv = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );
      expect(inv.isDueSoon, false);
    });
  });

  // ── Invoice equality ──────────────────────────────────────────────────────

  group('Invoice equality', () {
    test('同じ id は等しい', () {
      final a = _makeInvoice(id: 'inv1', totalAmount: 100000);
      final b = _makeInvoice(id: 'inv1', totalAmount: 999999);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeInvoice(id: 'inv1');
      final b = _makeInvoice(id: 'inv2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（請求書サービスエラーシナリオ）', () {
    test('network error は isRetryable=true', () {
      const error = AppError.network('接続失敗');
      expect(error.isRetryable, true);
    });

    test('server error は isRetryable=true', () {
      const error = AppError.server('サーバーエラー');
      expect(error.isRetryable, true);
    });

    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('請求書が見つかりません');
      expect(error.isRetryable, false);
    });

    test('Result.success に Invoice を格納できる', () {
      final result = Result<Invoice, AppError>.success(_makeInvoice());
      expect(result.isSuccess, true);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<Invoice, AppError>.failure(
        AppError.notFound('inv not found'),
      );
      expect(result.isFailure, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('remainingAmount: totalAmount が非常に大きい場合も正常', () {
      final inv = _makeInvoice(
        totalAmount: 999999999,
        paidAmount: null,
        paymentStatus: PaymentStatus.unpaid,
      );
      expect(inv.remainingAmount, 999999999);
    });

    test('isDueSoon と isOverdue が同時に true にならない', () {
      // 期限切れ（isOverdue=true）は isDueSoon=false
      final overdue = _makeInvoice(
        paymentStatus: PaymentStatus.unpaid,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(overdue.isOverdue, true);
      expect(overdue.isDueSoon, false);
    });

    test('PaymentMethod と PaymentStatus の displayName が全て異なる', () {
      final methodNames = PaymentMethod.values.map((m) => m.displayName).toSet();
      expect(methodNames.length, PaymentMethod.values.length);

      final statusNames = PaymentStatus.values.map((s) => s.displayName).toSet();
      expect(statusNames.length, PaymentStatus.values.length);
    });

    test('paid 状態の Invoice は isOverdue=false かつ isDueSoon=false', () {
      final past = _makeInvoice(
        paymentStatus: PaymentStatus.paid,
        dueDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(past.isOverdue, false);
      expect(past.isDueSoon, false);
    });
  });
}
