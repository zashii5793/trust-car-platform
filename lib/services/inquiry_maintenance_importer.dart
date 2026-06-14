import '../models/maintenance_record.dart';

/// Structured maintenance detail that a repair shop attaches to an inquiry
/// reply. The user can pull it into their own maintenance records with one tap.
///
/// Stored on the inquiry message as a plain `Map<String, dynamic>` so the model
/// layer stays decoupled; this typed wrapper handles (de)serialization.
class InquiryMaintenancePayload {
  final String typeKey; // MaintenanceType.name
  final String title;
  final DateTime date;
  final int cost;
  final int? mileageAtService;
  final String? shopName;
  final String? description;
  final String? staffName;
  final String? safetyStandardsCertificate;
  final List<WorkItem> workItems;
  final List<Part> parts;
  final int? partsCost;
  final int? laborCost;
  final int? miscCost;

  const InquiryMaintenancePayload({
    required this.typeKey,
    required this.title,
    required this.date,
    required this.cost,
    this.mileageAtService,
    this.shopName,
    this.description,
    this.staffName,
    this.safetyStandardsCertificate,
    this.workItems = const [],
    this.parts = const [],
    this.partsCost,
    this.laborCost,
    this.miscCost,
  });

  factory InquiryMaintenancePayload.fromMap(Map<String, dynamic> map) {
    return InquiryMaintenancePayload(
      typeKey: map['typeKey'] as String? ?? 'other',
      title: map['title'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      mileageAtService: (map['mileageAtService'] as num?)?.toInt(),
      shopName: map['shopName'] as String?,
      description: map['description'] as String?,
      staffName: map['staffName'] as String?,
      safetyStandardsCertificate: map['safetyStandardsCertificate'] as String?,
      workItems: (map['workItems'] as List<dynamic>?)
              ?.map(
                  (e) => WorkItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      parts: (map['parts'] as List<dynamic>?)
              ?.map((e) => Part.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      partsCost: (map['partsCost'] as num?)?.toInt(),
      laborCost: (map['laborCost'] as num?)?.toInt(),
      miscCost: (map['miscCost'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeKey': typeKey,
      'title': title,
      'date': date.toIso8601String(),
      'cost': cost,
      if (mileageAtService != null) 'mileageAtService': mileageAtService,
      if (shopName != null) 'shopName': shopName,
      if (description != null) 'description': description,
      if (staffName != null) 'staffName': staffName,
      if (safetyStandardsCertificate != null)
        'safetyStandardsCertificate': safetyStandardsCertificate,
      'workItems': workItems.map((e) => e.toMap()).toList(),
      'parts': parts.map((e) => e.toMap()).toList(),
      if (partsCost != null) 'partsCost': partsCost,
      if (laborCost != null) 'laborCost': laborCost,
      if (miscCost != null) 'miscCost': miscCost,
    };
  }

  /// One-line summary for the import card UI.
  String get summary {
    final buf = StringBuffer(title.isEmpty ? '整備記録' : title);
    if (cost > 0) {
      buf.write(' / ¥$cost');
    }
    return buf.toString();
  }
}

/// Pure converter: builds a [MaintenanceRecord] **owned by the user** from a
/// shop-supplied [InquiryMaintenancePayload].
///
/// This is a pull-model import — the user always confirms before the record is
/// persisted, so [userId] is the importing user (never the shop). The shop only
/// proposes the data via the inquiry thread.
MaintenanceRecord buildMaintenanceRecordFromPayload({
  required InquiryMaintenancePayload payload,
  required String vehicleId,
  required String userId,
  required String inquiryId,
  DateTime? now,
}) {
  final created = now ?? DateTime.now();
  return MaintenanceRecord(
    id: '',
    vehicleId: vehicleId,
    userId: userId,
    type: MaintenanceType.fromString(payload.typeKey),
    title: payload.title.isEmpty ? '整備記録' : payload.title,
    description: payload.description,
    cost: payload.cost,
    shopName: payload.shopName,
    date: payload.date,
    mileageAtService: payload.mileageAtService,
    createdAt: created,
    staffName: payload.staffName,
    safetyStandardsCertificate: payload.safetyStandardsCertificate,
    workItems: payload.workItems,
    parts: payload.parts,
    partsCost: payload.partsCost,
    laborCost: payload.laborCost,
    miscCost: payload.miscCost,
    inquiryId: inquiryId,
  );
}
