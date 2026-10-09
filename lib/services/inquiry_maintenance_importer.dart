import '../models/maintenance_record.dart';
import '../models/shop_ledger.dart';
import '../models/vehicle.dart';

/// 店が整備明細を送るときのメッセージ本文。スレッドから1件ずつ送るときも、
/// 台帳の「送っていない明細」からまとめて送るときも、同じ文にする。
const String maintenanceDetailMessage = '整備明細をお送りします。「記録に追加」から保存できます。';

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

  /// Which car the detail is for. The shop picks it from its ledger; the
  /// ledger does not know the user's app vehicle IDs, so the plate and the car
  /// name travel with the detail and the user's app matches them.
  final String? vehicleLabel;
  final String? licensePlate;
  final String? ledgerVehicleId;

  /// The user's app vehicle ID, when the shop knows it (a thread the user
  /// opened about a specific car).
  final String? vehicleId;

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
    this.vehicleLabel,
    this.licensePlate,
    this.ledgerVehicleId,
    this.vehicleId,
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
      vehicleLabel: map['vehicleLabel'] as String?,
      licensePlate: map['licensePlate'] as String?,
      ledgerVehicleId: map['ledgerVehicleId'] as String?,
      vehicleId: map['vehicleId'] as String?,
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
      if (vehicleLabel != null) 'vehicleLabel': vehicleLabel,
      if (licensePlate != null) 'licensePlate': licensePlate,
      if (ledgerVehicleId != null) 'ledgerVehicleId': ledgerVehicleId,
      if (vehicleId != null) 'vehicleId': vehicleId,
    };
  }

  /// Car name and plate for display, or null when the shop did not say.
  String? get vehicleDisplay {
    final parts = [vehicleLabel, licensePlate]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join('・');
  }

  /// One-line summary for the import card UI.
  String get summary {
    final buf = StringBuffer(title.isEmpty ? '整備記録' : title);
    if (cost > 0) {
      buf.write(' / ${formatYen(cost)}');
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
  String? sourceMessageId,
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
    sourceMessageId: sourceMessageId,
  );
}

/// Yen with thousands separators, e.g. `¥16,500`.
String formatYen(int value) =>
    '${value < 0 ? '-' : ''}¥${formatThousands(value.abs())}';

/// Thousands separators, e.g. `45,100`.
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// The user's car a shop-sent detail most likely belongs to, or null when it
/// cannot be told. Used as the initial choice; the user still confirms.
///
/// 1. the app vehicle ID, if it is one of [vehicles]
/// 2. the plate (ignoring spaces, hyphens and full-width digits)
/// 3. the car name, when exactly one car matches
String? suggestImportVehicleId({
  required InquiryMaintenancePayload payload,
  required List<Vehicle> vehicles,
}) {
  if (vehicles.isEmpty) return null;

  final id = payload.vehicleId;
  if (id != null && vehicles.any((v) => v.id == id)) return id;

  final plate = payload.licensePlate?.trim() ?? '';
  if (plate.isNotEmpty) {
    final key = LedgerSearch.plateKey(plate);
    final hits = vehicles
        .where((v) =>
            v.licensePlate != null &&
            v.licensePlate!.trim().isNotEmpty &&
            LedgerSearch.plateKey(v.licensePlate!) == key)
        .toList();
    if (hits.length == 1) return hits.single.id;
  }

  final label = _nameKey(payload.vehicleLabel ?? '');
  if (label.isNotEmpty) {
    final hits = vehicles
        .where((v) => _nameKey('${v.maker}${v.model}') == label)
        .toList();
    if (hits.length == 1) return hits.single.id;
  }
  return null;
}

String _nameKey(String s) =>
    s.replaceAll(RegExp(r'[\s\u3000]'), '').toLowerCase();
