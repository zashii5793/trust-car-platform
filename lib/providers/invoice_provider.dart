import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../core/error/app_error.dart';

/// 請求書状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class InvoiceProvider with ChangeNotifier {
  final InvoiceService _invoiceService;

  InvoiceProvider({required InvoiceService invoiceService})
      : _invoiceService = invoiceService;

  List<Invoice> _invoices = [];
  List<Invoice> _unpaidInvoices = [];
  bool _isLoading = false;
  AppError? _error;
  StreamSubscription<List<Invoice>>? _invoicesSubscription;

  List<Invoice> get invoices => _invoices;
  List<Invoice> get unpaidInvoices => _unpaidInvoices;
  bool get isLoading => _isLoading;

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  /// ユーザーの請求書一覧をリスニング
  void listenToInvoices() {
    _invoicesSubscription?.cancel();

    _invoicesSubscription = _invoiceService.getUserInvoices().listen(
      (invoices) {
        _invoices = invoices;
        _error = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
        _scheduleRetry(listenToInvoices);
      },
    );
  }

  void _scheduleRetry(VoidCallback action) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: 2 << _retryCount);
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  /// リソースの解放
  void stopListening() {
    _invoicesSubscription?.cancel();
    _invoicesSubscription = null;
    _retryTimer?.cancel();
    _retryCount = 0;
  }

  /// ログアウト時のクリーンアップ
  void clear() {
    stopListening();
    _invoices = [];
    _unpaidInvoices = [];
    _error = null;
    notifyListeners();
  }

  /// 未払い請求書を取得
  Future<void> loadUnpaidInvoices() async {
    _isLoading = true;
    notifyListeners();

    final result = await _invoiceService.getUnpaidInvoices();
    result.when(
      success: (invoices) {
        _unpaidInvoices = invoices;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 請求書を作成
  Future<String?> createInvoice(Invoice invoice) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _invoiceService.createInvoice(invoice);
    String? invoiceId;

    result.when(
      success: (id) {
        invoiceId = id;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return invoiceId;
  }

  /// 請求書を更新
  Future<bool> updateInvoice(String invoiceId, Invoice invoice) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _invoiceService.updateInvoice(invoiceId, invoice);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 支払いステータスを更新
  Future<bool> updatePaymentStatus({
    required String invoiceId,
    required PaymentStatus status,
    PaymentMethod? method,
    DateTime? paymentDate,
    int? paidAmount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _invoiceService.updatePaymentStatus(
      invoiceId: invoiceId,
      status: status,
      method: method,
      paymentDate: paymentDate,
      paidAmount: paidAmount,
    );
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        // 未払いリストを更新
        loadUnpaidInvoices();
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 請求書を削除
  Future<bool> deleteInvoice(String invoiceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _invoiceService.deleteInvoice(invoiceId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        _invoices.removeWhere((inv) => inv.id == invoiceId);
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// 請求書番号を生成
  Future<String?> generateInvoiceNumber() async {
    final result = await _invoiceService.generateInvoiceNumber();
    return result.valueOrNull;
  }

  /// 車両の請求書を取得
  Future<List<Invoice>> getInvoicesByVehicle(String vehicleId) async {
    final result = await _invoiceService.getInvoicesByVehicle(vehicleId);
    return result.getOrElse([]);
  }

  /// 整備記録の請求書を取得
  Future<Invoice?> getInvoiceByMaintenanceRecord(String maintenanceRecordId) async {
    final result = await _invoiceService.getInvoiceByMaintenanceRecord(maintenanceRecordId);
    return result.getOrElse(null);
  }

  /// 期間の請求書を取得（統計用）
  Future<List<Invoice>> getInvoicesByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _invoiceService.getInvoicesByDateRange(start: start, end: end);
    return result.getOrElse([]);
  }

  /// 統計情報を計算
  InvoiceStatistics getStatistics() {
    int totalCount = _invoices.length;
    int totalAmount = 0;
    int unpaidCount = 0;
    int unpaidAmount = 0;
    int overdueCount = 0;
    int overdueAmount = 0;

    for (final invoice in _invoices) {
      totalAmount += invoice.totalAmount;

      if (invoice.paymentStatus != PaymentStatus.paid) {
        unpaidCount++;
        unpaidAmount += invoice.remainingAmount;

        if (invoice.isOverdue) {
          overdueCount++;
          overdueAmount += invoice.remainingAmount;
        }
      }
    }

    return InvoiceStatistics(
      totalCount: totalCount,
      totalAmount: totalAmount,
      unpaidCount: unpaidCount,
      unpaidAmount: unpaidAmount,
      overdueCount: overdueCount,
      overdueAmount: overdueAmount,
    );
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

/// 請求書統計情報
class InvoiceStatistics {
  final int totalCount;
  final int totalAmount;
  final int unpaidCount;
  final int unpaidAmount;
  final int overdueCount;
  final int overdueAmount;

  const InvoiceStatistics({
    required this.totalCount,
    required this.totalAmount,
    required this.unpaidCount,
    required this.unpaidAmount,
    required this.overdueCount,
    required this.overdueAmount,
  });
}
