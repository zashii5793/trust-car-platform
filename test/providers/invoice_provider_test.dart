// InvoiceProvider Unit Tests

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/invoice_provider.dart';
import 'package:trust_car_platform/services/invoice_service.dart';
import 'package:trust_car_platform/models/invoice.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock InvoiceService
// ---------------------------------------------------------------------------

class MockInvoiceService implements InvoiceService {
  // Stream controller for listenToInvoices
  final _streamController = StreamController<List<Invoice>>.broadcast();

  Result<List<Invoice>, AppError> unpaidResult = const Result.success([]);
  Result<String, AppError> createResult = const Result.success('inv_new');
  Result<void, AppError> updateResult = const Result.success(null);
  Result<void, AppError> updatePaymentResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);
  Result<String, AppError> generateNumberResult =
      const Result.success('INV-001');
  Result<List<Invoice>, AppError> byVehicleResult = const Result.success([]);
  Result<Invoice?, AppError> byMaintenanceResult = const Result.success(null);
  Result<List<Invoice>, AppError> byDateRangeResult = const Result.success([]);

  // Call tracking
  int createCallCount = 0;
  int updateCallCount = 0;
  int deleteCallCount = 0;
  String? lastDeletedId;
  String? lastUpdatedId;

  void emitInvoices(List<Invoice> invoices) {
    _streamController.add(invoices);
  }

  void emitError(Object error) {
    _streamController.addError(error);
  }

  @override
  Stream<List<Invoice>> getUserInvoices() => _streamController.stream;

  @override
  Future<Result<List<Invoice>, AppError>> getUnpaidInvoices() async =>
      unpaidResult;

  @override
  Future<Result<String, AppError>> createInvoice(Invoice invoice) async {
    createCallCount++;
    return createResult;
  }

  @override
  Future<Result<void, AppError>> updateInvoice(
      String invoiceId, Invoice invoice) async {
    updateCallCount++;
    lastUpdatedId = invoiceId;
    return updateResult;
  }

  @override
  Future<Result<void, AppError>> updatePaymentStatus({
    required String invoiceId,
    required PaymentStatus status,
    PaymentMethod? method,
    DateTime? paymentDate,
    int? paidAmount,
  }) async => updatePaymentResult;

  @override
  Future<Result<void, AppError>> deleteInvoice(String invoiceId) async {
    deleteCallCount++;
    lastDeletedId = invoiceId;
    return deleteResult;
  }

  @override
  Future<Result<String, AppError>> generateInvoiceNumber() async =>
      generateNumberResult;

  @override
  Future<Result<List<Invoice>, AppError>> getInvoicesByVehicle(
          String vehicleId) async =>
      byVehicleResult;

  @override
  Future<Result<Invoice?, AppError>> getInvoiceByMaintenanceRecord(
          String maintenanceRecordId) async =>
      byMaintenanceResult;

  @override
  Future<Result<List<Invoice>, AppError>> getInvoicesByDateRange({
    required DateTime start,
    required DateTime end,
  }) async => byDateRangeResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  void dispose() {
    _streamController.close();
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Invoice _makeInvoice({
  String id = 'inv1',
  String userId = 'user1',
  int totalAmount = 10000,
  int paidAmount = 0,
  PaymentStatus paymentStatus = PaymentStatus.unpaid,
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return Invoice(
    id: id,
    maintenanceRecordId: 'mr1',
    vehicleId: 'v1',
    userId: userId,
    invoiceNumber: 'INV-$id',
    issueDate: now,
    dueDate: dueDate,
    partsCost: 7000,
    laborCost: 2000,
    miscCost: 1000,
    subtotal: totalAmount,
    taxAmount: 0,
    discountAmount: 0,
    totalAmount: totalAmount,
    paymentStatus: paymentStatus,
    paidAmount: paidAmount,
    createdAt: now,
    updatedAt: now,
  );
}

InvoiceProvider _makeProvider(MockInvoiceService service) {
  return InvoiceProvider(invoiceService: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InvoiceProvider', () {
    late MockInvoiceService mockService;
    late InvoiceProvider provider;

    setUp(() {
      mockService = MockInvoiceService();
      provider = _makeProvider(mockService);
    });

    tearDown(() {
      provider.stopListening();
      mockService.dispose();
    });

    // ── 初期状態 ──────────────────────────────────────────────────────────────

    group('初期状態', () {
      test('初期状態は空でエラーなし', () {
        expect(provider.invoices, isEmpty);
        expect(provider.unpaidInvoices, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
        expect(provider.isRetryable, false);
      });
    });

    // ── listenToInvoices ──────────────────────────────────────────────────────

    group('listenToInvoices (Stream)', () {
      test('Stream から請求書を受け取ると invoices が更新される', () async {
        provider.listenToInvoices();

        mockService.emitInvoices([_makeInvoice(id: 'i1'), _makeInvoice(id: 'i2')]);
        await Future.microtask(() {}); // let stream propagate

        expect(provider.invoices.length, 2);
        expect(provider.error, isNull);
      });

      test('Stream エラーが発生すると error が設定される', () async {
        provider.listenToInvoices();
        mockService.emitError(Exception('[cloud_firestore/permission-denied] Access denied'));
        await Future.microtask(() {});

        expect(provider.error, isNotNull);
      });

      test('stopListening で購読が解除される', () async {
        provider.listenToInvoices();
        mockService.emitInvoices([_makeInvoice()]);
        await Future.microtask(() {});

        provider.stopListening();
        mockService.emitInvoices([_makeInvoice(id: 'after_stop')]);
        await Future.microtask(() {});

        // 購読解除後の更新は反映されない
        expect(provider.invoices.length, 1);
      });
    });

    // ── loadUnpaidInvoices ────────────────────────────────────────────────────

    group('loadUnpaidInvoices', () {
      test('未払い請求書を読み込める', () async {
        mockService.unpaidResult = Result.success([
          _makeInvoice(id: 'u1', paymentStatus: PaymentStatus.unpaid),
          _makeInvoice(id: 'u2', paymentStatus: PaymentStatus.unpaid),
        ]);

        await provider.loadUnpaidInvoices();

        expect(provider.unpaidInvoices.length, 2);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.unpaidResult =
            Result.failure(AppError.network('network error'));

        await provider.loadUnpaidInvoices();

        expect(provider.error, isNotNull);
        expect(provider.unpaidInvoices, isEmpty);
      });

      test('未払いがない場合は空リスト', () async {
        mockService.unpaidResult = const Result.success([]);
        await provider.loadUnpaidInvoices();

        expect(provider.unpaidInvoices, isEmpty);
        expect(provider.error, isNull);
      });
    });

    // ── createInvoice ─────────────────────────────────────────────────────────

    group('createInvoice', () {
      test('作成成功で invoiceId を返す', () async {
        mockService.createResult = const Result.success('new_id');

        final id = await provider.createInvoice(_makeInvoice());

        expect(id, 'new_id');
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('作成失敗で null を返しエラーが設定される', () async {
        mockService.createResult =
            Result.failure(AppError.network('failed'));

        final id = await provider.createInvoice(_makeInvoice());

        expect(id, isNull);
        expect(provider.error, isNotNull);
      });

      test('作成後は isLoading が false に戻る', () async {
        await provider.createInvoice(_makeInvoice());
        expect(provider.isLoading, false);
      });
    });

    // ── updateInvoice ─────────────────────────────────────────────────────────

    group('updateInvoice', () {
      test('更新成功で true を返す', () async {
        final success =
            await provider.updateInvoice('inv1', _makeInvoice());
        expect(success, true);
        expect(provider.error, isNull);
      });

      test('更新失敗で false を返しエラーが設定される', () async {
        mockService.updateResult =
            Result.failure(AppError.permission('Permission denied'));

        final success =
            await provider.updateInvoice('inv1', _makeInvoice());

        expect(success, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── updatePaymentStatus ───────────────────────────────────────────────────

    group('updatePaymentStatus', () {
      test('支払いステータス更新成功で true を返す', () async {
        final success = await provider.updatePaymentStatus(
          invoiceId: 'inv1',
          status: PaymentStatus.paid,
        );
        expect(success, true);
        expect(provider.error, isNull);
      });

      test('更新失敗で false を返す', () async {
        mockService.updatePaymentResult =
            Result.failure(AppError.network('failed'));

        final success = await provider.updatePaymentStatus(
          invoiceId: 'inv1',
          status: PaymentStatus.paid,
        );

        expect(success, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── deleteInvoice ─────────────────────────────────────────────────────────

    group('deleteInvoice', () {
      test('削除成功で請求書一覧から除去される', () async {
        // Stream 経由で請求書を設定
        provider.listenToInvoices();
        mockService.emitInvoices([
          _makeInvoice(id: 'inv1'),
          _makeInvoice(id: 'inv2'),
        ]);
        await Future.microtask(() {});

        final success = await provider.deleteInvoice('inv1');

        expect(success, true);
        expect(provider.invoices.length, 1);
        expect(provider.invoices.first.id, 'inv2');
      });

      test('削除失敗では請求書一覧が変わらない', () async {
        provider.listenToInvoices();
        mockService.emitInvoices([_makeInvoice(id: 'inv1')]);
        await Future.microtask(() {});

        mockService.deleteResult =
            Result.failure(AppError.permission('Permission denied'));
        final success = await provider.deleteInvoice('inv1');

        expect(success, false);
        expect(provider.invoices.length, 1);
      });

      test('正しい invoiceId を渡してサービスを呼び出す', () async {
        await provider.deleteInvoice('target_inv');
        expect(mockService.lastDeletedId, 'target_inv');
      });
    });

    // ── getStatistics ─────────────────────────────────────────────────────────

    group('getStatistics', () {
      test('全請求書ゼロのとき統計はすべて 0', () {
        final stats = provider.getStatistics();

        expect(stats.totalCount, 0);
        expect(stats.totalAmount, 0);
        expect(stats.unpaidCount, 0);
        expect(stats.unpaidAmount, 0);
        expect(stats.overdueCount, 0);
      });

      test('未払い請求書の統計が正しい', () async {
        provider.listenToInvoices();
        mockService.emitInvoices([
          _makeInvoice(
              id: 'i1', totalAmount: 10000, paymentStatus: PaymentStatus.unpaid),
          _makeInvoice(
              id: 'i2', totalAmount: 5000, paymentStatus: PaymentStatus.paid),
        ]);
        await Future.microtask(() {});

        final stats = provider.getStatistics();

        expect(stats.totalCount, 2);
        expect(stats.totalAmount, 15000);
        expect(stats.unpaidCount, 1);
        expect(stats.unpaidAmount, 10000);
      });

      test('期限超過の請求書が overdueCount に含まれる', () async {
        provider.listenToInvoices();
        final overdueDate = DateTime.now().subtract(const Duration(days: 1));
        mockService.emitInvoices([
          _makeInvoice(
            id: 'i1',
            totalAmount: 8000,
            paymentStatus: PaymentStatus.unpaid,
            dueDate: overdueDate,
          ),
        ]);
        await Future.microtask(() {});

        final stats = provider.getStatistics();

        expect(stats.overdueCount, 1);
        expect(stats.overdueAmount, 8000);
      });

      test('支払い済み請求書は overdueCount に含まれない', () async {
        provider.listenToInvoices();
        final overdueDate = DateTime.now().subtract(const Duration(days: 1));
        mockService.emitInvoices([
          _makeInvoice(
            id: 'i1',
            totalAmount: 8000,
            paymentStatus: PaymentStatus.paid,
            dueDate: overdueDate,
          ),
        ]);
        await Future.microtask(() {});

        final stats = provider.getStatistics();

        expect(stats.overdueCount, 0);
      });
    });

    // ── clear ─────────────────────────────────────────────────────────────────

    group('clear', () {
      test('clear で全状態がリセットされる', () async {
        provider.listenToInvoices();
        mockService.emitInvoices([_makeInvoice()]);
        await Future.microtask(() {});

        provider.clear();

        expect(provider.invoices, isEmpty);
        expect(provider.unpaidInvoices, isEmpty);
        expect(provider.error, isNull);
      });
    });

    // ── Edge Cases ────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('generateInvoiceNumber が null を返しても正常', () async {
        mockService.generateNumberResult =
            Result.failure(AppError.network('failed'));

        final number = await provider.generateInvoiceNumber();

        expect(number, isNull);
      });

      test('getInvoicesByVehicle が空リストを返しても正常', () async {
        mockService.byVehicleResult = const Result.success([]);
        final result = await provider.getInvoicesByVehicle('v1');
        expect(result, isEmpty);
      });

      test('getInvoicesByVehicle が失敗しても空リストで返る', () async {
        mockService.byVehicleResult =
            Result.failure(AppError.network('failed'));
        final result = await provider.getInvoicesByVehicle('v1');
        expect(result, isEmpty);
      });

      test('isRetryable はリトライ可能エラーのとき true', () async {
        provider.listenToInvoices();
        mockService.emitError(Exception('[cloud_firestore/unavailable] Service unavailable'));
        await Future.microtask(() {});

        expect(provider.isRetryable, true);
      });

      test('isRetryable はエラーがないとき false', () {
        expect(provider.isRetryable, false);
      });
    });
  });
}
