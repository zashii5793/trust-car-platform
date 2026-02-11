import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invoice.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// 請求書サービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class InvoiceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  InvoiceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // コレクション参照
  CollectionReference<Map<String, dynamic>> get _invoicesCollection =>
      _firestore.collection('invoices');

  /// 請求書を作成
  Future<Result<String, AppError>> createInvoice(Invoice invoice) async {
    try {
      final docRef = await _invoicesCollection.add(invoice.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 請求書を更新
  Future<Result<void, AppError>> updateInvoice(String invoiceId, Invoice invoice) async {
    try {
      await _invoicesCollection.doc(invoiceId).update(invoice.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 請求書を取得
  Future<Result<Invoice?, AppError>> getInvoice(String invoiceId) async {
    try {
      final doc = await _invoicesCollection.doc(invoiceId).get();
      if (doc.exists) {
        return Result.success(Invoice.fromFirestore(doc));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザーの請求書一覧を取得（Stream）
  Stream<List<Invoice>> getUserInvoices() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _invoicesCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  /// 車両の請求書一覧を取得
  Future<Result<List<Invoice>, AppError>> getInvoicesByVehicle(String vehicleId) async {
    try {
      final snapshot = await _invoicesCollection
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('issueDate', descending: true)
          .get();
      final invoices = snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
      return Result.success(invoices);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 整備記録に紐付く請求書を取得
  Future<Result<Invoice?, AppError>> getInvoiceByMaintenanceRecord(String maintenanceRecordId) async {
    try {
      final snapshot = await _invoicesCollection
          .where('maintenanceRecordId', isEqualTo: maintenanceRecordId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return Result.success(Invoice.fromFirestore(snapshot.docs.first));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 未払いの請求書一覧を取得
  Future<Result<List<Invoice>, AppError>> getUnpaidInvoices() async {
    if (currentUserId == null) {
      return Result.success([]);
    }

    try {
      final snapshot = await _invoicesCollection
          .where('userId', isEqualTo: currentUserId)
          .where('paymentStatus', whereIn: ['unpaid', 'partiallyPaid'])
          .orderBy('dueDate')
          .get();
      final invoices = snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
      return Result.success(invoices);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 支払いステータスを更新
  Future<Result<void, AppError>> updatePaymentStatus({
    required String invoiceId,
    required PaymentStatus status,
    PaymentMethod? method,
    DateTime? paymentDate,
    int? paidAmount,
  }) async {
    try {
      final updates = <String, dynamic>{
        'paymentStatus': status.name,
        'updatedAt': Timestamp.now(),
      };

      if (method != null) {
        updates['paymentMethod'] = method.name;
      }
      if (paymentDate != null) {
        updates['paymentDate'] = Timestamp.fromDate(paymentDate);
      }
      if (paidAmount != null) {
        updates['paidAmount'] = paidAmount;
      }

      await _invoicesCollection.doc(invoiceId).update(updates);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 請求書を削除
  Future<Result<void, AppError>> deleteInvoice(String invoiceId) async {
    try {
      await _invoicesCollection.doc(invoiceId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 請求書番号を生成
  Future<Result<String, AppError>> generateInvoiceNumber() async {
    try {
      final now = DateTime.now();
      final prefix = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}';

      // 今月の請求書数を取得
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final snapshot = await _invoicesCollection
          .where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('issueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final sequence = (snapshot.docs.length + 1).toString().padLeft(4, '0');
      return Result.success('$prefix-$sequence');
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 期間内の請求書を取得（統計用）
  Future<Result<List<Invoice>, AppError>> getInvoicesByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (currentUserId == null) {
      return Result.success([]);
    }

    try {
      final snapshot = await _invoicesCollection
          .where('userId', isEqualTo: currentUserId)
          .where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('issueDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('issueDate', descending: true)
          .get();
      final invoices = snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
      return Result.success(invoices);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
