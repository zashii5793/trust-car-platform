import 'package:cloud_firestore/cloud_firestore.dart';

/// 支払方法
enum PaymentMethod {
  cash('現金'),
  creditCard('クレジットカード'),
  bankTransfer('銀行振込'),
  loan('ローン'),
  electronicMoney('電子マネー'),
  other('その他');

  final String displayName;
  const PaymentMethod(this.displayName);

  static PaymentMethod? fromString(String? value) {
    if (value == null) return null;
    try {
      return PaymentMethod.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 支払状況
enum PaymentStatus {
  unpaid('未払い'),
  partiallyPaid('一部入金'),
  paid('入金済'),
  overdue('支払期限超過');

  final String displayName;
  const PaymentStatus(this.displayName);

  static PaymentStatus fromString(String? value) {
    if (value == null) return PaymentStatus.unpaid;
    try {
      return PaymentStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return PaymentStatus.unpaid;
    }
  }
}

/// 請求書モデル
class Invoice {
  final String id;
  final String maintenanceRecordId;   // 紐付く整備記録ID
  final String vehicleId;
  final String userId;

  // 請求書情報
  final String invoiceNumber;         // 請求書番号
  final String? estimateNumber;       // 見積書番号
  final DateTime issueDate;           // 発行日
  final DateTime? dueDate;            // 支払期限

  // 金額内訳
  final int partsCost;                // 部品代合計
  final int laborCost;                // 工賃合計
  final int miscCost;                 // 諸費用（印紙代、重量税等）
  final int subtotal;                 // 小計（税抜）
  final int taxAmount;                // 消費税額
  final int discountAmount;           // 割引額
  final int totalAmount;              // 総額

  // 諸費用内訳（車検時など）
  final int? stampDuty;               // 印紙代
  final int? weightTax;               // 重量税
  final int? liabilityInsurance;      // 自賠責保険料
  final int? recyclingFee;            // リサイクル料

  // 支払情報
  final PaymentMethod? paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime? paymentDate;        // 入金日
  final int? paidAmount;              // 入金額（一部入金の場合）

  // 顧客情報（スナップショット）
  final String? customerName;
  final String? customerAddress;
  final String? customerPhone;

  // メタデータ
  final String? notes;                // 備考
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.maintenanceRecordId,
    required this.vehicleId,
    required this.userId,
    required this.invoiceNumber,
    this.estimateNumber,
    required this.issueDate,
    this.dueDate,
    required this.partsCost,
    required this.laborCost,
    required this.miscCost,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    this.stampDuty,
    this.weightTax,
    this.liabilityInsurance,
    this.recyclingFee,
    this.paymentMethod,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentDate,
    this.paidAmount,
    this.customerName,
    this.customerAddress,
    this.customerPhone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 残額
  int get remainingAmount {
    if (paymentStatus == PaymentStatus.paid) return 0;
    return totalAmount - (paidAmount ?? 0);
  }

  /// 支払期限超過か
  bool get isOverdue {
    if (dueDate == null) return false;
    if (paymentStatus == PaymentStatus.paid) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// 支払期限が近いか（7日以内）
  bool get isDueSoon {
    if (dueDate == null) return false;
    if (paymentStatus == PaymentStatus.paid) return false;
    final days = dueDate!.difference(DateTime.now()).inDays;
    return days <= 7 && days >= 0;
  }

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Invoice(
      id: doc.id,
      maintenanceRecordId: data['maintenanceRecordId'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      estimateNumber: data['estimateNumber'],
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      partsCost: data['partsCost'] ?? 0,
      laborCost: data['laborCost'] ?? 0,
      miscCost: data['miscCost'] ?? 0,
      subtotal: data['subtotal'] ?? 0,
      taxAmount: data['taxAmount'] ?? 0,
      discountAmount: data['discountAmount'] ?? 0,
      totalAmount: data['totalAmount'] ?? 0,
      stampDuty: data['stampDuty'],
      weightTax: data['weightTax'],
      liabilityInsurance: data['liabilityInsurance'],
      recyclingFee: data['recyclingFee'],
      paymentMethod: PaymentMethod.fromString(data['paymentMethod']),
      paymentStatus: PaymentStatus.fromString(data['paymentStatus']),
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate(),
      paidAmount: data['paidAmount'],
      customerName: data['customerName'],
      customerAddress: data['customerAddress'],
      customerPhone: data['customerPhone'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenanceRecordId': maintenanceRecordId,
      'vehicleId': vehicleId,
      'userId': userId,
      'invoiceNumber': invoiceNumber,
      'estimateNumber': estimateNumber,
      'issueDate': Timestamp.fromDate(issueDate),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'partsCost': partsCost,
      'laborCost': laborCost,
      'miscCost': miscCost,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'stampDuty': stampDuty,
      'weightTax': weightTax,
      'liabilityInsurance': liabilityInsurance,
      'recyclingFee': recyclingFee,
      'paymentMethod': paymentMethod?.name,
      'paymentStatus': paymentStatus.name,
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'paidAmount': paidAmount,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Invoice copyWith({
    String? id,
    String? maintenanceRecordId,
    String? vehicleId,
    String? userId,
    String? invoiceNumber,
    String? estimateNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    int? partsCost,
    int? laborCost,
    int? miscCost,
    int? subtotal,
    int? taxAmount,
    int? discountAmount,
    int? totalAmount,
    int? stampDuty,
    int? weightTax,
    int? liabilityInsurance,
    int? recyclingFee,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DateTime? paymentDate,
    int? paidAmount,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      maintenanceRecordId: maintenanceRecordId ?? this.maintenanceRecordId,
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      estimateNumber: estimateNumber ?? this.estimateNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      miscCost: miscCost ?? this.miscCost,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      stampDuty: stampDuty ?? this.stampDuty,
      weightTax: weightTax ?? this.weightTax,
      liabilityInsurance: liabilityInsurance ?? this.liabilityInsurance,
      recyclingFee: recyclingFee ?? this.recyclingFee,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentDate: paymentDate ?? this.paymentDate,
      paidAmount: paidAmount ?? this.paidAmount,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Invoice(id: $id, invoiceNumber: $invoiceNumber, totalAmount: $totalAmount, status: ${paymentStatus.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
